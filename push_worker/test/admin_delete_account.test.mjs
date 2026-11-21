// Local test of POST /admin/delete-account with every Google endpoint mocked:
// no network, no real keys. Run with `node --test test/` from push_worker/.
//
// A throwaway RSA key pair signs the caller's Firebase ID token (its public
// half is served as the "Google JWKS"), and a second throwaway key stands in
// for the service account. Firestore reads, the OAuth token exchange and the
// Identity Toolkit delete are answered by the fake fetch below.

import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

import worker from '../src/index.js';

const PROJECT = 'test-project';
const enc = new TextEncoder();
const b64url = (bytes) =>
  Buffer.from(bytes).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

const signingPair = await crypto.subtle.generateKey(
  {
    name: 'RSASSA-PKCS1-v1_5',
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: 'SHA-256',
  },
  true,
  ['sign', 'verify'],
);
const publicJwk = {
  ...(await crypto.subtle.exportKey('jwk', signingPair.publicKey)),
  kid: 'test-kid',
  alg: 'RS256',
  use: 'sig',
};

const serviceKey = await crypto.subtle.generateKey(
  {
    name: 'RSASSA-PKCS1-v1_5',
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: 'SHA-256',
  },
  true,
  ['sign', 'verify'],
);
const pkcs8 = Buffer.from(await crypto.subtle.exportKey('pkcs8', serviceKey.privateKey));
const SERVICE_ACCOUNT_JSON = JSON.stringify({
  client_email: 'worker@test-project.iam.gserviceaccount.com',
  private_key:
    '-----BEGIN PRIVATE KEY-----\n' +
    pkcs8.toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PRIVATE KEY-----\n',
});

const env = { FIREBASE_PROJECT_ID: PROJECT, SERVICE_ACCOUNT_JSON };

async function idToken(uid, { project = PROJECT } = {}) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(enc.encode(JSON.stringify({ alg: 'RS256', kid: 'test-kid' })));
  const claims = b64url(
    enc.encode(
      JSON.stringify({
        aud: project,
        iss: 'https://securetoken.google.com/' + project,
        sub: uid,
        iat: now - 10,
        exp: now + 3600,
      }),
    ),
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    signingPair.privateKey,
    enc.encode(header + '.' + claims),
  );
  return header + '.' + claims + '.' + b64url(new Uint8Array(sig));
}

// ── Fake Google ────────────────────────────────────────────────────────────

/** users/{uid} documents in Firestore REST shape. */
let users;
/** Every accounts:delete call: { url, body, auth }. */
let deletes;
/** What accounts:delete answers next. */
let deleteAnswer;
let tokenExchanges;
let tokenScopes;

const userDoc = (fields) => ({
  fields: Object.fromEntries(
    Object.entries(fields).map(([k, v]) => [
      k,
      typeof v === 'boolean' ? { booleanValue: v } : { stringValue: v },
    ]),
  ),
});

beforeEach(() => {
  users = {
    admin1: userDoc({ role: 'admin', name: 'Boss' }),
    admin2: userDoc({ role: 'admin', name: 'Other admin' }),
    parent1: userDoc({ role: 'parent', name: 'Sara' }),
    driver1: userDoc({ role: 'driver', name: 'Ali' }),
    gone1: userDoc({ role: 'student', name: 'Zed' }),
    fired: userDoc({ role: 'admin', isActive: false }),
  };
  deletes = [];
  deleteAnswer = () => new Response('{}', { status: 200 });
});
tokenExchanges = 0;
tokenScopes = [];

globalThis.fetch = async (input, init = {}) => {
  const url = String(input);
  if (url.startsWith('https://www.googleapis.com/service_accounts/v1/metadata/jwk/')) {
    return new Response(JSON.stringify({ keys: [publicJwk] }), {
      headers: { 'cache-control': 'max-age=3600' },
    });
  }
  if (url === 'https://oauth2.googleapis.com/token') {
    tokenExchanges++;
    const assertion = new URLSearchParams(String(init.body)).get('assertion');
    const claims = JSON.parse(Buffer.from(assertion.split('.')[1], 'base64url').toString());
    tokenScopes.push(claims.scope);
    return new Response(JSON.stringify({ access_token: 'fake-access', expires_in: 3600 }));
  }
  const docsRoot =
    'https://firestore.googleapis.com/v1/projects/' + PROJECT + '/databases/(default)/documents/';
  if (url.startsWith(docsRoot + 'users/')) {
    assert.equal(init.headers?.Authorization, 'Bearer fake-access');
    const uid = url.slice((docsRoot + 'users/').length);
    return users[uid]
      ? new Response(JSON.stringify(users[uid]))
      : new Response('{"error":{"code":404}}', { status: 404 });
  }
  if (url === 'https://identitytoolkit.googleapis.com/v1/projects/' + PROJECT + '/accounts:delete') {
    deletes.push({ body: JSON.parse(init.body), auth: init.headers.Authorization });
    return deleteAnswer();
  }
  throw new Error('Unexpected network call in test: ' + url);
};

async function call({ token, body = { uid: 'parent1' }, method = 'POST' } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  const response = await worker.fetch(
    new Request('https://worker.test/admin/delete-account', {
      method,
      headers,
      body: method === 'POST' ? JSON.stringify(body) : undefined,
    }),
    env,
  );
  return { status: response.status, body: await response.json() };
}

// ── Tests ──────────────────────────────────────────────────────────────────

test('no token → 401, nothing deleted', async () => {
  const r = await call();
  assert.equal(r.status, 401);
  assert.equal(deletes.length, 0);
});

test('a forged token → 401', async () => {
  const good = await idToken('admin1');
  const [h, c] = good.split('.');
  const r = await call({ token: h + '.' + c + '.' + b64url(enc.encode('not-a-signature')) });
  assert.equal(r.status, 401);
  assert.equal(deletes.length, 0);
});

test('a token for another project → 401', async () => {
  const r = await call({ token: await idToken('admin1', { project: 'someone-else' }) });
  assert.equal(r.status, 401);
});

test('a non-admin caller → 403, nothing deleted', async () => {
  const r = await call({ token: await idToken('parent1'), body: { uid: 'driver1' } });
  assert.equal(r.status, 403);
  assert.match(r.body.error, /Only an admin/);
  assert.equal(deletes.length, 0);
});

test('a caller with no users document → 403', async () => {
  const r = await call({ token: await idToken('stranger'), body: { uid: 'driver1' } });
  assert.equal(r.status, 403);
  assert.equal(deletes.length, 0);
});

test('a deactivated admin → 403', async () => {
  const r = await call({ token: await idToken('fired'), body: { uid: 'driver1' } });
  assert.equal(r.status, 403);
  assert.equal(deletes.length, 0);
});

test('deleting yourself is refused', async () => {
  const r = await call({ token: await idToken('admin1'), body: { uid: 'admin1' } });
  assert.equal(r.status, 403);
  assert.match(r.body.error, /your own account/);
  assert.equal(deletes.length, 0);
});

test('deleting another admin is refused', async () => {
  const r = await call({ token: await idToken('admin1'), body: { uid: 'admin2' } });
  assert.equal(r.status, 403);
  assert.match(r.body.error, /Admin accounts/);
  assert.equal(deletes.length, 0);
});

test('a uid with no users document → 404, nothing deleted', async () => {
  const r = await call({ token: await idToken('admin1'), body: { uid: 'nobody' } });
  assert.equal(r.status, 404);
  assert.equal(deletes.length, 0);
});

test('a missing or path-like uid → 400', async () => {
  const token = await idToken('admin1');
  assert.equal((await call({ token, body: {} })).status, 400);
  assert.equal((await call({ token, body: { uid: 'users/admin1' } })).status, 400);
  assert.equal(deletes.length, 0);
});

test('success: calls accounts:delete with the uid and the service token', async () => {
  const r = await call({ token: await idToken('admin1'), body: { uid: 'parent1' } });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { deleted: true, uid: 'parent1', alreadyGone: false });
  assert.equal(deletes.length, 1);
  assert.deepEqual(deletes[0].body, { localId: 'parent1' });
  assert.equal(deletes[0].auth, 'Bearer fake-access');
  // The service token carries the Identity Toolkit scope.
  assert.ok(tokenScopes.at(-1).includes('https://www.googleapis.com/auth/identitytoolkit'));
});

test('USER_NOT_FOUND counts as success (already gone)', async () => {
  deleteAnswer = () =>
    new Response(JSON.stringify({ error: { code: 400, message: 'USER_NOT_FOUND' } }), {
      status: 400,
    });
  const r = await call({ token: await idToken('admin1'), body: { uid: 'gone1' } });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { deleted: true, uid: 'gone1', alreadyGone: true });
});

test('any other Identity Toolkit failure → 502 without the body', async () => {
  deleteAnswer = () =>
    new Response(JSON.stringify({ error: { code: 403, message: 'PERMISSION_DENIED secret detail' } }), {
      status: 403,
    });
  const r = await call({ token: await idToken('admin1'), body: { uid: 'driver1' } });
  assert.equal(r.status, 502);
  assert.equal(JSON.stringify(r.body).includes('secret detail'), false);
});

test('the Google access token is cached across calls', async () => {
  const before = tokenExchanges;
  await call({ token: await idToken('admin1'), body: { uid: 'parent1' } });
  await call({ token: await idToken('admin1'), body: { uid: 'driver1' } });
  assert.ok(tokenExchanges - before <= 1);
});

test('GET is refused, other routes still answer', async () => {
  const r = await call({ method: 'GET' });
  assert.equal(r.status, 405);
  const health = await worker.fetch(new Request('https://worker.test/health'), env);
  assert.equal(health.status, 200);
});
