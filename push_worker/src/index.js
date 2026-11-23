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
  // Deleting a Firebase Auth user (POST /admin/delete-account).
  'https://www.googleapis.com/auth/identitytoolkit',
].join(' ');
const IDENTITY_TOOLKIT = 'https://identitytoolkit.googleapis.com/v1/projects/';

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
  // Keyed by scope as well as expiry: a token minted before a scope was
  // added to SCOPES must not be reused for the new API.
  if (
    cachedAccessToken &&
    cachedAccessToken.scope === SCOPES &&
    cachedAccessToken.expiresAt > now + 60
  ) {
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
    scope: SCOPES,
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
const boolField = (doc, name) => doc?.fields?.[name]?.booleanValue === true;

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
              // One tray entry per notification. Tagging by type made each
              // alert replace the previous one of its kind — a second chat
              // message, or a second child's "boarded", wiped the first.
              tag: notification.docId || notification.type || 'general',
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
            route: notification.route || '',
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
        route:
          doc?.fields?.data?.mapValue?.fields?.route?.stringValue ?? '',
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

// ── Routes API proxy ───────────────────────────────────────────────────────

/**
 * The one field mask the app uses. Pinned here so a caller cannot ask for
 * the more expensive fields (traffic on polyline, toll info) on our key.
 */
const ROUTES_FIELD_MASK = [
  'routes.optimizedIntermediateWaypointIndex',
  'routes.polyline.encodedPolyline',
  'routes.legs.distanceMeters',
  'routes.legs.duration',
  'routes.legs.polyline.encodedPolyline',
  'routes.distanceMeters',
  'routes.duration',
].join(',');

const MAX_INTERMEDIATES = 25;

/** A `{location:{latLng:{latitude,longitude}}}` waypoint, or null. */
function cleanWaypoint(raw, stopover) {
  const ll = raw?.location?.latLng;
  const lat = Number(ll?.latitude);
  const lng = Number(ll?.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  const point = { location: { latLng: { latitude: lat, longitude: lng } } };
  if (stopover) {
    point.vehicleStopover = true;
    point.sideOfRoad = true;
  }
  return point;
}

/**
 *   POST /routes
 *   Authorization: Bearer <Firebase ID token of a driver>
 *   { "request": { origin, destination, intermediates?, optimizeWaypointOrder? } }
 *
 * Forwards one `computeRoutes` call with the server's own key, so the key
 * that can spend money on routing never ships inside the app. The request
 * is rebuilt from the few fields the app sends, not passed through, and
 * only drivers may call it: families read the route the driver's app
 * already cached on the trip.
 */
async function handleRoutes(request, env) {
  const authorization = request.headers.get('authorization') ?? '';
  if (!authorization.toLowerCase().startsWith('bearer ')) {
    return json({ error: 'Missing bearer token.' }, 401);
  }
  let uid;
  try {
    uid = await verifyIdToken(authorization.slice(7).trim(), env.FIREBASE_PROJECT_ID);
  } catch (error) {
    return json({ error: String(error.message ?? error) }, 401);
  }

  // 501 tells the app to use its own fallback, rather than fail the route.
  if (!env.ROUTES_API_KEY || !env.SERVICE_ACCOUNT_JSON) {
    return json({ error: 'Routing is not configured.' }, 501);
  }

  const accessToken = await googleAccessToken(env);
  const user = await readDocument(env, accessToken, 'users/' + uid);
  if (stringField(user, 'role') !== 'driver') {
    return json({ error: 'Only drivers can plan routes.' }, 403);
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: 'Body must be JSON.' }, 400);
  }
  const raw = payload?.request ?? {};
  const origin = cleanWaypoint(raw.origin, false);
  const destination = cleanWaypoint(raw.destination, true);
  if (!origin || !destination) {
    return json({ error: 'origin and destination are required.' }, 400);
  }
  const rawStops = Array.isArray(raw.intermediates) ? raw.intermediates : [];
  if (rawStops.length > MAX_INTERMEDIATES) {
    return json({ error: 'At most 25 stops per request.' }, 400);
  }
  const intermediates = rawStops.map((w) => cleanWaypoint(w, true));
  if (intermediates.some((w) => w === null)) {
    return json({ error: 'Every stop needs a valid latLng.' }, 400);
  }

  const body = {
    origin,
    destination,
    travelMode: 'DRIVE',
    routingPreference: 'TRAFFIC_AWARE',
    polylineEncoding: 'ENCODED_POLYLINE',
  };
  if (intermediates.length > 0) body.intermediates = intermediates;
  if (raw.optimizeWaypointOrder === true && intermediates.length > 1) {
    body.optimizeWaypointOrder = true;
  }

  const response = await fetch(
    'https://routes.googleapis.com/directions/v2:computeRoutes',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': env.ROUTES_API_KEY,
        'X-Goog-FieldMask': ROUTES_FIELD_MASK,
      },
      body: JSON.stringify(body),
    },
  );
  const text = await response.text();
  if (!response.ok) {
    console.error('routes failed', response.status, text.slice(0, 300));
    // The app falls back to a straight-line plan on any non-200.
    return json({ error: 'Routing failed.', status: response.status }, 502);
  }
  return new Response(text, {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ── AI reader (Gemini) ─────────────────────────────────────────────────────

/**
 * The fallback for the app's on-device OCR: when ML Kit could not read the
 * amount or transaction id off a payment screenshot, or the key fields off a
 * CNIC / licence / registration card, the app sends the (downsized) image here and
 * Gemini reads it into a fixed JSON shape.
 *
 *   POST /ai/read
 *   Authorization: Bearer <Firebase ID token>
 *   { "kind": "slip" | "license" | "registration" | "cnic",
 *     "mimeType": "image/jpeg", "imageBase64": "<…>" }
 *   → 200 { "result": { …fields… }, "model": "<model id>" }
 *   → 503 { "error": "ai_unavailable" } when no key is configured — the app
 *         then keeps its OCR-only result.
 *
 * The key is the `GEMINI_API_KEY` secret; it never ships in the app. The
 * image and the key are never logged.
 */

/**
 * Free-tier Flash-Lite. Measured on the owner's real receipts (Nov 2026):
 * 2.5-7 s and exact (incl. JazzCash's superscript "Rs. 1.00"), while
 * `gemini-flash-latest` and `gemini-3.8-flash` did not answer within 45-90 s
 * and `gemini-2.5-flash` is closed to new keys. Override with GEMINI_MODEL.
 */
const DEFAULT_GEMINI_MODEL = 'gemini-3.1-flash-lite';
const GEMINI_API = 'https://generativelanguage.googleapis.com/v1beta/models/';

/** ~2 MB of base64 ≈ 1.5 MB of JPEG; the app sends ≤1280 px, far under it. */
const MAX_IMAGE_BASE64 = 2 * 1024 * 1024;
const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);

const str = (description) => ({ type: 'string', description });

const AI_KINDS = {
  slip: {
    prompt:
      'This is a screenshot of a money-transfer receipt from a Pakistani ' +
      'payment app or bank (Easypaisa, JazzCash, NayaPay, SadaPay, Meezan ' +
      'or another bank, possibly via Raast). Read it exactly. The amount is ' +
      'the amount transferred in rupees (if a total including fees is ' +
      'shown, use the total); JazzCash prints the decimals as superscript, ' +
      'so "Rs. 1.00" is one rupee, not one hundred. Ignore fee, charge and ' +
      'tax lines. Copy the transaction id as printed (TID, Transaction ID, ' +
      'ID#, Trx ID, Reference Number / STAN), keeping a trailing "..." if ' +
      'it is cut off. Give the date and time as ISO 8601 local time. The ' +
      'receiver is who the money was sent to; the sender is who sent it. ' +
      'Leave out any field that is not visible. Do not guess.',
    schema: {
      type: 'object',
      properties: {
        provider: str('App or bank that issued the receipt: easypaisa, jazzcash, nayapay, sadapay, meezan, bank or unknown'),
        successful: { type: 'boolean', description: 'false if the receipt says failed, pending or unsuccessful' },
        amount: { type: 'number', description: 'Amount transferred in rupees, e.g. 1 or 4500.5' },
        transactionId: str('Transaction id exactly as printed'),
        dateTime: str('Transaction date and time, ISO 8601, e.g. 2026-11-20T01:33:00'),
        receiverName: str('Name of the person the money was sent to'),
        receiverAccount: str('Receiver account / mobile number as printed, masks included'),
        senderName: str('Name of the sender'),
        senderAccount: str('Sender account / mobile number as printed, masks included'),
      },
    },
  },
  license: {
    prompt:
      'This should be a photo of a Pakistani (usually Punjab) driving ' +
      'licence. Read it exactly. Dates as ISO 8601 (YYYY-MM-DD). The expiry ' +
      'is the "Valid Upto" / "Expiry" / "Valid Till" date. Categories are ' +
      'the vehicle classes the holder may drive (e.g. M/CYCLE, M/CAR, LTV, ' +
      'HTV, PSV). Set isDrivingLicense to false if it is not a driving ' +
      'licence. Leave out any field that is not visible. Do not guess.',
    schema: {
      type: 'object',
      properties: {
        isDrivingLicense: { type: 'boolean' },
        name: str('Holder name'),
        fatherName: str('Father / husband name'),
        cnic: str('CNIC number, 13 digits as printed'),
        licenseNumber: str('Licence number'),
        issueDate: str('Issue date, YYYY-MM-DD'),
        expiryDate: str('Expiry date, YYYY-MM-DD'),
        categories: { type: 'array', items: { type: 'string' } },
      },
    },
  },
  cnic: {
    prompt:
      'This should be a photo of a Pakistani CNIC (Computerized National ' +
      'Identity Card) issued by NADRA — the smart card or the older green ' +
      'card, front or back. Read it exactly. Dates as ISO 8601 ' +
      '(YYYY-MM-DD); on the card they are printed DD.MM.YYYY. The expiry is ' +
      'the "Date of Expiry"; set lifetime to true if it says Lifetime ' +
      'instead of a date. Do not read or return the date of birth or the ' +
      'address. side is "front" when the name is visible, else "back". Set ' +
      'isCnic to false if it is not a CNIC. Leave out any field that is not ' +
      'visible. Do not guess.',
    schema: {
      type: 'object',
      properties: {
        isCnic: { type: 'boolean' },
        side: str('front or back'),
        name: str('Holder name'),
        fatherName: str('Father / husband name'),
        cnic: str('Identity number, 13 digits as printed'),
        issueDate: str('Date of issue, YYYY-MM-DD'),
        expiryDate: str('Date of expiry, YYYY-MM-DD'),
        lifetime: { type: 'boolean', description: 'true if the expiry says Lifetime' },
      },
    },
  },
  registration: {
    prompt:
      'This should be a photo of a Pakistani (usually Punjab) vehicle ' +
      'registration card — either the front (Make, Maker Name, Type of ' +
      'Body, Seating Capacity, Year of Mfg, MRZ line starting C<ETD) or the ' +
      'back (Excise & Taxation, Form-G: Owner\'s Name, Chassis No, Engine ' +
      'No, Reg No). Read it exactly. The registration number looks like ' +
      'LEA-12-1234 or ABC-123. Set isVehicleRegistration to false if it is ' +
      'not a vehicle registration card. Leave out any field that is not ' +
      'visible or is blacked out. Do not guess.',
    schema: {
      type: 'object',
      properties: {
        isVehicleRegistration: { type: 'boolean' },
        registrationNumber: str('Registration / plate number'),
        make: str('Make (model), e.g. HIACE'),
        makerName: str('Maker, e.g. TOYOTA'),
        bodyType: str('Type of body, e.g. VAN, MOTOR CYCLE'),
        seatingCapacity: { type: 'integer' },
        yearOfManufacture: { type: 'integer' },
        colour: str('Colour'),
        ownerName: str("Owner's name"),
      },
    },
  },
};

/** The major version in a model id ("gemini-3.8-flash" → 3), or 0. */
function geminiMajor(model) {
  const m = /gemini-(\d+)/.exec(model);
  return m ? Number(m[1]) : 0;
}

async function handleAiRead(request, env) {
  const authorization = request.headers.get('authorization') ?? '';
  if (!authorization.toLowerCase().startsWith('bearer ')) {
    return json({ error: 'Missing bearer token.' }, 401);
  }
  try {
    await verifyIdToken(authorization.slice(7).trim(), env.FIREBASE_PROJECT_ID);
  } catch (error) {
    return json({ error: String(error.message ?? error) }, 401);
  }

  if (!env.GEMINI_API_KEY) return json({ error: 'ai_unavailable' }, 503);

  let payload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: 'Body must be JSON.' }, 400);
  }
  const kind = AI_KINDS[payload?.kind] ? payload.kind : null;
  if (!kind) return json({ error: 'kind must be slip, license, registration or cnic.' }, 400);
  const mimeType = String(payload.mimeType ?? 'image/jpeg');
  if (!ALLOWED_MIME.has(mimeType)) return json({ error: 'Unsupported image type.' }, 400);
  const image = typeof payload.imageBase64 === 'string' ? payload.imageBase64 : '';
  if (!image) return json({ error: 'imageBase64 is required.' }, 400);
  if (image.length > MAX_IMAGE_BASE64) return json({ error: 'Image too large.' }, 413);
  if (!/^[A-Za-z0-9+/=\s]+$/.test(image.slice(0, 1024))) {
    return json({ error: 'imageBase64 is not base64.' }, 400);
  }

  const model = (env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL).trim();
  const spec = AI_KINDS[kind];
  const generationConfig = {
    temperature: 0,
    responseMimeType: 'application/json',
    responseJsonSchema: spec.schema,
  };
  const contents = [
    {
      role: 'user',
      parts: [
        { inlineData: { mimeType, data: image.replace(/\s+/g, '') } },
        { text: spec.prompt },
      ],
    },
  ];
  const call = (config) =>
    fetch(GEMINI_API + encodeURIComponent(model) + ':generateContent', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        // Header, not ?key=, so the key never lands in a URL or a log line.
        'x-goog-api-key': env.GEMINI_API_KEY,
      },
      body: JSON.stringify({ contents, generationConfig: config }),
    });

  // Reading a receipt needs no deliberation; thinking only adds latency.
  // `thinkingLevel` exists on Gemini 3+ and is an error on older models. An
  // alias ("gemini-flash-latest") does not say which it is, so it is tried
  // with the level and, if refused as a bad request, once without.
  const mayThink = geminiMajor(model) >= 3 || model.endsWith('-latest');
  let response = await call(
    mayThink
      ? { ...generationConfig, thinkingConfig: { thinkingLevel: 'LOW' } }
      : generationConfig,
  );
  if (mayThink && response.status === 400) response = await call(generationConfig);

  if (!response.ok) {
    // Status only: Google's error body can echo request details.
    console.error('ai/read: gemini answered', response.status);
    const status = response.status === 429 ? 429 : 502;
    return json({ error: 'ai_failed', status: response.status }, status);
  }

  let text = '';
  try {
    const body = await response.json();
    const parts = body?.candidates?.[0]?.content?.parts ?? [];
    text = parts.map((p) => (typeof p.text === 'string' && !p.thought ? p.text : '')).join('');
  } catch {
    return json({ error: 'ai_failed' }, 502);
  }
  let result;
  try {
    result = JSON.parse(text);
  } catch {
    console.error('ai/read: model returned non-JSON');
    return json({ error: 'ai_failed' }, 502);
  }
  if (!result || typeof result !== 'object' || Array.isArray(result)) {
    return json({ error: 'ai_failed' }, 502);
  }
  return json({ result, model });
}

// ── Admin: permanently delete an account's sign-in ─────────────────────────

/**
 *   POST /admin/delete-account
 *   Authorization: Bearer <Firebase ID token of an admin>
 *   { "uid": "<account to delete>" }
 *   → 200 { "deleted": true, "uid": "…", "alreadyGone": false }
 *
 * The one step of the admin panel's "Delete permanently" that a client
 * cannot do: removing someone else's Firebase Auth user, which frees the
 * email for a new registration. It needs the service account; the admin
 * app writes the Firestore tombstone itself, and only after this succeeded.
 *
 * Refused unless the caller's own `users/{uid}` says `role: admin` (and is
 * neither deleted nor deactivated). Never deletes an admin account or the
 * caller's own, and only accounts that have a `users` document — so the
 * endpoint cannot be pointed at arbitrary uids. A sign-in that is already
 * gone (USER_NOT_FOUND) counts as success, so a retry after a half-finished
 * delete completes cleanly.
 */
async function handleAdminDeleteAccount(request, env) {
  const authorization = request.headers.get('authorization') ?? '';
  if (!authorization.toLowerCase().startsWith('bearer ')) {
    return json({ error: 'Missing bearer token.' }, 401);
  }
  let callerUid;
  try {
    callerUid = await verifyIdToken(
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
  const uid = typeof payload?.uid === 'string' ? payload.uid.trim() : '';
  // Firebase uids are at most 128 characters, and never contain a slash —
  // which would otherwise walk the Firestore path below.
  if (!uid || uid.length > 128 || uid.includes('/')) {
    return json({ error: 'uid is required.' }, 400);
  }

  if (!env.SERVICE_ACCOUNT_JSON) {
    return json({ error: 'Worker is not configured.' }, 500);
  }
  const accessToken = await googleAccessToken(env);

  const caller = await readDocument(env, accessToken, 'users/' + callerUid);
  if (
    stringField(caller, 'role') !== 'admin' ||
    boolField(caller, 'isDeleted') ||
    caller?.fields?.isActive?.booleanValue === false
  ) {
    return json({ error: 'Only an admin can delete accounts.' }, 403);
  }
  if (uid === callerUid) {
    return json({ error: 'You cannot delete your own account.' }, 403);
  }

  const target = await readDocument(env, accessToken, 'users/' + uid);
  if (!target) return json({ error: 'No such account.' }, 404);
  if (stringField(target, 'role') === 'admin') {
    return json({ error: 'Admin accounts cannot be deleted.' }, 403);
  }

  const response = await fetch(
    IDENTITY_TOOLKIT + env.FIREBASE_PROJECT_ID + '/accounts:delete',
    {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + accessToken,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ localId: uid }),
    },
  );
  if (response.ok) {
    console.log('admin ' + callerUid + ' deleted the sign-in of ' + uid);
    return json({ deleted: true, uid, alreadyGone: false });
  }
  const text = await response.text();
  if (text.includes('USER_NOT_FOUND')) {
    return json({ deleted: true, uid, alreadyGone: true });
  }
  // Status only: Google's error body can echo request details.
  console.error('admin/delete-account: identitytoolkit answered', response.status);
  return json(
    { error: 'Could not delete the sign-in.', status: response.status },
    502,
  );
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ ok: true, project: env.FIREBASE_PROJECT_ID ?? null });
    }

    if (
      url.pathname !== '/send' &&
      url.pathname !== '/routes' &&
      url.pathname !== '/ai/read' &&
      url.pathname !== '/admin/delete-account'
    ) {
      return json({ error: 'Not found.' }, 404);
    }
    if (request.method !== 'POST') return json({ error: 'Use POST.' }, 405);

    // Only the project id is needed to tell a real caller from a stranger;
    // the signing key is checked once that has been established.
    if (!env.FIREBASE_PROJECT_ID) {
      return json({ error: 'Worker is not configured.' }, 500);
    }

    try {
      if (url.pathname === '/routes') return await handleRoutes(request, env);
      if (url.pathname === '/ai/read') return await handleAiRead(request, env);
      if (url.pathname === '/admin/delete-account') {
        return await handleAdminDeleteAccount(request, env);
      }
      return await handleSend(request, env);
    } catch (error) {
      // Never leak the service account or a Google error body to the caller.
      console.error(url.pathname + ' failed', error);
      return json({ error: 'Request failed.' }, 500);
    }
  },
};
