/**
 * TransitPro push sender.
 *
 * The app already writes every alert into Firestore at
 * `notifications/{uid}/items/{docId}`, and a device that has the app open
 * raises its own banner from that stream. What was missing was delivery to a
 * phone that is asleep or has the app closed — which, for a bus-tracking app,
 * is most of the time it matters.
 *
 * FCM itself is free and unlimited; the only thing that needs to live on a
 * server is the credential that signs a send request. That is all this Worker
 * is. It never invents a notification: it is handed a document id, reads the
 * document the app already wrote, and delivers exactly that.
 *
 *   POST /send
 *   Authorization: Bearer <Firebase ID token of the signed-in sender>
 *   { "docId": "<shared notification id>", "uids": ["<recipient>", ...] }
 *
 * Why it reads the document rather than taking a title and body: an endpoint
 * that accepts arbitrary text for arbitrary uids can be used to send a fake
 * "your child has been dropped off" to any parent whose uid is known. Reading
 * the stored document means this Worker can only ever deliver something that
 * already passed `firestore.rules` on the way in.
 */

const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/metadata/jwk/securetoken@system.gserviceaccount.com';
const SCOPES = [
  'https://www.googleapis.com/auth/firebase.messaging',
  'https://www.googleapis.com/auth/datastore',
].join(' ');

/** Notification channel the Flutter app creates; keep the two in step. */
const ANDROID_CHANNEL_ID = 'transit_pro_channel';

// ── base64url helpers ──────────────────────────────────────────────────────

const encoder = new TextEncoder();

function base64UrlEncode(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecodeToString(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/');
  return atob(padded + '='.repeat((4 - (padded.length % 4)) % 4));
}

function base64UrlDecodeToBytes(value) {
  const binary = base64UrlDecodeToString(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function pemToPkcs8(pem) {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\s+/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

// ── Google access token (service account → OAuth2) ─────────────────────────

/**
 * Cached for the life of the isolate. Google's tokens last an hour; minting
 * one costs an RSA signature and a round trip, which is not worth repeating
 * for every alert in a burst of thirty.
 */
let cachedAccessToken = null;

async function googleAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.value;
  }

  const serviceAccount = JSON.parse(env.SERVICE_ACCOUNT_JSON);
  const claims = {
    iss: serviceAccount.client_email,
    scope: SCOPES,
    aud: OAUTH_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };

  const unsigned =
    base64UrlEncode(encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))) +
    '.' +
    base64UrlEncode(encoder.encode(JSON.stringify(claims)));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(unsigned),
  );

  const assertion = unsigned + '.' + base64UrlEncode(new Uint8Array(signature));
  const response = await fetch(OAUTH_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(
      'Google token exchange failed (' + response.status + '): ' +
        (await response.text()),
    );
  }

  const body = await response.json();
  cachedAccessToken = {
    value: body.access_token,
    expiresAt: now + (body.expires_in ?? 3600),
  };
  return cachedAccessToken.value;
}

// ── Firebase ID token verification ─────────────────────────────────────────

let cachedJwks = null;

async function signingKey(kid) {
  const now = Date.now();
  if (!cachedJwks || cachedJwks.expiresAt < now) {
    const response = await fetch(JWKS_URL);
    if (!response.ok) throw new Error('Could not fetch Google signing keys.');
    // Google states the refresh interval in Cache-Control; honouring it is
    // what keeps verification working across a key rotation without
    // re-fetching on every request.
    const cacheControl = response.headers.get('cache-control') ?? '';
    const maxAge = Number((cacheControl.match(/max-age=(\d+)/) ?? [])[1] ?? 3600);
    cachedJwks = {
      keys: (await response.json()).keys,
      expiresAt: now + maxAge * 1000,
    };
  }
  const jwk = cachedJwks.keys.find((k) => k.kid === kid);
  if (!jwk) throw new Error('Unknown signing key.');
  return crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
}

/** Returns the caller's uid, or throws with a reason. */
async function verifyIdToken(idToken, projectId) {
  const parts = idToken.split('.');
  if (parts.length !== 3) throw new Error('Malformed ID token.');

  // A malformed token must not surface a JSON parser's own wording to the
  // caller; every shape of garbage gets the same answer.
  let header;
  try {
    header = JSON.parse(base64UrlDecodeToString(parts[0]));
  } catch {
    throw new Error('Malformed ID token.');
  }
  if (header.alg !== 'RS256') throw new Error('Unexpected token algorithm.');
  if (!header.kid) throw new Error('ID token has no key id.');

  const key = await signingKey(header.kid);
  const verified = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64UrlDecodeToBytes(parts[2]),
    encoder.encode(parts[0] + '.' + parts[1]),
  );
  if (!verified) throw new Error('ID token signature does not verify.');

  let claims;
  try {
    claims = JSON.parse(base64UrlDecodeToString(parts[1]));
  } catch {
    throw new Error('Malformed ID token.');
  }
  const now = Math.floor(Date.now() / 1000);
  if (claims.exp <= now) throw new Error('ID token has expired.');
  if (claims.iat > now + 60) throw new Error('ID token is not valid yet.');
  if (claims.aud !== projectId) throw new Error('ID token is for another project.');
  if (claims.iss !== 'https://securetoken.google.com/' + projectId) {
    throw new Error('ID token has the wrong issuer.');
  }
  if (!claims.sub) throw new Error('ID token has no subject.');
  return claims.sub;
}

// ── Firestore REST ─────────────────────────────────────────────────────────

function documentsRoot(projectId) {
  return (
    'https://firestore.googleapis.com/v1/projects/' +
    projectId +
    '/databases/(default)/documents'
  );
}

async function readDocument(env, accessToken, path) {
  const response = await fetch(documentsRoot(env.FIREBASE_PROJECT_ID) + '/' + path, {
    headers: { Authorization: 'Bearer ' + accessToken },
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new Error(
      'Firestore read failed (' + response.status + '): ' + (await response.text()),
    );
  }
  return response.json();
}

const stringField = (doc, name) => doc?.fields?.[name]?.stringValue ?? '';

function stringArrayField(doc, name) {
  const values = doc?.fields?.[name]?.arrayValue?.values ?? [];
  return values.map((v) => v.stringValue).filter(Boolean);
}

/**
 * Drops tokens FCM has told us are dead. Without this a reinstalled phone
 * leaves its old token on the account for ever, and every later send spends
 * a request failing against it.
 */
async function removeTokens(env, accessToken, uid, tokens) {
  if (tokens.length === 0) return;
  const document =
    'projects/' +
    env.FIREBASE_PROJECT_ID +
    '/databases/(default)/documents/users/' +
    uid;
  await fetch(documentsRoot(env.FIREBASE_PROJECT_ID) + ':commit', {
    method: 'POST',
    headers: {
      Authorization: 'Bearer ' + accessToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      writes: [
        {
          transform: {
            document,
            fieldTransforms: [
              {
                fieldPath: 'fcmTokens',
                removeAllFromArray: {
                  values: tokens.map((t) => ({ stringValue: t })),
                },
              },
            ],
          },
        },
      ],
    }),
  });
}

// ── FCM ────────────────────────────────────────────────────────────────────

async function sendToToken(env, accessToken, deviceToken, notification) {
  const response = await fetch(
    'https://fcm.googleapis.com/v1/projects/' +
      env.FIREBASE_PROJECT_ID +
      '/messages:send',
    {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + accessToken,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          android: {
            // A bus alert is time-critical: "arriving in 5 minutes" is
            // useless if the OS batches it for twenty.
            priority: 'HIGH',
            notification: {
              channel_id: ANDROID_CHANNEL_ID,
              // Collapsing on type means a burst of position updates shows
              // the newest one rather than a stack of stale ones.
              tag: notification.type || 'general',
            },
          },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: { aps: { sound: 'default' } },
          },
          // Carried through so a tap can open the right screen.
          data: {
            type: notification.type || '',
            docId: notification.docId || '',
          },
        },
      }),
    },
  );

  if (response.ok) return { ok: true };

  const text = await response.text();
  // 404 UNREGISTERED and 400 INVALID_ARGUMENT on the token field both mean
  // "this token will never work again".
  const dead =
    response.status === 404 ||
    text.includes('UNREGISTERED') ||
    text.includes('registration-token-not-registered');
  return { ok: false, dead, error: text.slice(0, 300) };
}

// ── Request handling ───────────────────────────────────────────────────────

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

async function handleSend(request, env) {
  // Identity first, configuration second. The other order answers an
  // anonymous caller with "Worker is not configured", which tells a
  // stranger something about the deployment before they have proved they
  // are anyone at all.
  const authorization = request.headers.get('authorization') ?? '';
  if (!authorization.toLowerCase().startsWith('bearer ')) {
    return json({ error: 'Missing bearer token.' }, 401);
  }

  let senderUid;
  try {
    senderUid = await verifyIdToken(
      authorization.slice(7).trim(),
      env.FIREBASE_PROJECT_ID,
    );
  } catch (error) {
    return json({ error: String(error.message ?? error) }, 401);
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: 'Body must be JSON.' }, 400);
  }

  const docId = String(payload.docId ?? '').trim();
  const uids = Array.isArray(payload.uids)
    ? [...new Set(payload.uids.map((u) => String(u).trim()).filter(Boolean))]
    : [];

  if (!docId) return json({ error: 'docId is required.' }, 400);
  if (uids.length === 0) return json({ error: 'uids is required.' }, 400);
  // A ceiling, so one compromised account cannot turn this into a fan-out
  // amplifier. A driver's whole roster is well inside it.
  if (uids.length > 200) return json({ error: 'Too many recipients.' }, 400);

  if (!env.SERVICE_ACCOUNT_JSON) {
    return json({ error: 'Worker is not configured.' }, 500);
  }

  const accessToken = await googleAccessToken(env);

  // The notification is read from the recipient's own inbox, so there is
  // nothing to deliver unless the app already wrote it there.
  let notification = null;
  for (const uid of uids) {
    const doc = await readDocument(
      env,
      accessToken,
      'notifications/' + uid + '/items/' + docId,
    );
    if (doc) {
      notification = {
        title: stringField(doc, 'title') || 'Transit Pro',
        body: stringField(doc, 'body'),
        type: stringField(doc, 'type'),
        docId,
      };
      break;
    }
  }
  if (!notification) {
    return json({ error: 'No notification document matched docId.' }, 404);
  }

  let sent = 0;
  let failed = 0;
  const reached = [];

  for (const uid of uids) {
    const user = await readDocument(env, accessToken, 'users/' + uid);
    const tokens = stringArrayField(user, 'fcmTokens');
    if (tokens.length === 0) continue;

    const dead = [];
    for (const deviceToken of tokens) {
      const result = await sendToToken(env, accessToken, deviceToken, notification);
      if (result.ok) {
        sent++;
      } else {
        failed++;
        if (result.dead) dead.push(deviceToken);
      }
    }
    if (dead.length > 0) await removeTokens(env, accessToken, uid, dead);
    if (tokens.length > dead.length) reached.push(uid);
  }

  return json({ sent, failed, recipients: reached.length, sender: senderUid });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ ok: true, project: env.FIREBASE_PROJECT_ID ?? null });
    }

    if (url.pathname !== '/send') return json({ error: 'Not found.' }, 404);
    if (request.method !== 'POST') return json({ error: 'Use POST.' }, 405);

    // Only the project id is needed to tell a real caller from a stranger;
    // the signing key is checked once that has been established.
    if (!env.FIREBASE_PROJECT_ID) {
      return json({ error: 'Worker is not configured.' }, 500);
    }

    try {
      return await handleSend(request, env);
    } catch (error) {
      // Never leak the service account or a Google error body to the caller.
      console.error('send failed', error);
      return json({ error: 'Send failed.' }, 500);
    }
  },
};
