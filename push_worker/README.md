# TransitPro push sender

A Cloudflare Worker that delivers TransitPro's alerts to phones with the app
closed.

The app already writes every alert to `notifications/{uid}/items/{docId}` in
Firestore, and a device with the app open raises its own banner from that
stream. A sleeping phone hears nothing — which, for a bus-tracking app, is
most of the time it matters. FCM solves that and is free with no quota, but a
send request has to be signed by a service account, and a service account key
cannot ship inside an APK. This Worker holds that key.

## What it does

```
POST https://<your-worker>.workers.dev/send
Authorization: Bearer <Firebase ID token of the signed-in sender>
Content-Type: application/json

{ "docId": "<notification id>", "uids": ["<recipient uid>", ...] }
```

1. Verifies the Firebase ID token against Google's published signing keys —
   the same check the Firebase Admin SDK performs, so a stranger who finds
   the URL gets a 401.
2. Reads `notifications/{uid}/items/{docId}` and sends **what is stored
   there**. It never takes a title and body from the caller, so this endpoint
   cannot be used to put a fake "your child has been dropped off" on a
   parent's lock screen.
3. Reads each recipient's `users/{uid}.fcmTokens` and sends one FCM message
   per device, at high priority.
4. Drops tokens FCM reports as dead, so a reinstalled phone does not leave a
   token behind that every future send wastes a request on.

`GET /health` returns `{ ok: true }` and nothing sensitive — useful to
confirm a deploy landed.

## Already done

Deployed on 2026-10-31 to the account `noorshahid2632@gmail.com`:

| | |
| --- | --- |
| URL | `https://transitpro-push.transitpro-push.workers.dev` |
| Secret | `SERVICE_ACCOUNT_JSON` set from `transitpro-db-firebase-adminsdk-fbsvc-*.json` |
| Project | `transitpro-db` |
| App config | `AppConfig.pushWorkerUrl` defaults to the URL above |

Verified: `/health` returns 200; `/send` answers 401 with no token and 401
with a forged one; an unknown path answers 404.

**Delete the service account JSON from `N:\Flutter Projects\FYP\` now.** It
is uploaded and encrypted in Cloudflare; the copy on disk is the only one
anybody could steal. If it ever leaks, revoke it in Firebase Console →
Project settings → Service accounts, generate a new key and repeat step 3.

The rest of this file is how to redo any of it — a new machine, a rotated
key, a second environment.

## Setup — from scratch

### 1. Get the service account key

Firebase Console → **Project settings** → **Service accounts** →
**Generate new private key**. A JSON file downloads.

**Treat this file like a password.** It can read and write your whole
database. Do not commit it, do not put it in the app, delete it from
Downloads once step 3 is done.

### 2. Install Wrangler and sign in

```bash
cd push_worker
npm install
npx wrangler login
```

A browser opens to authorise. A free Cloudflare account is enough — no card.

### 3. Store the key as a secret

```bash
npx wrangler secret put SERVICE_ACCOUNT_JSON
```

It waits for input: paste the **entire contents** of the JSON file from step
1 (one paste, including the outer `{` and `}`), then press Enter.

Secrets are encrypted by Cloudflare and are never readable again, including
by you — they can only be overwritten. That is why they do not live in
`wrangler.jsonc`.

### 4. Deploy

```bash
npx wrangler deploy
```

It prints the URL, something like
`https://transitpro-push.<your-subdomain>.workers.dev`. Check it:

```bash
curl https://transitpro-push.<your-subdomain>.workers.dev/health
```

Expected: `{"ok":true,"project":"transitpro-db"}`.

### 5. Point the app at it

`AppConfig.pushWorkerUrl` in `transit_core/lib/src/config.dart` holds the
default. A different deployment overrides it at build time:

```bash
flutter run --dart-define=PUSH_WORKER_URL=https://transitpro-push.<your-subdomain>.workers.dev
```

The URL is not a secret — the Worker verifies a Firebase ID token on every
request, so knowing it grants nothing.

With no URL configured the app behaves exactly as it did before: in-app
banners only, nothing delivered to a closed app. Nothing breaks; alerts just
do not reach a sleeping phone.

### 6. Watch it work

```bash
npx wrangler tail
```

Then trigger an alert in the app (a seat request, an emergency alert). You
should see the request and, on the other phone, a notification with the app
closed.

## Cost

Cloudflare's free plan allows 100,000 Worker requests a day. One alert to a
driver is one request; a broadcast to a whole roster is also one request.
FCM itself is free and unlimited. Firestore reads: one for the notification
plus one per recipient, against the 50,000/day free tier.

Realistically this runs at zero.

## If something goes wrong

| Symptom | Cause |
| --- | --- |
| `401 Missing bearer token` | The app did not attach an ID token — nobody is signed in. |
| `401 ID token is for another project` | `FIREBASE_PROJECT_ID` in `wrangler.jsonc` does not match the app's Firebase project. |
| `404 No notification document matched docId` | The inbox write failed or was rejected by `firestore.rules`; nothing was stored to deliver. |
| `500 Worker is not configured` | `SERVICE_ACCOUNT_JSON` was never set — repeat step 3. |
| TLS handshake fails right after the first deploy | The `workers.dev` certificate is still being issued. Give it a few minutes. |
| `wrangler dev` refuses to start over `compatibility_date` | The bundled runtime only supports dates up to its own build. Keep the date a day or two behind today, or run `npm update wrangler`. |
| Request succeeds, `sent: 0` | The recipients have no `fcmTokens`. They have not opened the app since push registration was added, or they denied the notification permission. |
