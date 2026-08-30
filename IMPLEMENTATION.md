# TransitPro — Implementation Tracker

> **This file is the working state of the project.** It is the single place that
> records what is finished, what is in progress, and what is blocked.
>
> Companion documents:
> - [`README.md`](README.md) — architecture, schema, screen docs (mobile app)
> - [`../../transit_admin/README.md`](../../transit_admin/README.md) — admin app
>
> **Last updated:** 2026-08-28

---

## 🤖 Agent Protocol — read this first, every session

If you are an AI agent picking up this project, follow this loop **every time**:

### 1. Before doing anything
- Read this entire file. It is the source of truth for status.
- Read [`README.md`](README.md) §5 (architecture) and §8 (schema) for context.
- Run `flutter analyze` in **both** `transit_pro/` and `transit_core/`. If either
  reports errors, fix those before starting new work.
- Check the **Blocked** table below — never start a task whose blocker is unresolved.

### 2. While working
- Pick tasks in **ID order** within the lowest-numbered phase that still has open
  work. Dependencies are listed per task; respect them.
- Mark a task 🔵 **In progress** when you start it.
- Do not silently expand scope. If a task turns out bigger than described, split
  it, add the new task rows, and say so.

### 3. After every change — mandatory
1. Run `flutter analyze` in both packages. It must pass with **zero errors**.
2. Update this file:
   - Flip the task's status emoji.
   - Fill in its **Files** column with what you actually touched.
   - Add a dated line to the **Changelog** at the bottom.
   - Update **Last updated** at the top.
3. If you discovered something that changes the plan (a wrong assumption, a new
   blocker, a missing dependency), add it to **Open Questions** and tell the user
   plainly — do not bury it.
4. If a task is blocked by something only the user can do (an API key, a console
   setting, a decision), move it to 🔴 and add a row to
   **What I Need From You**.

### 4. Rules that do not bend
- **Never invent credentials.** Every key arrives via `--dart-define`. If one is
  missing, the feature must degrade gracefully, never crash.
- **Never mark a task ✅ without verifying it.** "Compiles" is not "works".
  State what you actually checked.
- **Never delete a user's data or a Firebase collection** without explicit
  confirmation in that session.
- **Money is integer paisa. Dates are `DateTime`. IDs are references, not names.**
  These three rules are why the model layer was rebuilt; do not regress them.
- Keep the `ValueNotifier` service API when migrating screens — swap the
  internals for Firestore streams. Most screens should not need to change.

### Status legend

| | Meaning |
|---|---|
| ✅ | Done and verified |
| 🔵 | In progress |
| ⬜ | Not started |
| 🔴 | Blocked — see *What I Need From You* |
| ⏸️ | Deferred, out of scope for now |

---

## 📊 Progress

| Phase | Done | Total | Status |
|---|---|---|---|
| Phase 0 — Foundation | 4 | 7 | 🔵 In progress |
| Phase 1 — Real accounts & data | 18 | 20 | 🔵 In progress |
| Phase 1b — Driver service & requests | 14 | 15 | 🔵 In progress |
| Phase 2 — Live tracking | 0 | 11 | ⬜ Not started |
| Phase 3 — AI features | 0 | 8 | ⬜ Not started |
| Phase 4 — Pilot hardening | 0 | 9 | ⬜ Not started |
| **Total** | **36** | **70** | |

**2026-08-18 update:** `firestore.rules`, `database.rules.json`, and
Email/Password sign-in are all confirmed live — none of it independently
re-verified in this session (no device/emulator available here). Phase 1b's
items are no longer blocked by `PERMISSION_DENIED`, but the **manual
end-to-end walkthrough in 🏃 Next Actions still hasn't been run** — do that
before trusting the seat-request flow works, not just that it compiles. See
*What I Need From You* for the (short) list of what's still genuinely open.

---

## Phase 0 — Foundation

| ID | Task | Status | Files |
|---|---|---|---|
| P0-1 | Decide maps provider | ✅ **Redecided 2026-08-18 (later still) — Mapbox**, superseding the earlier Google Maps decision | — |
| P0-2 | Native map + HTTP APIs wired | ✅ Mapbox SDK, Directions v5, Geocoding v6 — see the 2026-08-18 (later still) changelog entry | `lib/map/**`, `lib/app/route_service.dart`, `lib/screens/map_picker_screen.dart` |
| P0-3 | Create `transit_core` shared package | ✅ | `transit_core/**`, `pubspec.yaml` |
| P0-4 | Move `mini_chart.dart` into `transit_core` | ⬜ | from `transit_admin/lib/widgets/` |
| P0-5 | Fix `applicationId` / bundle id | ⬜ tried and **reverted at your request 2026-08-18** — see note | `android/app/build.gradle.kts`, `ios/`, `macos/` |
| P0-6 | Delete duplicate admin section from mobile app | ✅ | removed `lib/screens/admin/`, `lib/app/admin_service.dart` |
| P0-7 | Regenerate colliding web `appId` in admin app | 🔴 | needs `flutterfire configure` — *What I Need From You* #6 |

**P0-1/P0-2, superseded 2026-08-18 (later still).** Everything Google-Maps-related
above (the demo key, `RouteService` calling Google's Routes/Geocoding APIs,
`AppConfig.googleMapsApiKey`) **no longer exists in this repo** — you switched
providers to Mapbox the same day, and the switch is complete: no
`google_maps_flutter` import, no `LatLng`, no Google key anywhere. See the
**2026-08-18 (later still) — Google Maps → Mapbox migration** changelog entry
for the full detail; that entry is now the authority on this area, not this
note.

**P0-5 note.** Renamed to `com.transitpro.app` earlier today, then **reverted
back to `com.example.transit_pro` at your request the same day** — Gradle, the
Kotlin package, the background-service `MethodChannel` name, and the iOS/macOS
bundle id are all back to the placeholder, confirmed by `git diff` showing no
change against the last commit. Still open whenever you're ready to pick a real
id: the blocker is unchanged from before — a real value has to be chosen (it
can't be invented for you, and it becomes permanent the moment a release build
reaches the Play Store), and a rename means registering a matching app in the
Firebase console before the build works again (see the old *What I Need From
You* #2b for why: `google-services.json` is keyed to the package name, and a
locally-faked match wouldn't survive contact with Google's OAuth backend
either).

---

## Phase 1 — Real accounts & real data

### Backend foundation

| ID | Task | Status | Files |
|---|---|---|---|
| P1-1 | Domain models with serialization | ✅ | `transit_core/lib/src/models/*.dart` (10 files, 17 models) |
| P1-2 | One enum set, duplicates removed | ✅ | `transit_core/lib/src/enums.dart` (16 enums) |
| P1-3 | Tolerant JSON helpers | ✅ | `transit_core/lib/src/json.dart` |
| P1-4 | Typed Firestore references | ✅ | `lib/data/db.dart` |
| P1-5 | Repository layer | ✅ | `lib/data/{user,fleet,trip,payment,missed_bus,messaging,live_location}_repository.dart` |
| P1-6 | Real auth with server-enforced roles | ✅ | `lib/app/auth_service.dart` |
| P1-7 | Firestore security rules | ✅ deployed & verified 2026-08-17 | `firestore.rules` |
| P1-8 | Realtime Database rules | ✅ deployed 2026-08-18 (per you — not yet exercised, Phase 2 hasn't started) | `database.rules.json` |
| P1-9 | Cloudinary upload service | ✅ | `lib/services/cloudinary_service.dart` |
| P1-10 | Seed script for starter data | ⬜ | `tool/seed.dart` (not created) |

### Screen migration — replace mock data with Firestore

| ID | Task | Status | Files |
|---|---|---|---|
| P1-11 | Rewire login screen to real auth | ✅ | `lib/screens/login_screen.dart` |
| P1-12 | Rewire signup screen to real auth | ✅ | `lib/screens/signup_screen.dart` |
| P1-13 | Real password reset + change password | ✅ | `forgot_password_screen.dart`, `parent/change_password_screen.dart` |
| P1-14 | Router auth guard (`redirect` on auth state) | ✅ | `lib/app/router.dart` |
| P1-15 | Migrate `ParentDataService` → Firestore | ✅ | `lib/app/parent_data_service.dart`, `lib/data/rating_repository.dart` |
| P1-16 | Migrate `DriverDataService` + `StudentDataService` | ✅ | `lib/app/{driver,student}_data_service.dart` |
| P1-17 | Global session store | ✅ | `lib/app/session_service.dart` |
| P1-18 | Google onboarding — profile completion screen | ✅ | `lib/screens/profile_completion_screen.dart`, `lib/app/{onboarding_service,profile_draft}.dart` |
| P1-19 | Fix broken logout | ✅ | `lib/widgets/logout_flow.dart` + 3 layouts |
| P1-20 | Seed script for demo data | ⬜ | `tool/seed.dart` (not created) |

### Phase 1b — driver-defined service & the request flow

Added 2026-08-18. This is what makes the app usable without an admin in the loop:
drivers describe their own rounds, and families book seats on them directly.

| ID | Task | Status | Files |
|---|---|---|---|
| P1b-1 | `ServiceArea`, `DriverSchedule`, `RideRequest`, `DriverMatch` models | ✅ | `transit_core/lib/src/models/{driver,ride_request,fleet,student}.dart`, `enums.dart` |
| P1b-2 | Unique `Student.publicCode` + duplicate-name validation | ✅ | `transit_core/.../student.dart`, `lib/app/profile_draft.dart` |
| P1b-3 | `ride_requests` collection + repository | ✅ | `lib/data/{db,ride_request_repository}.dart` |
| P1b-4 | Transactional accept / release (no oversold rounds) | ✅ | `lib/data/ride_request_repository.dart` |
| P1b-5 | Matchmaking query + ranking | ✅ | `lib/data/user_repository.dart`, `lib/app/ride_match_service.dart` |
| P1b-6 | Driver collects service areas + rounds at sign-up | ✅ | `profile_completion_screen.dart`, `signup_screen.dart`, `widgets/profile_form_fields.dart` |
| P1b-7 | Driver seat-request inbox | ✅ | `lib/screens/driver/driver_ride_requests_screen.dart` |
| P1b-8 | Driver service editor (rounds, seats, radius) | ✅ | `lib/screens/driver/driver_service_screen.dart` |
| P1b-9 | Family driver search + request | ✅ | `lib/screens/parent/find_drivers_screen.dart`, `widgets/find_driver_banner.dart` |
| P1b-10 | `ride_requests` + `students` security rules | ✅ published 2026-08-18 (per you) | `firestore.rules` |
| P1b-11 | Migrate the three fee screens to `payments` | ✅ | `parent_fees.dart`, `student_fees.dart`, `driver_payment_history_screen.dart`, `widgets/payment_presentation.dart` |
| P1b-12 | Real notification inbox (replaces 7 seeded fakes) | ✅ | `lib/app/notification_service.dart` |
| P1b-13 | Migrate driver roster off mock data, grouped by round | ✅ | `lib/screens/driver/driver_booked_students_screen.dart` |
| P1b-14 | FCM push for request events (true push while the app is fully closed) | ⏸️ **Deferred by your choice, 2026-08-18** — needs a Cloud Function, which needs the Blaze plan. See *What I Need From You* #8b |
| P1b-15 | System-tray banner for new remote notifications (interim, no server needed) | ✅ | `lib/app/notification_service.dart` |

**P1-11 → P1-13 done 2026-08-12.** All four auth screens now call Firebase for
real; `grep "Future.delayed"` across them returns nothing, and no screen calls
the deprecated `saveRole()` any more. Login routes by `AppUser.role` read from
Firestore, so opening `/login/driver` as a registered parent still lands in the
parent app — the URL is a hint, never an authorisation.

**P1-14 done 2026-08-12.** `router.dart` now has a `redirect` guard plus a
`refreshListenable` bound to `authStateChanges`, so the guard re-runs the moment
a session starts or ends rather than only on navigation.

- Public: `/splash`, `/`, `/role-select`, `/login/:role`, `/signup`, `/forgot-password`
- Everything else requires a session; signed-out access → `/role-select`
- Signed in but sitting on a login/signup screen → bounced to their role home
- `/splash` is never redirected, so the launch animation still owns its own routing

Sign-out now genuinely ejects the user: clearing the session fires the listenable
and any protected screen redirects immediately.

⚠️ **Cannot be tested until console setup is done** — items 2b and 3 in *What I
Need From You*. Until Email/Password is enabled, `signIn()` fails with
`operation-not-allowed`; until the SHA-1 is registered, Google sign-in fails.

---

## Phase 2 — Live tracking across devices

| ID | Task | Status | Files |
|---|---|---|---|
| P2-1 | Add Start Route / End Route control | ⬜ | `driver_dashboard.dart`, `driver_route.dart` |
| P2-2 | Driver publishes GPS to RTDB on a timer | ⬜ | new `lib/services/location_publisher.dart` |
| P2-3 | Point native background service at RTDB | ⬜ | `lib/main.dart` (`busTrackingBackground`) |
| P2-4 | Parent/student subscribe to live position | ⬜ | `parent_tracking.dart`, `student_tracking.dart` |
| P2-5 | Rewire `TrackingService` to real data | ⬜ | `lib/app/tracking_service.dart` |
| P2-6 | Attendance writes to Firestore | ⬜ | `driver_attendance.dart` |
| P2-7 | Add FCM + token registration | ⬜ | `pubspec.yaml`, `lib/services/push_service.dart` |
| P2-8 | Geofence events → FCM push to parents | ⬜ | `lib/app/geofence_service.dart` |
| P2-9 | Real chat replacing the 3 echo bots | ⬜ | `driver_chat_screen.dart`, `live_chat_screen.dart`, `student_driver_chat.dart` |
| P2-10 | Missed-bus flow on Firestore | ⬜ | `lib/app/missed_bus_service.dart` |
| P2-11 | Parent next-day attendance notice → driver, real backend | ⬜ added 2026-08-28 — `students/{id}/nextDayAttendance/{dateKey}` write + `NotificationService` push, replacing `parent_schedule.dart`'s current mock (`_setTomorrowAttendance`) | `lib/screens/parent/parent_schedule.dart`, new repository |

---

## Phase 3 — AI features

| ID | Task | Status | Files |
|---|---|---|---|
| P3-1 | Route-deviation detection | ⬜ | new `lib/services/safety_service.dart` |
| P3-2 | Unscheduled-stop detection | ⬜ | same |
| P3-3 | Harsh speed-change detection | ⬜ | same |
| P3-4 | Predicted-delay alerts | ⬜ | same |
| P3-5 | Write findings to `incidents` | ⬜ | `lib/data/` + `transit_core` `Incident` |
| P3-6 | ETA regression trained on pilot data | ⬜ | `tool/train_eta.dart` or notebook |
| P3-7 | Gemini assistant with function calling | ⬜ | new `lib/services/assistant_service.dart` |
| P3-8 | Assistant UI replacing fake chat | ⬜ | parent chat screens |

**Design note.** The admin app already has `SmartAlertService` with the right
shape — a broadcast `Stream<SmartAlert>` with severity levels. Fill that in
rather than inventing a new structure. `SafetyAlertType` in `transit_core`
already defines the vocabulary both apps share.

---

## Phase 4 — Pilot hardening

| ID | Task | Status | Files |
|---|---|---|---|
| P4-1 | Parent + school consent flow | ⬜ | new screen + `users` consent field |
| P4-2 | Security-rules audit against real accounts | ⬜ | `firestore.rules` |
| P4-3 | GPS retention policy (delete raw > 30 days) | ⬜ | scheduled cleanup |
| P4-4 | Data-deletion path for a withdrawing family | ⬜ | admin app + documented procedure |
| P4-5 | Written incident plan shared with school | ⬜ | `docs/incident-plan.md` |
| P4-6 | Crashlytics | ⬜ | `pubspec.yaml`, `main.dart` |
| P4-7 | Widget tests for critical flows | 🔵 `test/` now exists — one suite so far (the lat/lng conversion, see P0-1/P0-2). Screen-level widget tests still to come | `test/mapbox_geo_test.dart` |
| P4-8 | Seed real school data | ⬜ | `tool/seed.dart` |
| P4-9 | Multi-device testing on a real route | ⬜ | — |

---

## ⏸️ Deliberately out of scope

Disclose these in the report as scoped-out future work.

| Item | Why |
|---|---|
| Payment gateway | JazzCash/EasyPaisa need a registered merchant account. Keep deep link + manual slip confirmation |
| Automated document verification | Admin approves by hand |
| CSV / PDF report generation | Buttons removed rather than left fake |
| iOS background tracking | Android service works; pilot runs on Android |
| Cloudinary asset deletion | Needs a signed request; storing `publicId` keeps the option open |

---

## 🔴 What I Need From You

**Everything that was actually blocking something is resolved as of
2026-08-18.** What's left below is genuinely open, nothing more:

1. **#9 — verify the Mapbox migration on a real device.** I built a debug APK
   successfully in this session (proves the Gradle/token/compile chain works),
   but I have no Android device or emulator attached here to actually look at
   a rendered map. This is the one item that genuinely needs your eyes.
   **#9a, the crash you hit, is fixed** — the token is now a hardcoded default
   (with your sign-off), verified against a build with no `--dart-define` at
   all, so it's no longer dependent on a specific IDE run config. See its
   entry and the *final pass* changelog entry for detail.
2. **#7 — real pilot-school details**, so the seed script stops inventing
   names. The one true action item here.
3. **#8b — a Cloud Function for push-to-a-closed-app**, deferred by your
   choice, not urgent, no action needed until you want it.
4. **#8 — the Gemini key**, which you said is coming; nothing to do until it
   arrives.

Every other numbered item below is **done** and kept only as a dated reference
— e.g. the exact SHA-1 fingerprints in #2b, or what changed in #6b's rules
publish. Skip straight to the four above unless you need to look something up.

---

### ~~9a. Crash: MapboxConfigurationException — no access token~~ — ✅ fixed 2026-08-18 (even later)
You hit exactly the gap flagged below: `RouteMapView` (unlike `MapPickerScreen`,
which already checked `AppConfig.hasMapboxToken` first) built a `MapWidget`
unconditionally. With no token reaching the app, constructing the native view
throws `MapboxConfigurationException` — uncaught, since it happens inside
Flutter's platform-view creation, before `onMapCreated` ever runs. Fixed:
`RouteMapView` now checks `AppConfig.hasMapboxToken` the same way and shows a
plain "map unavailable" message instead of ever attempting to build the native
view without a valid token.

**Root cause of *why* the token wasn't reaching the app, and the real fix:**
`.idea/runConfigurations/main_dart.xml` — the Android Studio run config for
`main.dart` — had no `--dart-define` at all; adding it there (previous entry)
turned out not to be enough on its own, because `--dart-define` is baked in at
*compile time* — a hot reload/restart after editing that file keeps running
the old build, and any launch method that doesn't go through that exact IDE
config (a fresh checkout, a plain terminal `flutter run`, a different
temporary run configuration) still gets an empty token. Confirmed with you
directly and got explicit sign-off: `AppConfig.mapboxAccessToken`
(`transit_core/lib/src/config.dart`) now has the public `pk.` token as its
**default value**, the same pattern this file already used for Cloudinary's
public config. `--dart-define` still overrides it when needed. This is the
actual fix — the IDE run-config files were a fragile stopgap, now
unnecessary but left in place since they're harmless and git-ignored either
way. **Verified**: `flutter build apk --debug` with **zero** `--dart-define`
flags now succeeds and produces a working token.

**The "app breaks sometimes on logout" report is very likely the same bug,
not a separate one** — I looked through `session_service.dart` and the
tracking screens' dispose ordering and found nothing that looks like an
independent race; what the logs show (`Disposing unknown platform view`)
is Android tearing down a native view that never finished being created in
the first place, which lines up with signing out from a screen that had a
crashed map behind it. Please retest after this fix — if logout still misbehaves
with a real token in place, that *is* a separate bug and I'll need the crash
log for that specific failure, since I found nothing conclusive without one.

### 9. Verify the Mapbox migration on-device
Everything I could check without a device checks out: `flutter analyze` is
clean (0 errors), the lat/lng conversion tests pass, and
`flutter build apk --debug` — with no `--dart-define` needed at all now (see
the *final pass* changelog entry) — **succeeds**, proving the Gradle maven
auth, the token, and the whole Dart migration compile correctly together.
What it does *not* prove is anything about what actually renders. **Now that
the token reaches every launch path unconditionally, please check, on a real
build:**

1. ~~`MapPickerScreen` tiles render~~ — ✅ **confirmed** (your screenshot).
2. ~~Tap the map moves the pin, coordinate readout matches~~ — ✅ confirmed
   in the same screenshot.
3. **New, from the map-picker polish pass:** the "Done" button is now clearly
   visible (was white-on-white before) — confirm in both light and dark mode.
4. **New:** type a place name into the search bar — do results appear within
   ~1 second of pausing, and does tapping one fly the camera to the right
   spot?
5. **New:** tap the "my location" button (bottom-right) — does it prompt for
   location permission if not yet granted, and correctly center on your
   actual position once allowed?
6. Pick a point and confirm `MapPointField` resolves it to a real address
   (not raw coordinates) within a couple of seconds.
7. Open each of the three tracking screens (parent/student/driver). Confirm:
   all 6 stop pins are visible (not silently collision-hidden), the bus icon
   is visible and moves, the dashed route line and the solid "completed"
   line both render, and — for the driver screen — the camera follows the bus
   when "Follow" is active.
8. Leave and re-enter a tracking tab several times in a row. This is the one
   check most likely to surface a bug I couldn't fully verify without a
   device: whether annotations are cleanly torn down and rebuilt each time,
   or start piling up / crashing.
9. Toggle light/dark mode while a tracking screen is open — the map should
   flash and reload with the new style, not go blank.

If anything above fails, share what you saw (a screenshot, or the debug
console output — most of the new map code logs failures via `debugPrint`)
and I'll dig in from there.

---

### 7. Confirm one thing about the pilot school
For the seed script I need the real values: school name, how many buses, how many
students, and the actual route stops. Approximate is fine for now — I need to
stop inventing "Oak Street" and "Ahmed Raza".

### 8b. Later — a Cloud Function, if you want push while the app is fully closed
**You chose to defer this on 2026-08-18** — no Blaze plan yet, so no Cloud
Function. Here's the state that decision leaves things in, and the two real
options for when you revisit it.

**What's real today, no server needed (shipped 2026-08-18, P1b-15).**
`NotificationService.bindToUser` now raises an actual system-tray banner (sound +
vibration) the instant a new `notifications/{uid}/items` document arrives on a
signed-in device — a driver's SOS, an "alert all parents" broadcast, a ride-request
reply. Before this change the Firestore write only updated the in-app list
silently; opening the notifications screen was the only way to ever see it. This
now covers **foreground and backgrounded-but-running** — exactly the pattern
`BusTrackingService` (the existing foreground service) already keeps alive on
Android. What it does **not** cover: a device where the app process has been
fully killed by the OS or swiped away — there is no listener running to notice
the write.

**Why closing that last gap needs a trusted sender.** Reaching a *killed* app
needs an actual OS-level push (FCM), and sending FCM to someone else's device
needs a server holding credentials — putting those in the client would let
anyone with the APK push to any user, so `firebase_messaging` was deliberately
not added and nothing here can be done from Flutter alone.

**Option A — Firebase Cloud Function (needs Blaze).** One function triggered on
writes to `notifications/{uid}/items`, forwarding the document to that user's
`fcmTokens` via the Admin SDK. Cleanest option, lives in the same project,
~10 lines of code. Blocked on enabling Blaze billing (still has a large free
monthly quota at pilot scale — Blaze changes the *billing model*, not the price,
for functions under the free tier).

**Option B — an external relay, if you want to avoid Firebase billing entirely.**
A small serverless function on a free tier outside Firebase (Vercel, Cloudflare
Workers) holding a Firebase service-account key as a secret env var. The client
calls it right after writing the notification doc (pass `uid` + the doc id); the
relay looks up `fcmTokens` and calls the FCM HTTP v1 API directly. Same trust
model as option A, no Firestore trigger involved so no Blaze requirement — the
tradeoff is a second service to deploy and monitor, and the endpoint needs a
shared-secret header (or ID-token verification) so a stranger with the APK can't
call it to spam arbitrary users.

Either way, `UserRepository.addFcmToken`/`.removeFcmToken` already exist for the
client half — token registration was never built (no `firebase_messaging`
dependency yet), so that's still a few hours of work whichever option you pick.
Say the word when you're ready and I'll build the client + function together.

### 8. Later — Gemini API key (Phase 3, week 9)
Free at [aistudio.google.com](https://aistudio.google.com/apikey). Not urgent.
**You said 2026-08-18 you'll share this soon.** When it arrives, it's a straight
drop-in: `--dart-define=GEMINI_API_KEY=...`, gated by `AppConfig.hasGemini` —
nothing in Phase 3 exists to consume it yet, so there's no rush on either side.

---

## ✅ Resolved (reference archive)

Everything below is **done**. Kept for the exact detail (fingerprints, what a
rules change actually did) — not something you need to act on.

### ~~1. Cloudinary account~~ — ✅ DONE 2026-08-12
Cloud name `dllh0oom`, unsigned preset `TransitPro`. Both committed as defaults
in `AppConfig` (public values, safe to commit).

**Verified end to end:** an unsigned upload returned HTTP 200 with a
`secure_url`, and the on-the-fly thumbnail transform resolves. File uploads work
today.

Two notes:
- The self-test left one 1×1 px asset at `transitpro/_selftest/` in your media
  library. Safe to delete whenever.
- Because the preset has `Overwrite: false` (and unsigned uploads cannot set
  `overwrite: true`), the service does **not** send a fixed `public_id`.
  Cloudinary mints a unique id per upload, so changing a photo always succeeds
  and the old asset is simply orphaned — free and harmless at 25 GB.

### ~~1b. Register new Firebase apps for the renamed package/bundle id~~ — moot, reverted 2026-08-18
Was written up earlier today after P0-5 renamed the app id to `com.transitpro.app`.
You asked for the rename to be reverted the same day, so the app id is back to
`com.example.transit_pro`/`com.example.transitPro` and this Firebase-console step
is no longer needed. Left here, struck through, because P0-5 itself is still open
— whenever a real app id is chosen, this is the console-side step that goes with
it (new Android/iOS app registration, matching SHA-1s, fresh
`google-services.json`), not something to redo from scratch.

### ~~2. Maps HTTP calls (reverse geocoding, routes)~~ — ✅ superseded 2026-08-18 (later still)
This entire item described Google's Maps Demo Key and `RouteService` calling
Google's Routes/Geocoding APIs. **That's gone** — you switched to Mapbox the
same day, and `RouteService` now calls Mapbox's Directions v5 and Geocoding v6
APIs instead. See the migration changelog entry for the real, current state;
struck through here rather than deleted so the "why we looked at Google's
Web Service list" history isn't lost.

**Still open, unrelated to which provider:** nothing in the UI actually calls
`RouteService.fetchRoute` yet to draw a driver's route on a map — the service
is correct and ready, but "draw the polyline somewhere" is a separate, not yet
requested, UI task.

### ~~2b. Register the SHA-1 fingerprint~~ — ✅ DONE, verified 2026-08-17
Google Sign-In completes successfully on-device now — confirmed by a real
`users/{uid}` document landing in Firestore for a first-time Google account.
Left below for reference in case a release build or a new machine needs the
same fix again.

**Updated 2026-08-16 — the machine changed.** `google-services.json` now carries
`f1da1598…` (the old `FERRUM` machine). The current machine signs debug builds
with a different key, so Play Services cannot match the APK to any OAuth client
and Google Sign-In fails with `ApiException: 10` (`DEVELOPER_ERROR`). This was
reproduced on the TECNO CH7n on 2026-08-16.

Current debug keystore (`C:\Users\ta104\.android\debug.keystore`):

```
SHA-1   B6:B2:55:A2:BE:88:3C:5E:B9:3A:D8:93:4E:EA:B9:94:DB:EF:C4:91
SHA-256 D8:60:7A:CF:D9:55:4D:1F:CE:DD:15:48:D7:A5:7F:D5:EE:1C:03:CB:4E:AB:79:1D:4A:45:8E:63:50:1C:04:6D
```

Add these **alongside** the existing `F1:DA:…` entry rather than replacing it, so
both machines keep working. Previous machine, for reference:

```
SHA-1   F1:DA:15:98:B8:B6:38:40:F4:32:8D:89:A4:AF:CA:6E:11:CD:D3:CF
SHA-256 A6:3D:4F:E1:FB:CE:13:99:72:3B:08:76:C0:E4:CD:95:B7:DE:37:DA:C0:77:C3:49:07:9B:DD:57:49:29:F5:D8
```

The failure is no longer silent: `AuthService._messageForPlatform` catches the
`PlatformException` and explains that the signing certificate is unregistered.

Firebase console → Project settings → *Your apps* → **Add fingerprint**, for
**both** registrations (same fingerprint — the debug keystore is per-machine):
- `com.example.transit_pro` (mobile)
- `com.transitpro.transit_admin` (admin)

Then **re-download `google-services.json`** for each app and replace the file.
Skipping this is the single most common cause of Google Sign-In failing with no
error message.

Regenerate the fingerprint at any time with:
```bash
"/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe" -list -v \
  -keystore "$USERPROFILE/.android/debug.keystore" \
  -alias androiddebugkey -storepass android -keypass android
```

⚠️ Debug key only. A release build needs its own SHA-1, and Play Store App
Signing adds a third. Also note P0-5 (package rename) will invalidate the mobile
registration and require redoing this once.

### ~~3. Enable Email/Password sign-in~~ — ✅ done, per you 2026-08-18 (later)
Firebase console → Authentication → Sign-in method → Email/Password is now
enabled. Not independently re-verified in this session (no device here) — the
manual walkthrough in 🏃 Next Actions is still worth running to confirm
`signIn()`/`signUp()` actually succeed rather than just that the toggle is on.

### ~~4. Create the Firestore database~~ — ✅ DONE, verified 2026-08-17
Confirmed via the console: `users/{uid}` documents are being written and read
correctly.

### ~~5. Create the Realtime Database~~ — ✅ done, rules published 2026-08-18 (per you)
Rules can't publish against a database that doesn't exist, so this is implicitly
confirmed along with `database.rules.json` below. If the instance isn't in the
project's default region, send the URL for `RTDB_URL` (`AppConfig` in
`transit_core/lib/src/config.dart`) — otherwise nothing to do here. Still
genuinely untested end to end: Phase 2 (live GPS) hasn't started, so nothing has
written to or read from it yet.

### ~~6. Deploy the rules~~ — ✅ Firestore DONE, verified 2026-08-17
Deployed via the Firebase Console (paste-and-publish on the Rules tab), not
the CLI. Confirmed working: `firestore.rules`'s `users/{userId}` rule
correctly allows a signed-in user to create and read their own document.

**Realtime Database rules are also published now** — confirmed by you 2026-08-18,
see item 5 above.

`.firebaserc` and the `firestore`/`database` sections in `firebase.json` were
added 2026-08-17 so the CLI path
(`firebase deploy --only firestore:rules,firestore:indexes,database`) is ready
whenever you want to switch to it — useful going forward since a new Firestore
index (see the 2026-08-17 changelog entry) currently has to be created by hand
via a console link every time a new query pattern needs one.

Still open — fixes P0-7, unrelated to the above:
```bash
cd "d:/Noorulain FYP/transit_admin"
flutterfire configure --project=transitpro-db
```

### ~~6b. Re-publish `firestore.rules`~~ — ✅ DONE, published 2026-08-18 (per you)
`firestore.rules` gained a `ride_requests` block and two changes to `students` on
2026-08-17; you confirmed the current file is published. This was the top blocker
on the whole driver↔family flow, so it's worth actually running the manual
walkthrough in 🏃 Next Actions now rather than assuming it works — "published"
isn't the same as "a real driver and family have been through it."

What changed, so you can see it is safe:
- **New** `match /ride_requests/{requestId}` — readable only by the two parties,
  creatable only by a family that owns the named student, and the document id is
  forced to `{driverId}_{studentId}`.
- **`students` create** now also accepts `studentId == uid()`. This fixes a real
  pre-existing bug: a student registering themselves writes `students/{uid}` with
  an empty `parentId`, which the old rule denied outright — so student self-signup
  created the Auth account and the `users/{uid}` document and then silently failed
  on the student record.
- **`students` update** now lets a driver write `driverId` / `scheduleId` /
  `busId` — *only* those fields, and only when an accepted `ride_requests`
  document names them. It also lets a student edit their own record, which the old
  rule did not.

*(#7, #8, #8b — the three genuinely open items — moved to the top of this
section, right under the heading, so they don't get lost among the resolved
ones below.)*

---

## ❓ Open Questions

### ⏳ Still open — need your call

| # | Question | Raised | Notes |
|---|---|---|---|
| 3 | Rescue or delete the 4 unreachable admin screens (fees, routes, vehicles, students)? | 2026-08-08 | Open |
| 4 | Should students have their own login, or only appear inside the parent account? Their screens overlap heavily | 2026-08-08 | Open |
| 5 | Per-day schedules — the UI implies them, the model has one global slot set | 2026-08-08 | **Partly answered 2026-08-18** — `DriverSchedule.weekdays` exists and `runsOn()` honours it, but no form collects it yet, so every round is currently every-day. Finish this if the pilot has a Saturday-only or weekday-only run |
| 6 | Should a family book pickup and drop-off as one action, or two? | 2026-08-18 | A round is currently one direction, so a family wanting both legs sends two requests and consumes a seat on each. Faithful to how seats actually work (different trips, different capacity) but two taps for what feels like one arrangement to a parent. Worth deciding before the pilot, since it changes the request model |
| 7 | Should a driver be able to accept a student into a *full* round by overriding? | 2026-08-18 | Currently refused outright by the transaction. Drivers do squeeze one more in; the question is whether the app should let them record that or keep the seat count honest |

### ✅ Decided

| # | Question | Raised | Decision |
|---|---|---|---|
| 1 | Maps: Google, OpenStreetMap, or Mapbox? | 2026-08-12 | **Mapbox** (2026-08-18, later still) — superseded an earlier same-day "Google Maps" decision after the Google demo key turned out not to cover the native map widget. Full migration done — see P0-1/P0-2 and the migration changelog entry |
| 2 | Do driver sign-ups need admin approval before they can drive? | 2026-08-12 | **Self-signup allowed** (2026-08-16) — email *and* Google, landing in `status: pendingVerification`. Drivers reach their dashboard immediately; approval remains an admin action in `transit_admin`. Revisit before the pilot if a pending driver must be blocked from starting a route |
| 8 | Real push while the app is fully closed (P1b-14): Cloud Function or external relay? | 2026-08-18 | **Deferred** (2026-08-18) — neither built by your choice. In-app banners fire for foreground/backgrounded sessions (P1b-15) instead; revisit which option when you want push to a fully-killed app (*What I Need From You* #8b) |

---

## 🏃 Next Actions

**For you — nothing is currently blocking, but these are still worth doing:**
1. **Item 9 — verify the Mapbox migration on-device.** The whole reason for
   the provider switch was Google's demo key not covering the native map
   widget; I can't personally confirm Mapbox's does either without a device.
   See item 9's checklist.
2. Run the manual walkthrough below — every item that used to block it (rules,
   Email/Password) is now resolved *per you*, but none of it has actually been
   exercised end to end yet.
3. Decide the real `applicationId`/bundle id (P0-5) whenever you're ready — tried
   `com.transitpro.app` on 2026-08-18 and reverted it the same day, so this is
   back to open, not done.
4. Answer Open Questions #3, #4, #6, #7 whenever convenient — none block
   anything today, they're design decisions that get more expensive to change
   the longer real data sits on the current model.

**Then test the flow end to end, in this order** — each step depends on the last:
1. Sign up a **driver** manually. Confirm the new sections appear: destinations,
   travel radius, and at least one round with seats. Check `drivers/{uid}` in the
   console has `serviceAreas`, `serviceSchools` (lowercased) and `schedules`.
2. Sign up a **parent** with a child at one of that driver's listed schools.
3. Parent dashboard → *Find a driver* → the driver should appear. Send a request.
4. Driver dashboard → the banner should show "1 seat request waiting" → accept.
5. Confirm, in the console: the round's `bookedSeats` went up by one, and the
   child's `students/{id}` gained `driverId` and `scheduleId`.
6. Confirm the parent's banner now reads "Riding with <driver>", and that the
   driver appears in the parent's notification list.
7. Try to over-book: fill a round, then request it from another account. It should
   refuse with a readable message, not silently oversell.

**For the agent, after that:**
1. `P1-20` — write `tool/seed.dart`. Still the highest-value remaining task: fees,
   trips and attendance screens all show honest empty states until data exists.
2. `P1b-13` and the remaining mock screens: `driver_attendance`, both
   trip-history screens, the driver dashboard stat tiles, `lib/models/route_data.dart`.
3. Then Phase 2, starting with `P2-1` (Start/End Route), which everything else
   in that phase hangs off.

**Agent may do now without any credentials:** `P0-4` (move `mini_chart.dart`),
`P1-20` (write the seed script — it can be authored before it can be run).
`P0-5` (fix `applicationId`) is back to open — tried and reverted 2026-08-18, see
its note above — pick a real id whenever you're ready and it can be redone.

---

## 📝 Changelog

### 2026-08-28 (even later still) — hide the day-schedule "Completed" badge for a new account, swap Holidays for a "Tomorrow's Attendance" card

Three related fixes/changes to `parent_schedule.dart`, all in the same
"don't show a real-looking status when there's nothing real behind it"
family as the two entries just below.

**Task 1 — the day-detail "Completed" badge.** `sel.status` ('done'/
'today'/'upcoming') is derived purely from comparing the selected weekday to
today's date (`_buildSchedule`) — it has no idea whether a driver was ever
actually assigned. So a brand-new account with no driver, selecting any
weekday before today (e.g. "Monday" on a Thursday), saw a "Completed" badge
describing a pickup that never happened, since no schedule ever existed to
complete. Fixed by wrapping the status badge `Container` in `if (hasBus)` —
the same "does this child have a real assigned bus/route" signal this screen
already computes for the pickup/drop-off cards below it (`"Your driver
hasn't set a schedule yet"`). Icons/labels around it are unaffected — only
the badge disappears.

**Task 2 — removed "Upcoming Holidays" from this screen.** Deleted the
`FutureBuilder<List<Holiday>>` block, `_holidaysFuture`, `_holidayColors`,
`_formatHolidayDate`, and the `holiday_service.dart` import from
`parent_schedule.dart`. **Note, not hidden:** `lib/app/holiday_service.dart`
(the real Google Calendar-backed `HolidayService`, filtered to Pakistani
national + Islamic holidays as of the entry just below this one) is now
unused dead code — nothing imports it any more. Left in place rather than
deleted, since it's real working functionality you may want to surface
elsewhere (an announcements screen, the driver dashboard); say the word if
you'd rather it be deleted outright or wired in somewhere else.

**Task 3/4 — added a "Tomorrow's Attendance" card in its place.** A
`going`/`not going` segmented control (`_TomorrowAttendanceCard` +
`_AttendanceOption`, new private widgets in the same file) so a parent can
tell the driver in one tap whether their child is riding the next day,
instead of the driver finding out by waiting at an empty stop. Only shown
when `hasBus` is true (same gate as Task 1) — there's no driver to notify
otherwise. State is a per-child `Map<String, bool> _tomorrowGoing` (keyed by
`ChildInfo.id` so switching children via the child-switcher above doesn't
leak one child's choice onto another's card), defaulting an unset child to
"Going" rather than an ambiguous blank state, plus `_submittingAttendanceFor`
so only the card mid-submit shows a spinner and disables its own buttons.

**Explicitly a mock, and says so in the code.** `_setTomorrowAttendance`
updates local state optimistically, "calls the API" via a 600ms
`Future.delayed`, then shows a confirmation `SnackBar` — there is no real
backend for this yet. `AttendanceRecord` (`transit_core/lib/src/models/trip.dart`)
is a genuinely different thing: it lives under `trips/{tripId}/attendance/
{studentId}`, written by the *driver* once a real trip is running (Phase 2,
not started). A parent's advance notice for a trip that doesn't exist yet
needs its own home — most naturally a `students/{id}/nextDayAttendance/
{dateKey}` document plus a driver-facing push through `NotificationService`,
neither of which exists today. A `// TODO(backend):` comment in
`_setTomorrowAttendance` shows exactly where that real write would go. Added
as a new Phase 2 candidate task below rather than left unrecorded.

Added string keys `tomorrows_attendance`, `tomorrows_attendance_subtitle`,
`going`, `not_going` (English + Urdu) to `language_provider.dart`. Left the
now-unreferenced `upcoming_holidays` key in place — harmless dead data, not
worth a separate edit.

`flutter analyze` (full project): 4 issues, all pre-existing (same as before
this session — the `route_service.dart` info-lint and three Mapbox
deprecation notices). No new issues.

### 2026-08-28 (later still) — filter "Upcoming Holidays" to Pakistani national + Islamic observances only

`HolidayService` (parent schedule screen) reads Google's own
`en.pk#holiday@group.v.calendar.google.com` public calendar — already the
correct, country-restricted source (there's no separate `country=PK` query
param on the Calendar API; the restriction is which calendar you point at,
and this was already the right one). The problem wasn't the wrong country —
it's that Google's Pakistan calendar itself bundles in every regionally
observed festival for Pakistan's religious minorities (Janmashtami, Durga
Puja, Dussehra, Diwali, Holi, …) alongside the official national holidays and
Islamic observances the schedule screen should show. The API has no
"official/national only" toggle, so this needed a local filter.

**Added `HolidayService.isApprovedHoliday(name)`** — a static, testable
allowlist match against a curated `_approvedKeywords` list (Kashmir
Solidarity Day, Pakistan Day, Labour Day, Independence Day, Defence Day,
Iqbal Day, Quaid-e-Azam Day, Christmas [shares 25 Dec, officially gazetted],
plus the Islamic observances: Eid-ul-Fitr/Eid-ul-Azha, Ashura/Muharram, Eid
Milad-un-Nabi, Shab-e-Meraj, Shab-e-Barat, Giarhwin Sharief, Ramadan). It's an
**allowlist**, deliberately not a blocklist of the unwanted festivals —
fails closed, so an unrecognised event Google adds later is dropped rather
than silently shown. Matching is a case-insensitive substring check, since
Google's exact wording varies year to year ("Eid-ul-Fitr" vs "Eid al-Fitr").

**Wired into `upcomingPakistanHolidays`**: the raw API fetch now requests a
higher internal limit (`_rawFetchLimit = 30`, up from the caller's
`maxResults`) since a chunk of the raw feed gets filtered out and there needs
to be enough left to still fill the caller's requested count (default 5);
filtering happens right after parsing each item, before it's ever added to
the returned list; the 6-hour cache now stores the already-filtered list and
slices to `maxResults` per call.

**No UI changes needed** — `parent_schedule.dart`'s `FutureBuilder<List<Holiday>>`
already just renders whatever `HolidayService` returns, so the filter is
transparent to the widget.

`flutter analyze lib/app/holiday_service.dart lib/screens/parent/parent_schedule.dart`:
0 issues. Not independently verified against a live API response in this
session (no device/network call made) — the keyword list should be spot
checked against Google's actual `en.pk` summaries next time the schedule
screen is run for real, in case a spelling variant slips past the allowlist.

### 2026-08-28 (later) — hide the live ETA card for a new account with no driver yet, make its "to school"/"to home" text real

Same class of bug as the schedule-chip fix just below: the parent dashboard's
"8 min to school" / "Currently at [stop]" card (just above the "Find Driver"
section) rendered unconditionally, even for a brand-new account with no
driver ever accepted — a fabricated ETA with nothing behind it.

Added `_isLinkedWithDriver(child)` (`child != null && child.driver.isNotEmpty`
— the same "has an assigned driver" signal `_timingSlotsFor` already uses)
and wrapped the entire card in `if (_isLinkedWithDriver(child)) ...[...]`
inside the dashboard's `Column`. Nothing renders — not even a placeholder —
until a driver is actually linked.

**Also made the destination text real, not hardcoded.** It always read
`AppStrings.t('to_school')` regardless of time of day. Added
`_etaDestinationLabel(slots)`: compares `TimeOfDay.now()` against the linked
driver's own `afternoonPickupFromSchool` slot (the same real per-driver
`timingSlots` `_timingSlotsFor` reads) — before that time it's the morning
home→school leg ("to school"), at/after it's the afternoon school→home leg
("to home"). Added the missing `to_home` string key (English + Urdu) to
`language_provider.dart` alongside the existing `to_school`. The ETA minutes
figure itself was already live (`TrackingService.instance.etaMinutes` via
`ValueListenableBuilder`) — untouched.

**What this does not yet do, honestly:** there's still no real per-trip
"direction" field anywhere in the data model (`Trip`, `RouteData`) — Phase 2
(live tracking) hasn't started, so nothing writes real trip state yet. The
time-of-day heuristic against the driver's own schedule is the best real
signal available today; if/when Phase 2 lands actual trip direction, this
should read that instead of inferring it from the clock.

`flutter analyze lib/screens/parent/parent_dashboard.dart
lib/app/language_provider.dart`: 0 issues.

### 2026-08-28 — hide "Done"/"Pending" schedule badges for a new account with no active trip

Parent dashboard bug: the "Today's Schedule" card's three chips (Pickup, At
School, Drop Off) always showed a "Done"/"Pending" status badge, even for a
brand-new account with no driver assigned yet and no trip data at all —
fabricated status on an empty state.

`_timingSlotsFor` already returned `null` in exactly that case (no driver
assigned, or the driver record hasn't resolved yet) and the chips already used
that to show `'—'` for the time instead of a real one — the badge just wasn't
wired to the same check. Fixed by making `_ScheduleChip.status` nullable and
hiding its badge `Container` entirely when null, then passing `null` from all
three call sites when `slots == null`. The icons and labels (Pickup, At
School, Drop Off) still render unconditionally — only the badge disappears.

`flutter analyze lib/screens/parent/parent_dashboard.dart`: 0 issues.

### 2026-08-18 (map picker polish) — search bar, "my location", visible Done button

Map tiles render now, and you flagged three real usability gaps on
`MapPickerScreen` (the onboarding pin picker): the "Done" button was
essentially invisible, there was no way to jump to your current location, and
no way to search for a place by name — every pin had to be placed by eye and
memory of the map.

**"Done" button contrast — a real, simple bug.** It was hardcoded
`Colors.white` text on a `Scaffold`'s default `AppBar`, which is transparent
over the map by default. Against `MapboxStyles.LIGHT` (a light day map,
exactly what your screenshot showed) that's white-on-white — unreadable. Fixed
with a solid, theme-matched `AppBar` background (`context.cardBgElevated` /
`context.textPrimary`, the same tokens every other screen in the app uses)
instead of relying on transparency over content whose color can't be
predicted (roads, parks, water, labels all differ by location and zoom).

**Added `RouteService.forwardGeocode(query, {near})`** — Mapbox Geocoding v6
forward search (`q`, `proximity`, `access_token`), returning a short list of
`GeocodeResult(label, coord)`. `near: _selected` biases results toward
wherever the pin already is, so "Gulberg" resolves to the one in view rather
than an unrelated city. Same never-throws contract as `reverseGeocode`: no
token or a failed lookup returns an empty list, not an exception.

**Added a debounced search bar** floating over the map (`_SearchBox`, private
to `map_picker_screen.dart`) — 400ms after the user stops typing, it calls
`forwardGeocode` and shows up to 5 results in a dropdown; tapping one flies
the camera to it and moves the pin. Tapping the map elsewhere dismisses the
keyboard/results, matching how search fields behave everywhere else in the
app.

**Added a "my location" `FloatingActionButton`.** Extracted the
permission-check logic that already existed, duplicated, inside
`TrackingService._ensureLocationPermission()` into a shared
`lib/app/location_permissions.dart` (`ensureLocationPermission()`) — this
screen is now the second caller, and `TrackingService` was refactored to use
the shared version instead of its own copy, rather than writing a third one.
Denied/disabled location shows a `SnackBar` explaining what to do, rather than
the button silently doing nothing.

**Refactored pin-moving into one path** (`_movePin`), shared by map taps,
search results, and "my location" — a tap keeps the camera where it is
(`flyToCenter: false`, since the user just looked at that spot), the other
two fly the camera to the new point since the user's attention is elsewhere
(a search result, their real GPS position) until the map shows them what was
picked.

`flutter analyze`: 0 errors (3 pre-existing info-level deprecation notices,
same as before — no new ones). `flutter test`: 4/4 pass. `flutter build apk
--debug`: succeeds. **Not verified on-device** — no device/emulator available
in this session; please check the search bar actually returns results, "my
location" correctly requests permission and centers on your real position,
and that the Done button is now visible in both light and dark mode.

### 2026-08-18 (final pass) — Mapbox token now hardcoded as a default, verified

The previous entry's fix (adding `--dart-define` to
`.idea/runConfigurations/main_dart.xml`) turned out to be a dead end, not just
incomplete: you still hit the identical "map unavailable" state afterward.
Root cause — `--dart-define` is resolved at **compile time**. A hot
reload/restart of an already-running session keeps whatever was compiled
before the run-config edit; only a full stop + fresh run re-embeds it. Any
launch path other than that one exact IDE configuration (a different Studio
run config, a bare `flutter run`, a fresh checkout) was never going to see the
token either way. The IDE-run-config approach was fixing the symptom in one
narrow launch path, not the actual problem.

**Asked you directly before making this change**, since it reverses this
file's own "no key is ever hardcoded here" framing: `AppConfig.mapboxAccessToken`
(`transit_core/lib/src/config.dart`) now carries the public `pk.` token as a
`defaultValue`, exactly the pattern this file already uses for Cloudinary's
public cloud name/preset. The distinction that makes this the right call
rather than a policy violation: a Mapbox **public** token is *designed* to
ship inside the compiled app — that's what distinguishes it from the secret
`sk.` download token, which stays in `~/.gradle/gradle.properties` and is
never touched by this change. `--dart-define=MAPBOX_ACCESS_TOKEN=...` still
overrides the default for a different Mapbox account.

**Verified, not just asserted:** `flutter build apk --debug` with **zero**
`--dart-define` flags succeeds and produces a working token — the exact
scenario (Android Studio's plain Run button) that was crashing before.
`flutter analyze`: 0 errors (3 info lints — two `unnecessary_import`s in
`parent_profile.dart` picked up along the way, unrelated to this change, not
yet fixed). `flutter test`: 4/4 pass.

The two IDE run-config files (`.idea/runConfigurations/main_dart.xml`,
`.vscode/launch.json`) are now redundant — the default alone is sufficient —
but left in place since they're harmless and already git-ignored.

### 2026-08-18 (even later still) — fixed the on-device Mapbox crash

You ran the migration on a real device and hit exactly the failure mode the
previous entry couldn't rule out without one: `PlatformException` /
`MapboxConfigurationException` — *"requires providing a valid access token"*
— the moment a tracking screen's map tried to render, plus intermittent app
instability you saw around logging out.

**Cause, in two parts.** `MapPickerScreen` already guarded against a missing
`AppConfig.mapboxAccessToken` before ever constructing a `MapWidget` — but
`RouteMapView` (the shared map used by all three tracking screens, built
later in the same session) didn't get the same guard, so it built the native
view unconditionally. Constructing a Mapbox `MapView` with an empty token
throws straight out of the platform-view constructor, before `onMapCreated`
ever runs — Flutter doesn't catch it, hence the unhandled exception in the
log. Separately, *why* the token was empty at all: this project has two run
configs — `.vscode/launch.json` (added previous session, carries the token,
only used if you launch through VS Code) and
`.idea/runConfigurations/main_dart.xml` (Android Studio's own Run button,
which had no `--dart-define` at all). You'd been launching via Android
Studio, so every run silently had an empty token regardless of the VS Code
file being correct.

**Fixed both halves:**
- `RouteMapView` now checks `AppConfig.hasMapboxToken` before building
  `MapWidget`, exactly like `MapPickerScreen` — a missing/empty token now
  shows a plain "map unavailable" message instead of crashing, on every
  screen, regardless of how the app was launched.
- Added the matching `--dart-define=MAPBOX_ACCESS_TOKEN=...` to
  `.idea/runConfigurations/main_dart.xml`. Confirmed git-ignored
  (`git check-ignore` before editing) — the token isn't committed by either
  file.

**On the logout instability:** found no independent bug in
`session_service.dart` or the tracking screens' dispose ordering. The
`Disposing unknown platform view` log line is Android tearing down a native
view that never finished constructing — consistent with the same root cause,
not a second one. Flagged as unconfirmed rather than closed: see *What I Need
From You* #9a for what to check after this fix, and to report back if signing
out still misbehaves with a real token in place.

`flutter analyze`: 0 errors (same 10 info lints as before). `flutter test`:
4/4 pass.

### 2026-08-18 (later still) — Google Maps → Mapbox migration

**Why.** The previous entry's Maps Demo Key fix only covered the Directions/
Geocoding *HTTP* APIs — it explicitly could not confirm whether the native map
widget would render, since the demo key's documented feature list has no
"Maps SDK for Android/iOS" entry. You had a Mapbox account already set up
(both tokens generated, the Android download token placed in
`~/.gradle/gradle.properties`) and asked to switch providers entirely rather
than buy a billed Google key. This entry is the full switch: every trace of
Google Maps is gone from the repo, replaced with Mapbox.

**Fixed one real problem before touching any code:** `.env.example` contained
a live secret download token (`sk.*`) and `.gitignore` had no `.env` entry —
one `git add .` away from a committed secret. `.gitignore` now ignores
`.env`/`.env.*` and `.vscode/launch.json`; `.env.example` is a real template
with placeholders only; the actual tokens live in a git-ignored `.env` (not
read by the app — Flutter has no built-in `.env` loader here, it's just a
safer place to keep them than the tracked example file) and in a git-ignored
`.vscode/launch.json` so `F5` in VS Code just works. Recommended rotating the
`sk.` token since it briefly sat in a tracked-looking file, though it was
never actually committed.

**Two corrections to the setup plan you'd been given**, both would have broken
the build: (1) `dependencyResolutionManagement { repositoriesMode.set(FAIL_ON_PROJECT_REPOS) }`
in `settings.gradle` is incompatible with the project-level `allprojects { repositories {...} }`
block `android/build.gradle.kts` already has — Gradle would refuse to build.
The Mapbox maven repo went into that existing block instead. (2) The setup
plan's Groovy `authentication { basic(BasicAuthentication) }` doesn't compile
in this project's Kotlin DSL (`.kts`) — needed the fully-qualified
`create<org.gradle.authentication.http.BasicAuthentication>("basic")`.

**Coordinates now flow through `transit_core`'s `GeoCoord` everywhere**, not
`LatLng`. `transit_core/lib/src/models/fleet.dart` already documented the
reason for `GeoCoord`'s existence — *"Deliberately not `LatLng` —
`transit_core` must not depend on google_maps_flutter"* — so this was
finishing a boundary the codebase had already drawn, not inventing one.
Migrated: `lib/models/route_data.dart` (the ~80-`LatLng` mock waypoint array),
`lib/app/tracking_service.dart`, `lib/app/geofence_service.dart`,
`lib/main.dart` (which no longer needs to import a maps package at all inside
its background isolate — it was only ever there for one `LatLng`
constructor), `lib/app/route_service.dart`, and the `LatLng`⇄`GeoCoord`
boundary in `signup_screen.dart`, `profile_completion_screen.dart`,
`driver_service_screen.dart` and `widgets/profile_form_fields.dart` — four
hand-written conversions (`_toGeo` × 2, plus two in
`ServiceAreaFormData`) were deleted outright rather than ported, since once
`MapPointField` itself speaks `GeoCoord` they became identity functions.

**The lat/lng ordering trap, guarded, not just hand-waved.** `GeoCoord(lat, lng)`
is lat-first; Mapbox's `Position(lng, lat)` is **lng-first**. Both
constructors are positional `double`s, and for every coordinate this app uses
(Lahore, lat ≈31/lng ≈74) a swapped pair is still a *valid* position — it
throws nothing, logs nothing, and would silently put the bus in Kazakhstan.
`lib/map/mapbox_geo.dart` is now the **only** file in the repo permitted to
contain a `Position(` literal — enforced by convention and checked at the end
via `grep`, not by the type system, since both types are just two `double`s.
`test/mapbox_geo_test.dart` (the project's **first test suite**) asserts the
conversion round-trips correctly for both a single point and a list, so this
can't silently regress. All 4 tests pass.

**`route_service.dart` rewritten against Mapbox's Directions v5 and Geocoding
v6 REST APIs**, replacing the Google Routes/Geocoding calls entirely.
`fetchRoute`/`fetchDistanceDuration` request `geometries=polyline` (precision
5) specifically because `flutter_polyline_points` (already a dependency,
kept) hardcodes a precision-5 decode divisor — Mapbox's higher-precision
`polyline6` would silently decode to wrong coordinates with this decoder,
and nothing at runtime would catch that. `optimize` on `fetchRoute` is now a
documented no-op: Mapbox Directions always visits waypoints in the given
order — reordering is a separate product (the Optimization API), not
requested here. `reverseGeocode` returns `properties.full_address` from the
v6 GeoJSON response. `RouteService.fetchRoute`/`fetchDistanceDuration` remain
dead code today (nothing calls them) exactly as before — only
`reverseGeocode` has a live caller (`MapPointField`).

**The map-rendering rewrite — the actual hard part.** Google Maps is
declarative (`Set<Marker>` in, diffed for you); Mapbox is imperative (await a
manager, then `create`/`update`/`delete`), and the bus position ticks every
150 ms. New shared infrastructure in `lib/map/`:
- `route_map_controller.dart` — owns the annotation lifecycle. The 6 stop pins
  are created once and only ever re-touched on an actual status *change*
  (`TrackingService.stopStatusRevision`, new — a `ValueNotifier<int>` bumped
  only on a real transition, not on every tick). The bus is one
  `PointAnnotation` held and `update()`-ed in place, never recreated, via a
  latest-wins coalescing update: if a platform call is still in flight when
  the next tick arrives, the new position simply overwrites the pending one
  rather than queuing — never more than one in-flight call, no tick silently
  dropped, no timer needed since `TrackingService`'s own 150 ms cadence
  already paces it. Every `await` boundary re-checks a `_disposed` flag, and
  `attach()` guards against `onMapCreated` firing twice (a real Android
  platform-view-recreation case) by tearing down any existing managers first.
- `route_map_view.dart` — the shared widget that replaces the near-identical
  `GoogleMap` block that used to live separately in all three tracking
  screens.
- `map_icons.dart` — the bus icon's canvas-drawing code from `driver_route.dart`
  is reused almost as-is (Mapbox's `PointAnnotationOptions.image` also just
  takes PNG bytes), now memoised app-wide instead of re-rasterising per mount,
  and rasterised at `devicePixelRatio` scale — Mapbox's icon field has no
  separate scale parameter, so an un-scaled icon renders at a third of its
  intended size on a 3× phone. Five pre-rasterised teardrop pins replace
  Google's `defaultMarkerWithHue`, using `AppTheme`'s actual palette instead
  of hues that never matched it — a real, if cosmetic, fix: the driver
  screen's legend already used `success`/`purple`/`info`/`warning`, which the
  old Google hue markers didn't match.
- `map_style.dart` — theme-aware `MapboxStyles.LIGHT`/`DARK`, matching your
  choice. A theme toggle forces the `MapWidget` to rebuild via a `ValueKey`
  (Mapbox style reloads don't reliably bring annotation managers back on
  their own) — an intentionally simpler, more certain-to-work choice than
  Mapbox Standard's `lightPreset` import-config mechanism, which would avoid
  the rebuild but is unverified against this package version.

**Two real, pre-existing bugs fixed as a side effect of removing the blanket
`setState`.** The old Google Maps screens called `setState(() {})` on every
150 ms tick to rebuild `Set<Marker>`/`Set<Polyline>` — Mapbox's imperative
model needs none of that, so those calls are gone, which is a real perf win
(the whole scrollable screen, not just the map, was rebuilding at 6.7 Hz). But
two widgets were quietly relying on that blanket rebuild to stay fresh with no
listenable of their own: the "stops left" stat chip and the route-progress
timeline in `parent_tracking.dart`, and the stop list in `driver_route.dart`.
All three now wrap in `ValueListenableBuilder<int>` on
`stopStatusRevision` instead — the same notifier the map layer uses, so they
update exactly when a stop's status actually changes, not on every tick and
not never.

**Consequences worth knowing about, not hidden:**
- `trafficEnabled: true` has no Mapbox equivalent (traffic is baked into
  specific, non-theme-aware styles) — dropped. No screen surfaced or acted on
  traffic data.
- `InfoWindow`s (tap-a-marker-see-a-snippet) have no Mapbox equivalent. Dropped
  from the parent/student maps (redundant — both already list every stop with
  its time in the timeline below the map). Not yet rebuilt on the driver map
  either, where the snippet carried real info (`scheduledTime`/`studentCount`)
  — a tap-driven Flutter card is the natural replacement but wasn't built this
  session; flag if you want it.
- `AppTheme.warning` and `studentAmber` are the same hex, which would have
  made "destination" and "your stop" pins indistinguishable (they're
  currently orange vs yellow) — used `warningLight` for destination instead.
- Gestures (pan/zoom/rotate) are off by default on the two 220px parent/student
  maps, since they sit inside a `SingleChildScrollView` and a pan-capturing
  native view would otherwise fight the page scroll — a latent bug the old
  Google Maps screens had too, now actually fixed. The driver map opts in
  (`interactive: true`) since its Follow/Free toggle implies panning.
- `map_picker_screen.dart`'s old "are tiles loading" probe
  (`GoogleMapController.getVisibleRegion()`) was pure camera math that never
  actually failed whether tiles loaded or not — porting it would have produced
  a banner that never appears. Replaced with three real signals layered
  together: `AppConfig.hasMapboxToken` checked synchronously before even
  building the `MapWidget`, `onMapLoadErrorListener` for runtime failures, and
  an 8-second watchdog timer for the silent-failure case where neither
  callback ever fires.

**Cleanup.** Removed `google_maps_flutter` from both `transit_pro/pubspec.yaml`
and `transit_admin/pubspec.yaml` (admin declared it but never imported it —
already flagged as dead in the admin app's own README) and the unused
`permission_handler` dependency (declared, never imported anywhere in `lib`).
Deleted `assets/map_style.json` in both apps (a Google Maps JSON style;
meaningless to Mapbox, which takes a style URI instead) and its two pubspec
entries. Removed the hardcoded Google Maps API key from
`AndroidManifest.xml`'s `com.google.android.geo.API_KEY` meta-data and from
`import GoogleMaps`/`GMSServices.provideAPIKey(...)` in `AppDelegate.swift` —
**both hardcoded Google keys are now gone from the repo entirely.** Bumped iOS
`IPHONEOS_DEPLOYMENT_TARGET` from 13.0 to 14.0 (Mapbox's minimum) in all three
build configurations; iOS otherwise untouched and unbuilt (no `Podfile` exists,
Mapbox's iOS pod also needs a `~/.netrc` with the download token, and iOS
remains out of scope for the pilot per the ⏸️ table).

`AppConfig.googleMapsApiKey`/`hasMapsKey` are gone from `transit_core/lib/src/config.dart`,
replaced by `mapboxAccessToken`/`hasMapboxToken` — one token now covers both
the native widget (`MapboxOptions.setAccessToken` in `main()`) and the HTTP
APIs, where Google needed the native key from the manifest and a separate one
for HTTP.

**Final verification, all in this session:**
- `flutter analyze` in both packages: **0 errors** (10 info-level lints — the
  same pre-existing ones minus one, `dart:ui`'s now-gone unnecessary import in
  `parent_tracking.dart`, plus 3 new ones for intentionally-used-but-deprecated
  Mapbox APIs — `cameraOptions`/`onTapListener` — chosen over their
  replacements (`viewport`/`addInteraction`) because they're simpler and this
  package version's docs for the replacements were incomplete).
- `flutter test`: **4/4 pass** (the new lat/lng round-trip suite).
- `flutter build apk --debug --dart-define=MAPBOX_ACCESS_TOKEN=...`: **succeeds**
  — this is real proof the Mapbox maven authentication, the download token,
  `minSdk 24`, and the entire Dart migration all compile and package together
  correctly. It is *not* proof anything renders correctly — see *What I Need
  From You* #9 for the on-device checklist, which needs a real device or
  emulator this session had neither of.
- `grep -rn "google_maps_flutter\|LatLng\|GOOGLE_MAPS_API_KEY"` across both
  apps: zero hits. `grep -rn "Position("` outside `mapbox_geo.dart`: zero hits.

### 2026-08-18 (even later) — Maps HTTP calls wired, Email/Password confirmed, doc cleanup

**`RouteService` rewritten to actually work with the Maps Demo Key.** The
previous implementation called the legacy Directions API
(`maps.googleapis.com/maps/api/directions/json`), which isn't on the demo
key's documented feature list — it would very likely have failed with
`REQUEST_DENIED` the first time anything called it (nothing did; it was dead
code). It now calls the Routes API's `computeRoutes` (POST,
`X-Goog-Api-Key`/`X-Goog-FieldMask` headers, JSON body) for both the polyline
and distance/duration, which the demo key's feature list does cover. Also
added `reverseGeocode()`, against the standard Geocoding API. `apiKey`
defaults from `AppConfig.googleMapsApiKey` now instead of sitting unset forever
— still empty unless you build with
`--dart-define=GOOGLE_MAPS_API_KEY=...`, per `config.dart`'s existing
no-hardcoded-keys rule.

**`MapPointField` now shows a real address, not raw coordinates.** Converted
from stateless to stateful so it can kick off `reverseGeocode()` when a pin
changes and redraw once it resolves; falls back to
`31.520400, 74.358700`-style coordinates while the lookup is in flight, on
failure, or with no key configured — never a blank field. `flutter analyze`:
0 errors, same 8 pre-existing info lints.

**What this doesn't touch:** whether `MapPickerScreen`'s native map tiles
render at all. The demo key's feature list has no "Maps SDK for Android/iOS"
entry — only Maps JavaScript API (web) and the Web Service APIs above — so if
the picker is still showing its grey "map tiles are unavailable" banner, that
is a different, unresolved question this change doesn't answer. No
device/emulator is available in this session to check either way; asked you to
confirm in 🏃 Next Actions. Also still true: nothing in the UI calls
`RouteService.fetchRoute` to actually draw a route anywhere yet — the service
works now, but no screen asks it to.

**Maps key restriction dropped from tracking**, per your call — see *What I
Need From You* #2 (now resolved/struck-through for the HTTP-wiring half; the
restriction half is just gone rather than left open).

**Email/Password sign-in confirmed enabled**, per you. Item 3 marked resolved.
Not independently re-verified against a live sign-in in this session.

**Gemini API key incoming** — you said you'll share it. Noted in item 8; no
code changes needed until it arrives, since Phase 3 doesn't consume it yet.

**Document reorganized for readability**, per your feedback that open and
finished work were hard to tell apart. Changes: the *What I Need From You* and
*Open Questions* sections keep resolved items visually distinct (struck-through
headers, already the convention, now applied more consistently) and 🏃 Next
Actions was rewritten to state plainly that nothing is currently blocking
rather than listing stale blockers. The Phase tables and the ⚠️ notes under
them remain the fastest place to check one task's exact status; this
Changelog stays a historical, append-only narrative — read it for *why*
something changed, not *what's currently true* (the sections above are always
the current-truth source).

### 2026-08-18 (later) — rules confirmed live, real app id, real notification banners

**Rules.** You confirmed both `firestore.rules` (with the 2026-08-17
`ride_requests`/`students` changes) and `database.rules.json` are published.
Closes out item 6b, the standing top blocker on the whole driver↔family flow —
see P1-8, P1b-10 and item 5/6/6b above. Not independently re-verified against a
live listener in this session (no device available here); the manual walkthrough
in 🏃 Next Actions is still the way to actually confirm it, not just that the
console accepted the publish.

**P0-5 — `applicationId`/bundle id renamed to `com.transitpro.app`.** Every
in-repo reference to the `com.example.transit_pro` / `com.example.transitPro`
placeholder is gone:
- `android/app/build.gradle.kts` — `namespace` and `applicationId`.
- Kotlin sources moved from `android/app/src/main/kotlin/com/example/transit_pro/`
  to `.../com/transitpro/app/` (`git mv`, so history follows the files) —
  `MainActivity.kt`, `MainApplication.kt`, `BusTrackingService.kt`,
  `BootReceiver.kt` — package declarations updated to match.
- `BusTrackingService.CHANNEL_NAME` and the matching `MethodChannel` string in
  `lib/main.dart` — these have to agree exactly, since one names the channel from
  the Kotlin side and the other from Dart.
- `ios/Runner.xcodeproj/project.pbxproj` and `macos/Runner.xcodeproj/project.pbxproj`
  — `PRODUCT_BUNDLE_IDENTIFIER` for the app and both test targets;
  `macos/Runner/Configs/AppInfo.xcconfig` too.
- `lib/firebase_options.dart` — `iosBundleId` on both the `ios` and `macos`
  `FirebaseOptions`. Their `appId`/`apiKey` are untouched: those are the *actual*
  Firebase-registered iOS app's identifiers, still tied to the old bundle id on
  Google's side until you register a new iOS app (item 1b) — a local field edit
  can't fix that half.

**This deliberately breaks the current build until you act** — see item 1b.
`google-services.json` is untouched on purpose: editing it by hand to claim a
package-name match it doesn't have would satisfy the Gradle plugin locally but
not Google's OAuth backend, so Google Sign-In would still fail with
`DEVELOPER_ERROR`. That half needs your Firebase console access.

**Reverted, same day.** You asked for this rename to be undone. Every file
above is back to `com.example.transit_pro`/`com.example.transitPro` — the Kotlin
sources moved back with `git mv`, and `git diff` against the last commit shows no
change on any of them. P0-5 is open again, not done; pick a real id whenever
you're ready and this is the exact set of files it touches again.

**Google Maps key.** Confirmed already placed in `AndroidManifest.xml` and
`AppDelegate.swift` (P0-2 done). Wrote up the two follow-ups in *What I Need From
You* #2: restrict the key to your app's package + SHA-1s (it's currently wide
open), and use a *second*, separately-restricted key for the Directions/Geocoding
HTTP calls `AppConfig.googleMapsApiKey` feeds — an Android-app-restricted key
would reject those, since that restriction checks headers only the native Maps
SDK sends.

**P1b-15 — remote notifications now raise a real system-tray banner.**
`NotificationService.bindToUser` previously only updated the in-app
`ValueNotifier` when a new `notifications/{uid}/items` document arrived — a
driver's SOS or a ride-request reply reached the recipient's Firestore listener,
but nothing put it in front of them unless they happened to already have the
notifications screen open. It now diffs each snapshot against the doc ids
already seen on this stream and calls the local-notifications plugin directly
for anything new and unread, skipping the very first snapshot after bind (that's
the existing inbox catching up, not a fresh arrival, and would otherwise replay
someone's whole history as banners on every login).

This was the immediate, no-infrastructure alternative to P1b-14 (real FCM push),
which you deferred today rather than enable Firebase's Blaze plan — see
Question 8 and *What I Need From You* #8b for the two real options (a Cloud
Function, or an external relay) whenever you want push to reach a fully-closed
app. What ships today only fires while the recipient's app process is alive
(foreground or backgrounded-but-running, the same condition `BusTrackingService`
already keeps true on Android) — a swiped-away app still won't see it, and
nothing but a genuine OS push can close that gap.

`flutter analyze`: **0 errors** in both packages (the same 8 pre-existing info
lints as before). Native Android/iOS/macOS changes aren't picked up by
`flutter analyze` — it doesn't invoke Gradle or Xcode — so the `google-services.json`
breakage described above won't show up until you actually build.

### 2026-08-18 — driver-defined routes, per-round seats, and the request flow

The feature the app was missing: drivers describe their own service and families
book a seat on it. Previously a student reached a driver only through an
admin-assigned `route`, and no admin exists in the pilot loop — so a
self-signed-up driver and a self-signed-up family had no way to find each other
at all.

**New domain concepts** (`transit_core`, all additive):
- `ServiceArea` — one institution a driver serves, with an optional map pin.
- `DriverSchedule` — a **round**: direction, time window, and its own seat count.
  Seats live per round, not per vehicle, because a 12-seater running a 6:30 group
  and a 7:30 group offers 12 seats *twice*. Hanging capacity off the vehicle would
  under-report availability by however many rounds the driver runs.
- `RideRequest` — `ride_requests/{driverId}_{studentId}`. The composite id is
  load-bearing three times over: it makes duplicate requests impossible, it lets a
  family re-ask after a decline without leaving history behind, and it is the only
  reason a security rule can authorise a driver to write an assignment onto a
  student document they do not own — a rule can only `get()` a document it can
  *name*.
- `DriverMatch` — the output of matchmaking, carrying *why* a driver ranked where
  they did so the screen and the ranking cannot disagree about "3.1 km away".
- `Driver` gained `serviceAreas`, `serviceRadiusKm`, `baseLocation`, `schedules`.
- `Student` gained `driverId`, `scheduleId` (the direct link — a self-signed-up
  driver has no route to go through) and `publicCode`.
- `GeoCoord.distanceKmTo` (haversine) for client-side proximity ranking.

**Unique student identity.** Two parents can both register a "Jack Jones", and a
driver reading their roster has to tell them apart out loud. `Student.publicCode`
is `TP-` plus six characters *derived from the Firestore document id* — so it
inherits that id's uniqueness rather than needing a collision check a batched write
could not perform anyway. `O`/`I` are folded to `0`/`1` so the code survives being
read over a phone. Separately, `ProfileRequirements` now rejects two children with
the same name on one account: almost always a double-tap on "Add child", and the
two records would be indistinguishable on a driver's roster.

**Seat booking is transactional.** `RideRequestRepository.accept` moves the
request's status and the round's `bookedSeats` in one Firestore transaction.
Without it, two families racing for the last seat both read `availableSeats: 1`,
both writes succeed, and the round is oversold with nothing in the data to show it.
Linking the student to the driver is deliberately a *second*, non-atomic write —
the rule authorising it checks that the request is already `accepted`, and a rule
evaluates against committed state, so a same-transaction write would still see
`pending` and be denied. The alternative — an atomic pair guarded by a rule loose
enough to permit it — would let any driver claim any student. Re-tapping Accept
repairs a failed link without re-booking the seat.

**Editing a schedule cannot un-book anyone.** `RideMatchService.saveSchedules`
takes `bookedSeats` from the live document, matched by round id, never from the
form. It refuses to shrink a round below what is booked, and refuses to delete a
round that still has students — both of which would otherwise leave families
pointing at capacity or a round that no longer exists.

**New screens**
- `/driver/ride-requests` — the inbox. Accept / decline / release, with live
  per-round seat counts above the list, so accepting is a decision made with the
  cost visible. Accept is disabled on a round that filled up since the request
  arrived; the transaction would refuse it anyway, but the driver should not have
  to hunt for what they did wrong.
- `/driver/service` — edit service areas, radius, base location and rounds.
- `/parent/find-drivers` and `/student/find-drivers` — ranked recommendations and
  the request flow. One screen for both roles: a student books their own seat
  exactly as a parent books their child's.
- Dashboard entry points on all three roles, plus two rows in the driver profile
  menu. Each states the *gap* when there is one: a driver with no listed school is
  invisible to every parent while their profile reads as finished, and this is the
  only place the app can tell them.

**Matchmaking deliberately avoids composite indexes.** One
`arrayContains` on a normalised `serviceSchools` mirror, then seats, distance and
`serviceRadiusKm` filtered in memory. `serviceRadiusKm` is not expressible as a
Firestore filter without a geohash scheme this pilot does not need, and every
composite index in this project has to be created by hand through a console link —
each one a way for the app to break in production while working in development.
The same reasoning removed the `orderBy('monthKey')` from all three
`PaymentRepository` queries: that is the exact `FAILED_PRECONDITION` hit on
2026-08-17, and sorting `YYYY-MM` strings in memory costs nothing.

**Payments off mock data.** `parent_fees`, `student_fees` and
`driver_payment_history_screen` now read the `payments` collection through
`SessionService.payments`. Their triplicated `_amountToInt` / `_sumByStatus` /
`_formatRs` — which parsed money back out of `'Rs.2,500'` with a regex, the exact
thing integer paisa was meant to end — are replaced by
`lib/widgets/payment_presentation.dart`. Three real bugs fixed on the way:
- Outstanding balance excluded overdue, so a month vanished from the balance
  exactly when it went overdue.
- `parent_fees` showed the same fees regardless of which child was selected.
- The student screen's outstanding-balance label was hardcoded white, invisible in
  light mode.
- `refunded` had no colour anywhere; the driver screen's switch fell through to
  cyan and the fee screens had no case at all.

The driver's rows name the **student**, never the payer — `firestore.rules`
restricts `users/{uid}` reads to the owner or an admin, so a parent's name is
genuinely unreadable to a driver. That is a correctness decision, not an omission.

**Notifications are real.** `NotificationService` streamed nothing before — its
history was seven hardcoded `AppStrings.t('seed_…')` entries. It now merges the
Firestore inbox (`notifications/{uid}/items`, bound and unbound from
`SessionService.start`/`stop` so a new sign-in path cannot forget it) with
device-local geofence alerts, and `markAllRead` writes through instead of only
updating memory — without which every remote item came straight back unread on the
next snapshot. Every trigger point in `RideMatchService` writes one.

**This is not FCM, and cannot be from a Flutter client** — see *What I Need From
You* #8b. `firebase_messaging` was deliberately not added: it would let the app
receive a push nothing is able to send.

**The driver's SOS and "Alert All Parents" now actually reach parents.** Both called
`NotificationService.show()`, which raises a notification on the *driver's own
phone* and nowhere else — so a driver triggering an SOS got a confirmation
animation for an alert no family received. They now also write to
`notifications/{parentUid}/items` for everyone on the roster, de-duplicated so a
parent with two children on the vehicle gets one alert. When the roster is empty the
driver is told the alert went nowhere, rather than being shown a tick.

The message bodies were also hardcoded to `'Bus #42'`. A parent reading "SOS – Bus
#42" about a driver who runs Bus #7 will look for the wrong vehicle, so the text now
substitutes the real `busNumber` (falling back to the plate, then to a neutral
phrase — never an invented number).

**Two pre-existing bugs found while writing the rules:**
1. **Student self-signup could never have worked.** `students` create required
   `parentId == uid()`, but a self-registering student writes an empty `parentId`.
   The Auth account and `users/{uid}` document would be created and only the
   `students/{uid}` write in the same batch would fail — landing the user in a
   complete-looking account with no student record.
2. A student could not edit their own `students/{uid}` record at all; the rule only
   ever named the parent.

**The driver's roster is now grouped by round.** `driver_booked_students_screen`
(a main driver tab, previously 14 hardcoded passengers) reads
`SessionService.roster` merged with `routeStudents`, split into one section per
round with that round's live seat count, and shows each student's `displayCode`
where the fake bus number used to be. A student whose `scheduleId` is null or points
at a deleted round gets a "Not assigned to a round" section rather than being
dropped — a child on the vehicle but absent from the driver's screen is a child left
at the roadside.

**Two things were removed rather than rewired, and you should know:**
- `driver_search_screen.dart` is **deleted** — unreferenced dead code superseded by
  `find_drivers_screen.dart`, carrying a latent crash (`int.parse('2.3')` in its
  distance sort). Recoverable from git if you want it back.
- The passenger detail sheet's **chat thread and quick-alert chips are gone.** The
  chat was a hardcoded message list. The alert chips called
  `NotificationService.show()`, which raises a notification **on the driver's own
  phone** — it never reached the parent, so a driver tapping "alert the parent"
  got a confirmation for a message nobody received. That is worse than no button.
  Real family messaging belongs to `MessagingRepository`; the sheet now shows live
  fields plus Remove and Close.

`flutter analyze`: **0 errors, 0 warnings** in both packages (8 pre-existing info
lints). `flutter build apk --debug`: succeeds.

⚠️ **Not verified on-device at the time this entry was written.** The new rules
had not been published yet, and until they were every seat request failed with
`PERMISSION_DENIED`. **Update, same day:** you've since confirmed the rules are
published (see the newer 2026-08-18 entry above, and item 6b) — but that closes
the blocker, not the verification. Nothing in this entry should be read as
*working* until the manual walkthrough in 🏃 Next Actions has actually been run
against a real driver and parent account.

⚠️ **Still on mock data:** `driver_attendance`, both trip-history screens, the
driver dashboard's stat tiles, and `lib/models/route_data.dart`. These need
`trips` and `attendance`, which is Phase 2 (P2-6).

⚠️ **`Future.delayed` still simulating work** in `complaint_submission_screen`,
`pickup_dropoff_confirmation_screen`, `emergency_alerts_screen`, `payment_screens`,
`student_attendance`, and the three echo-bot chat screens. Each of these needs the
collection behind it before the delay can be replaced by a real write, so they were
left rather than half-converted. (The delays in `role_selection_screen`,
`profile_completion_screen` and `missed_bus_service` are legitimate — animation
timing and a deliberate resolution timeout, not fake latency.)

**One design decision worth your review.** The spec asked for a
`pending_verification` payment status. `PaymentStatus` was left as
`{pending, paid, overdue, refunded}` and that state is represented by
`paidAt != null && status != paid` instead — the fee screens render it as
"Awaiting confirmation". The reason is that `PaymentStatus` lives in
`transit_core`, which `transit_admin` also imports: adding a case there means the
admin app's `switch`es change too, and a status the admin app does not yet write is
a status no parent will ever see. Deriving it from `paidAt`, which
`PaymentRepository.submitPayment` already sets, gets the same user-visible
behaviour with no cross-app migration. Say the word if you would rather have the
explicit enum case.

### 2026-08-17 (yet later) — missing payments index + a genuine onboarding race

Rules are now confirmed live and working — a real `users/{uid}` doc with
`role: 'parent'`, `profileComplete: false`, correct `createdAt`/`updatedAt`
showed up in the console exactly as expected. Two new, unrelated issues
surfaced once that unblocked things:

**1. Missing Firestore composite index for `payments`.** The moment a parent
account exists, `ParentDataService._loadFees` queries
`payments where parentId == X order by monthKey desc`, which Firestore cannot
serve without a composite index:

```
FAILED_PRECONDITION: The query requires an index. ...
```

`PaymentRepository.watchForStudent` and `.watchForDriver` have the identical
shape and will fail the same way the first time a student or driver loads
fees/payment history — fixed all three, not just the one that happened to
fire first.

- Added `firestore.indexes.json` — `payments` indexed on
  (`parentId` ↑, `monthKey` ↓), (`studentId` ↑, `monthKey` ↓),
  (`driverId` ↑, `monthKey` ↓).
- `firebase.json` gained `firestore`/`database` deploy-config sections
  (alongside the existing FlutterFire `flutter` config, which is untouched) so
  `firebase deploy --only firestore:indexes` becomes possible once the CLI is
  set up.
- Added `.firebaserc` pinning the default project to `transitpro-db`.
- **Immediate unblock, no CLI needed:** the error itself carries a direct
  console link that pre-fills the exact index — click it, click "Create
  Index," wait ~1–2 minutes for it to build.

**2. A genuine race in `ProfileCompletionScreen`'s role resolution.** On a
brand-new account, the router reaches `/complete-profile` *because*
`SessionService` reacted to the just-written profile doc — but Flutter
schedules that navigation for the next frame, and `ProfileCompletionScreen`
was resolving the role exactly once, synchronously, in `initState()`. That
window — usually closed, but not guaranteed — is almost certainly why the very
first Google sign-in attempt could show the "lost track of your role" fallback
even though the document already existed correctly, while an immediate retry
against that same (now-settled) document always worked.

Fixed: `_resolveRole()` now waits up to 5 seconds on a `SessionService.user`
listener before declaring the role missing, instead of failing on the first
synchronous check. A brief spinner is shown during that wait — never the "lost
track" card, since at that point the app genuinely just hasn't heard back yet.
The card still exists for an actual timeout (a real backend failure), just no
longer as the outcome of an ordinary scheduling gap.

`flutter analyze`: 0 errors in both packages. `flutter build apk --debug`:
succeeds. **Verified on-device 2026-08-17**: composite index created via the
console link, first-time Google sign-in for a new parent account goes straight
to Complete Profile with no error screen. This closes out the auth/onboarding
work opened on 2026-08-17 — Phase 1's account layer is now confirmed working
end to end, not just compiling.

### 2026-08-17 (later still) — the *real* "lost track of your role" cause

The fix earlier today (writing the role into `users/{uid}` immediately) was
correct but incomplete: it didn't account for Firestore rejecting that write
outright. Reproduced on-device: Google Auth succeeds, then

```
Listen for QueryWrapper(...users/{uid}...) failed:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.}
```

**This is item 6 in "What I Need From You" below, still unresolved:
`firestore.rules` has never been deployed.** A Firestore database created in
production mode starts on a deny-everything default until a real rule set is
pushed with `firebase deploy --only firestore:rules,database`. Every
`users/{uid}` read or write — onboarding, login, everything — hits that wall
identically. No code change fixes this; it needs your Firebase login.

What *was* a real bug, now fixed: `SessionService` and `AuthService` treated
"Firestore refused the request" the same as "no profile exists yet," so a
permission error silently routed the user into the same misleading
"choose your role again" screen, which then failed the identical way on every
retry — a loop with no visible exit.

- `SessionState` gained `error`, distinct from `needsProfile`. A stream
  *erroring* (permission-denied, backend outage) now sets `error`; a stream
  succeeding with no document still correctly sets `needsProfile`. The router
  guard never routes `error` into onboarding.
- `SessionService.start()` now re-subscribes after `error` even for the same
  uid — a Firestore listener that has errored is dead and will never emit
  again, so a same-account retry used to silently reuse a listener that could
  never recover.
- `AuthService.signInWithGoogle`, `.signIn`, and `.signUp` all now catch
  `FirebaseException` explicitly, sign out cleanly, and surface an honest
  message ("the server rejected the request... try again shortly") instead of
  either the misleading role-loop or, for `signIn`, an outright uncaught
  exception (only `FirebaseAuthException` was handled there before — a
  Firestore error would have crashed past it).
- `welcome_screen._routeOnward()` handles `session.hasError` on a cold start
  the same way: sign out, back to `/role-select`, rather than routing by a
  stale cached role into a dashboard that would just hit the same wall loading
  its own data.
- `router.dart`'s "signed in but sitting on `/login/*`, bounce to dashboard"
  rule now requires `session.isReady`, not just `isSignedIn`. Without this, a
  failing Google attempt exposed a real race: `AuthService.signOut` tears down
  the Firestore session before ending the Firebase Auth one, and during that
  window `isSignedIn` is still true — long enough for the guard to bounce the
  user into a dashboard mid-failure, instead of leaving them on the login
  screen to see the error.
- `login_screen.dart`'s inline error `Row` gained an `Expanded` — the longer,
  more honest error text was overflowing it (visible in the reported repro as
  a `RenderFlex overflowed by 21 pixels` exception).

`flutter analyze`: 0 errors in both packages. `flutter build apk --debug`:
succeeds. **Not independently verified against a live Firestore instance** —
cannot be, until the rules are deployed.

### 2026-08-17 (later) — fix "lost track of your role", drop Google from Signup

The role-recovery design from earlier today (`AuthService.pendingRole`, a
SharedPreferences hint) was itself the failure mode being reported as *"We
lost track of your roles. Choose the roles again."* Any gap in that hint
being set or restored — and there was no Firestore record to fall back to
until the onboarding form was actually submitted — surfaced as that error.

Replaced with a stronger invariant: **a `users/{uid}` document now exists,
with a role on it, before `AuthService.signInWithGoogle` ever returns for a
first-time account.**

- `signInWithGoogle` takes a required `role: UserRole` — always available,
  because Google is only ever offered from a specific `/login/:role` screen
  now (see below). On a brand-new account it writes `users/{uid}` immediately
  — `role`, `name`, `email`, `photoUrl`, `profileComplete: false` — before
  returning `GoogleNeedsProfile`. A returning user who closed the app before
  finishing onboarding gets that same stored record read back, never
  recreated.
- `AuthService.pendingRole` and its SharedPreferences key are deleted
  entirely — there is nothing left for them to do.
- `ProfileCompletionScreen._resolveRole()` now reads exactly one source:
  `AuthService.currentUser?.role ?? SessionService.user.value?.role` — a
  profile the app already fetched or just wrote, never a client-side guess.
  `AuthService.currentUser` is checked first specifically because it is set
  synchronously inside `signInWithGoogle`, so resolution does not race the
  Firestore snapshot listener that feeds `SessionService`.
- **Signup screen: Google removed entirely** (`_googleContinue()` and its
  "Or continue with Google" button deleted). Signup is manual registration
  only — email/password plus the full role-specific form. Google sign-in
  exists solely on the Login screen, offered per-role exactly as email/password
  login is.
- Verified the "click Parent, back, click Student" scenario explicitly: each
  role card / route param produces a fresh value read at the moment "Continue
  with Google" is tapped (`go_router` rebuilds `LoginScreen` per navigation;
  the role is passed as an explicit argument, not cached) — no stale-role path
  exists.

Abandonment handling (already correct from the earlier change, now on firmer
footing): the router guard forces `/complete-profile` for any signed-in user
whose stored `profileComplete` is `false`, regardless of how they got there —
restart, re-authentication, or deep link — so a half-finished Google signup
can never reach a dashboard.

`flutter analyze`: 0 errors in both packages. `flutter build apk --debug`:
succeeds.

### 2026-08-17 — stop re-asking for a role during Google onboarding

`ProfileCompletionScreen` had grown its own role-picker step, which duplicated
`/role-select` — the app already asks for a role exactly once, before the login
or sign-up screen is even reached. Fixed:

- `AuthService` gained `pendingRole` — set by `login_screen.dart` and
  `signup_screen.dart` right before they navigate to onboarding, and restored
  from `SharedPreferences` in `preload()` so the role survives an app kill
  that happens mid-onboarding (before the profile document exists anywhere to
  read it back from). Cleared on sign-out and once a profile is written, so it
  never leaks into a different account signing in next.
- `ProfileCompletionScreen._resolveRole()` now checks, in order: (1) an
  existing profile document's role — covers accounts created before
  `profileComplete` existed, where the role is already rule-enforced and must
  never be re-asked; (2) `AuthService.pendingRole`. The router's `extra:
  UserRole` plumbing for `/complete-profile` is gone — that was a second, less
  reliable path to the same information.
- The in-screen role-picker step is removed entirely. The one remaining
  fallback (`_roleMissing`) is not a role picker — it hands the user back to
  `/role-select`, signing out first, since the router guard would otherwise
  bounce a signed-in `needsProfile` user straight back to onboarding no matter
  what URL they asked for.
- Checked the "pick Parent, go back, pick Student" case explicitly: `/login/:role`
  and the sign-up screen's role cards both rebuild fresh state per selection
  (route param vs. `setState`), so the role captured at the moment "Login with
  Google" is tapped is always the one currently on screen — no stale-role bug
  existed there, but it's now covered by `_role` being read fresh via
  `AuthService.pendingRole` rather than any long-lived cached value.

`flutter analyze`: 0 errors in both packages. `flutter build apk --debug`:
succeeds.

### 2026-08-16 — auth refactor, Google onboarding, live profile data

**P1-15 → P1-19 done.** `flutter analyze`: **0 errors** in both packages (8
pre-existing info lints remain). `flutter build apk --debug`: succeeds.

Four real defects found and fixed:

1. **Logout never logged anyone out.** All three layouts called
   `AuthService.clearRole()`, which removes a SharedPreferences key and nothing
   else — the Firebase session survived, so `isSignedIn` stayed true and a
   relaunch dropped the user back into the dashboard. Replaced with one shared
   `confirmAndSignOut()` that cancels the Firestore listeners, revokes the
   Google grant, ends the session, then clears the cached role.
2. **Sign-up discarded most of what it collected.** Children, vehicle
   number/type/seat capacity, licence and ID photos, student ID, school, pickup
   and dropoff were all typed in and then dropped. Both routes now build a
   `ProfileDraft` and go through one `OnboardingService.provision()`.
3. **Google sign-in threw an uncaught `PlatformException`** — only
   `FirebaseAuthException` was caught, so an unregistered SHA-1 surfaced as an
   unhandled exception with the spinner stuck on.
4. **Pickup and dropoff were marked required but never validated.**
   `_missingStudentField()` only checked name and school. `ProfileRequirements`
   is now the single validator both forms use.

New:
- `SessionService` — one global store fed by Firestore streams, with a
  `loading` state so the router does not bounce a valid user into onboarding
  during the first frames after launch.
- `/complete-profile` — mandatory, role-aware onboarding for Google accounts.
  No `users/{uid}` document is written until the role is chosen, because
  `unchanged('role')` in the rules would freeze a wrong guess permanently.
  Trapped with `PopScope`; the only exits are finishing or signing out.
- Google is now offered for **all three roles**. A Google driver fills in
  licence and vehicle on the completion screen and still lands in
  `pendingVerification`.

Model additions (`transit_core`, all additive): `AppUser.profileComplete` and
`.emergencyContacts`, `Student.pickupLocation`/`.dropoffLocation`,
`Bus.vehicleType`, `Driver.timingSlots`, `GeoCoord.fromMapOrNull`.

`firestore.rules`: `buses` was admin-write-only, so a self-signing-up driver
could not create their own vehicle. A driver may now create and edit the bus
that points at them, but never reassign it or put it on a route.

Hardcoded identity removed. `'Sarah Johnson'`, `'Ahmed Raza'`, `'Noorulain'`,
`'STU-2042'`, `'Bus #42'` and `'Rs.2,500'` are gone from all three data services
and from the three dashboard headers. Ratings moved from SharedPreferences to
`ratings/{driverId}_{raterId}_{weekKey}` (the composite id *is* the
one-per-week rule), and fee state now reads `payments` instead of a local set a
parent could forge by reinstalling.

⚠️ **Consequence:** derived fields show honest empty states until data exists.
Unassigned children read "No bus assigned yet", driver stats are blank, fees
show nothing. `buses`, `routes`, `trips` and `payments` are all empty until the
admin app or a seed script populates them — see P1-20.

⚠️ **Still hardcoded, out of this change's scope:** several screens hold their
own local mock arrays rather than reading a service — `parent_fees`,
`student_fees`, `driver_payment_history`, `driver_booked_students`,
`driver_attendance`, both trip-history screens, and the driver dashboard's stat
tiles. These need the `payments`, `trips` and `attendance` collections, which is
Phase 2 work (P2-6) plus a fees migration.

### 2026-08-12 (router guard)
- **P1-14 done.** Added a `redirect` guard and a `refreshListenable` bound to
  `authStateChanges` in `router.dart`. Protected routes now bounce signed-out
  users to `/role-select`, and signed-in users are bounced off login/signup to
  their own role home. `/splash` is exempt so the launch animation keeps control
  of its own routing.
- Phase 1's auth track is complete: real sign-up, sign-in, password reset,
  password change, and route protection. `flutter analyze`: 8 info lints, 0 errors.

### 2026-08-12 (auth screens)
- **P1-11, P1-12, P1-13 done.** All four auth screens rewired to real Firebase:
  - `login_screen` — real `signIn()`, routes by the Firestore role, errors shown inline
  - `signup_screen` — real `signUp()` creating both the auth user and the
    `users/{uid}` profile (plus a `drivers/{uid}` record for drivers); goes
    straight to the role home since Firebase signs the user in on creation
  - `forgot_password_screen` — really calls `sendPasswordResetEmail`; added an
    inline error row, since the screen previously had nowhere to show a failure
  - `change_password_screen` — real `changePassword()` that re-authenticates
    with the current password first
- **Fixed a regression I introduced earlier the same day.** Rewriting
  `AuthService` changed the Google path from *returns null on failure* to
  *throws `AuthException`*, but neither Google handler had a `try/catch`. A
  first-time Google user would have hit an unhandled exception with the spinner
  stuck on. Both handlers now catch and display the message.
- Google sign-in semantics tightened: the **login** screen passes no
  `signUpRole`, so an unknown Google account is told to sign up instead of
  silently getting a profile with a role it never chose. The **signup** screen
  passes the chosen role, which is correct there.
- `flutter analyze`: 8 info lints, **0 errors**, and zero deprecation warnings —
  no screen calls `saveRole()` any more.

### 2026-08-12 (later)
- Cloudinary configured and **verified working end to end** — cloud `dllh0oom`,
  unsigned preset `TransitPro`. Unsigned upload returned HTTP 200; delivery and
  thumbnail-transform URLs both resolve.
- Committed the cloud name and preset as `AppConfig` defaults. They are public
  values (the cloud name is in every delivery URL), so the app now runs without
  build flags; `--dart-define` still overrides.
- **Bug fixed before it shipped:** the upload wrappers passed fixed public ids
  (`user_<uid>`), which would have collided on a second upload given the
  preset's `Overwrite: false` — and unsigned uploads cannot enable overwrite.
  Wrappers no longer send a public id.

### 2026-08-12
- Created `transit_core` shared package — 17 models, 16 enums, tolerant JSON
  helpers, central config. `flutter analyze`: clean.
- Added `lib/data/` repository layer: typed Firestore refs plus 7 repositories
  covering users, students, drivers, fleet, trips, attendance, payments,
  missed-bus, notifications, chat and live location.
- Rewrote `AuthService` for real Firebase email/password auth. Role now read
  from `users/{uid}` in Firestore instead of being chosen by the client.
  `saveRole()` kept but deprecated so existing screens still compile.
- Added `CloudinaryService` with unsigned uploads (no API secret in the client).
- Wrote `firestore.rules` and `database.rules.json`. **Not deployed.**
- Added `firebase_database` and the `transit_core` path dependency.
- `flutter analyze`: 11 info-level lints, **0 errors**. Three are the deprecation
  warnings marking the remaining fake-login call sites.

### 2026-08-08
- Deleted the duplicate admin section from the mobile app (11 files). The
  standalone `transit_admin` app is now the only admin surface.
- Verified Firebase Storage is **not** provisioned on `transitpro-db` — decided
  on Cloudinary instead.
- Wrote both README files.
