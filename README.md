# TransitPro — Student Transport Management (Mobile App)

> **Safe Journeys, Happy Kids, Peace of Mind.**
>
> This is the **mobile app** for parents, students, and drivers.
> The **admin panel is a separate application** — see [`../../transit_admin`](../../transit_admin).
> Both apps share one Firebase backend (`transitpro-db`).

**Status:** UI-complete prototype moving into backend implementation.
**Document purpose:** single source of truth. Any developer or AI session should be able to read this and continue work without re-explaining the project.

**Last updated:** 2026-08-08

---

## 1. The Problem

Parents of school children have no reliable way to know where the school bus is, whether their child boarded it, or whether it is running late. Schools coordinate transport over phone calls and WhatsApp groups. Drivers keep attendance on paper. Fee collection is manual and disputed.

TransitPro replaces that with a single system:

- **Parents** see the bus move on a live map, get alerts when it approaches their stop, and know their child boarded.
- **Students** track their own bus and request an alternate pickup if they miss it.
- **Drivers** run their route, mark attendance, and broadcast location automatically.
- **Admins** (separate app) manage fleet, routes, users, and subscriptions.

---

## 2. Two Apps, One Backend — How This Fits Together

This is the most common point of confusion, so it is stated explicitly.

```
D:\Noorulain FYP\
│
├── transit_Pro\transit_pro\      ← THIS APP (mobile: parent + student + driver)
│      own folder · own git repo · own APK · package com.transitpro.transit_pro
│
├── transit_admin\                ← ADMIN APP (fleet & operations)
│      own folder · own git repo · own APK · package com.transitpro.transit_admin
│
└── transit_core\                 ← PLANNED shared package (not yet created)
       models, theme, widgets — imported by BOTH apps via a path dependency
                    │
                    ▼
        ┌───────────────────────────────────┐
        │  Firebase project: transitpro-db  │
        │  (ONE cloud backend, shared)      │
        │  · Auth (one user pool)           │
        │  · Firestore (business data)      │
        │  · Realtime Database (live GPS)   │
        │  · Storage (docs, slips, photos)  │
        │  · Cloud Messaging (push)         │
        └───────────────────────────────────┘
```

**The folders are separate. They are two distinct programs you install separately.**

- **"They share a backend"** means both apps connect to the **same Firebase project**, `transitpro-db`. One database, one set of user accounts, one storage bucket. When an admin creates a route in the admin app, the parent app reads that same route document. They talk to each other *through the cloud*, never directly.
- **"They share a data model"** means both apps must agree on what a `Student`, `Driver`, or `Route` *is* — the same field names and types. **Today they do not.** Each app has its own duplicate, incompatible model classes. Fixing that is Phase 1 work: extract one `transit_core` package that both apps import, so a model is defined **once** and used **twice**.

Each app is registered as its own **Firebase App** inside the shared project — correct configuration. (Known bug: the *web* `appId` is currently identical in both apps and must be regenerated. Android/iOS are correct.)

---

## 3. Tech Stack

### Current

| Layer | Technology |
|---|---|
| Framework | Flutter 3.38.10 (Dart SDK ^3.10.9) |
| Navigation | `go_router` ^14.0.0 |
| State | Singletons + `ValueNotifier` / `ChangeNotifier` (no external state library) |
| Maps | `google_maps_flutter` ^2.10.0, `flutter_polyline_points` |
| Location | `geolocator` ^13.0.0, `permission_handler` |
| Notifications | `flutter_local_notifications` ^18.0.0 (device-local only) |
| Background | Native Kotlin foreground service + secondary Flutter engine |
| Local storage | `shared_preferences` |
| Auth | `firebase_auth` + `google_sign_in` (Google only; email/password is a stub) |
| i18n | Custom `AppStrings.t()` — English + Urdu, ~590 keys, 699 call sites |

### Planned

| Purpose | Technology | Why |
|---|---|---|
| Business data | **Cloud Firestore** | Queries, offline cache, security rules |
| Live GPS | **Firebase Realtime Database** | Firestore bills per document write; a 3h route at 5s intervals ≈ 2,160 writes/bus/day and would exhaust the 20k/day free quota. RTDB bills bandwidth — effectively free at this volume |
| Push | **Firebase Cloud Messaging** | Cross-device alerts (currently notifications never leave the device) |
| Files | **Firebase Storage** | Driver documents, payment slips, profile photos |
| Shared code | **`transit_core` local package** | Eliminates duplication between the two apps |
| AI — safety | Rules engine → small regression model | Route deviation + ETA prediction |
| AI — assistant | **Gemini API** (free tier) with function calling | Natural-language Q&A over live app data |
| Testing | `flutter_test` | Currently **zero tests** |

---

## 4. Roles & Permissions

| Capability | Parent | Student | Driver | Admin *(separate app)* |
|---|:--:|:--:|:--:|:--:|
| Track assigned bus live | ✅ own children | ✅ own bus | ✅ broadcasts | ✅ all buses |
| Broadcast GPS | ❌ | ❌ | ✅ | ❌ |
| View schedule | ✅ | ✅ | ✅ | ✅ |
| Mark attendance | ❌ | ❌ | ✅ | ✅ override |
| Raise missed-bus request | ✅ | ✅ | ❌ | ❌ |
| Accept/decline missed-bus | ❌ | ❌ | ✅ | ✅ |
| Pay fees | ✅ | view only | ❌ | ✅ manage |
| Receive fee payments | ❌ | ❌ | ✅ view | ✅ manage |
| Chat | ✅ ↔ driver, support | ✅ ↔ driver | ✅ ↔ parents | ✅ broadcast |
| Rate driver | ✅ weekly | ✅ weekly | ❌ | ✅ view |
| Manage children | ✅ own | ❌ | ❌ | ✅ all |
| Upload documents | ❌ | ❌ | ✅ | ✅ verify |
| CRUD routes / buses / drivers | ❌ | ❌ | ❌ | ✅ |
| Emergency SOS | receive | receive | trigger | receive + manage |

> ⚠️ **Security note:** role is currently chosen by the client (`AuthService.saveRole()` from the login URL) and stored in `SharedPreferences`. Any user can select any role. **Before the pilot, role must live in Firestore and be enforced by security rules.** See §9.

---

## 5. Architecture

### Current pattern

Screens read from **singleton services** exposing `ValueNotifier`s, consumed via `ValueListenableBuilder` / `ListenableBuilder`. There is no DI container and no external state library. The pattern is consistent and readable — the problem is only that the services hold data **in RAM**, so nothing crosses devices or survives restart.

```
Screen  ──watch──▶  Service singleton (ValueNotifier)  ──▶  [ in-memory mock data ]
                                                             ▲
                                            TARGET: replace with Firestore / RTDB streams
```

The migration is deliberately shallow: keep the `ValueNotifier` API, swap the internals for Firestore `snapshots()`. Most screens will not change. `MissedBusService` even documents this intent in its own header comment.

### Folder structure

```
lib/
├── main.dart                  App entry + `busTrackingBackground` isolate entry point
├── firebase_options.dart      FlutterFire generated (project: transitpro-db)
│
├── app/                       Services & routing (the "logic layer")
│   ├── router.dart              go_router config — all routes
│   ├── auth_service.dart        Firebase Auth + Google + role persistence
│   ├── tracking_service.dart    Bus position: simulated OR live GPS
│   ├── geofence_service.dart    500m approaching / 100m arrived / 200m departed
│   ├── notification_service.dart Local notifications + in-app history
│   ├── missed_bus_service.dart  Cross-role missed-bus request lifecycle
│   ├── route_service.dart       Google Directions API (needs key)
│   ├── parent_data_service.dart Parent profile, children, fees, ratings
│   ├── student_data_service.dart Student profile, guardian, ride stats
│   ├── driver_data_service.dart Driver profile, timing slots, location toggle
│   ├── driver_alerts_service.dart  Unread alert counter
│   ├── profile_service.dart     Profile image files
│   ├── subscription_provider.dart  Active plan
│   └── language_provider.dart   i18n — EN/UR string tables (1,435 lines)
│
├── models/
│   ├── route_data.dart          RouteData, StopData, MockRouteBuilder (6 stops, 82 waypoints)
│   ├── missed_bus_request.dart
│   └── parent_trip_history_data.dart
│
├── screens/
│   ├── welcome_screen.dart · role_selection_screen.dart
│   ├── login_screen.dart · signup_screen.dart · forgot_password_screen.dart
│   ├── map_picker_screen.dart
│   ├── parent/    (23 files — largest role)
│   ├── student/   (13 files)
│   └── driver/    (13 files)
│
├── theme/    app_theme.dart (glassmorphic design system), theme_provider.dart
└── widgets/  glass_card.dart (GlassCard, GradientButton, AppSwitch, StatusBadge)

android/app/src/main/kotlin/com/example/transit_pro/
├── BusTrackingService.kt   Foreground service hosting a 2nd Flutter engine
├── BootReceiver.kt         Restarts tracking after device reboot
└── MainActivity.kt · MainApplication.kt
```

### Role accent colors

`parentPurple #7C3AED` · `driverCyan #0EA5E9` · `studentAmber #F59E0B` · `adminEmerald #059669`

---

## 6. Features — Implemented vs. Planned

### ✅ Genuinely working

- Glassmorphic design system, dark/light theme, persisted
- English/Urdu localization across the whole app
- Google Sign-In (real Firebase Auth)
- Google Maps rendering with custom style, markers, polylines, camera bearing/tilt
- Bus movement simulation — real spherical bearing math over 82 waypoints
- Live GPS mode (`TrackingService.toggleLive()`) using `Geolocator`
- Geofence detection with real distance thresholds → real OS notifications
- **Native Android background tracking** — foreground service + boot receiver + second Flutter engine
- Missed-bus request lifecycle (student raises → driver accepts/declines), 4-state machine
- Weekly driver rating with week-gating, persisted to `SharedPreferences`
- Trip-history filtering (day/week/month/year) with correct date predicates
- JazzCash / EasyPaisa deep links; payment-slip image picking

### 🔶 Half-real — mutates a singleton, lost on restart

Profile edits · children CRUD · attendance toggles · notification read state · document upload (path only, never uploaded) · subscription plan switching · schedule timing edits

### ❌ Stubs that *look* like they work

| Feature | Reality |
|---|---|
| **Email/password login** | `Future.delayed(1500ms)` → navigate. **Any email + any password works, as any role** |
| **Signup** | Never calls `createUserWithEmailAndPassword`; just routes to login |
| **Change password** | Validates, waits 1s, says "changed". Never calls Firebase; never checks the old password |
| Cash / Card payment | `Future.delayed` → "approved" |
| All 3 chat screens | Canned 2-second echo bot, ephemeral |
| Rate app | Rating and comment discarded |
| Complaint submission | Nothing stored or sent |
| Help & Support send | Text discarded |
| Driver notification reply | Reply button just closes the view |
| Student QR boarding pass | Drawn with `math.Random(42)` — encodes nothing |
| "Contact School" (both missed-bus screens) | `Container` with **no `onTap` at all** |
| "Request sent to driver" dialog | Sends nothing |

### 📋 Planned

Firestore persistence · FCM push · cross-device tracking · real auth + role enforcement · real chat · attendance persistence · document upload to Storage · AI safety intelligence · AI assistant · automated tests

### 🗑️ Dead code — decide: route or delete

`driver_search_screen.dart` (807 LOC, has a latent `int.parse('2.3')` crash) · `emergency_alerts_screen.dart` · `complaint_submission_screen.dart` · `pickup_dropoff_confirmation_screen.dart` · `student_attendance.dart` (534 LOC) · `_NotifSheet` in student profile · `/driver/subscription` (routed, unlinked)

---

## 7. Screen Documentation

### Shared entry flow

| Screen | Route | Notes |
|---|---|---|
| `WelcomeScreen` | `/splash`, `/` | Animated splash; auto-routes by saved role |
| `RoleSelectionScreen` | `/role-select` | 3 cards: parent, driver, student |
| `LoginScreen` | `/login/:role` | ⚠️ Fake auth. Unknown role silently falls back to Parent |
| `SignupScreen` | `/signup` | Role-specific fields; ⚠️ creates no account |
| `ForgotPasswordScreen` | `/forgot-password` | ⚠️ Sends no email |

### Parent (23 files) — most complete role

**Tabs (`ParentLayout`, `/parent`):** Dashboard · Tracking · Schedule · Notifications · Fees · Profile

| Screen | Route | Purpose | Data |
|---|---|---|---|
| `ParentDashboard` | tab 0 | Child selector, live ETA, missed-bus CTA, stats | Mixed — children real, ETA/schedule/alerts hardcoded |
| `ParentTracking` | tab 1 | Live map + stop timeline | `TrackingService` (simulated; GPS toggle available) |
| `ParentSchedule` | tab 2 | Weekly timetable, holidays | **100% static literals** — doesn't even read the child |
| `ParentNotifications` | tab 3 | Inbox with filters | `NotificationService` (7 seeded mocks) |
| `StudentFees` *(in `parent_fees.dart`)* | tab 4 | Balance, history, Pay Now | Hardcoded except `isMonthPaid()` |
| `ParentProfile` | tab 5 | 2,327 LOC hub — children CRUD, prefs, menu | `ParentDataService` |
| `DriverDetailsScreen` | `/parent/driver-details` | Driver info + weekly rating | ✅ **Persists rating to disk** |
| `DriverChatScreen` | `/parent/driver-chat` | Chat with driver | ⚠️ Echo bot |
| `TripHistoryScreen` | `/parent/trips` | Present/absent trips | Real filtering, fake data |
| `PaymentMethodScreen` + Cash/Online/Card | `/parent/payment/*` | 2,174 LOC payment flow | Only Online path persists |
| `ParentMissedBusScreen` | `/parent/missed-bus` | Alternate pickup request | ✅ Real cross-role flow |
| `SubscriptionScreen` | `/parent/subscription` | 3 plans | Not persisted |
| `EmergencyContactsScreen` | `/parent/emergency-contacts` | ICE contacts | ⚠️ Lost on pop |
| `HelpSupportScreen` · `LiveChatScreen` · `LanguageScreen` · `ChangePasswordScreen` · `RateAppScreen` | `/parent/*` | Support & settings | Language real; rest stubs |

> Six of these (`LanguageScreen`, `ChangePasswordScreen`, `EmergencyContactsScreen`, `HelpSupportScreen`, `RateAppScreen`, `SubscriptionScreen`) live in `screens/parent/` but are **reused by driver and student routes** with only an `accentColor` swap.

### Student (13 files)

**Tabs (`StudentLayout`, `/student`):** Dashboard · Tracking · Schedule · Notifications · Fees · Profile

| Screen | Route | Purpose | Data |
|---|---|---|---|
| `StudentDashboard` | tab 0 | Bus status, ETA, quick actions | Name + stats real; ETA/schedule hardcoded |
| `StudentTracking` | tab 1 | **Most real student screen** — live map | `TrackingService`; distance "2.4 km" faked |
| `StudentSchedule` | tab 2 | Timings, editable via `showTimePicker` | University branch writes to shared service; school branch is local-only |
| `StudentNotifications` | tab 3 + `/student/notifications` | Inbox | `NotificationService` |
| `StudentFees` | tab 4 | Fees | Hardcoded; Pay Now enters the **parent** payment flow |
| `StudentProfile` | tab 5 | 1,380 LOC hub | `StudentDataService` |
| `MissedBusScreen` | `/student/missed-bus` | **Best-built student feature** — 4-state machine | `MissedBusService` |
| `StudentTripHistoryScreen` | `/student/trips` | Trip log | Real filtering |
| `StudentDriverDetailsScreen` | *pushed* | Driver info + rating | ✅ Persists; ⚠️ "Last rating" hardcoded to 1.0 |
| `StudentDriverChat` | *pushed* | Chat | ⚠️ Echo bot; wrong accent (purple) |
| `TermsScreen` | `/student/terms` | T&Cs | Static (appropriate) |
| `StudentAttendance` | **none** | QR pass | 🗑️ Dead code |

### Driver (13 files)

**Tabs (`DriverLayout`, `/driver`):** Dashboard · Booked Students · Attendance · Route · Notifications · Profile

| Screen | Route | Purpose | Data |
|---|---|---|---|
| `DriverDashboard` | tab 0 | Route progress, SOS sheets, stats | **Every number hardcoded**; `_routeStarted` is a `final true` — there is no Start Route button |
| `DriverBookedStudentsScreen` | tab 1 | Passenger roster + chat sheet | 14 hardcoded passengers |
| `DriverAttendance` | tab 2 | Mark boarded/absent, bulk alert | 14 hardcoded students; toggles not persisted |
| `DriverRoute` | tab 3 | **Live map + stop timeline** | `TrackingService` — simulation starts on tab open, resets on leave |
| `DriverNotifications` | tab 4 | Message inbox | Read state real; ⚠️ reply is a stub |
| `DriverProfile` | tab 5 | Profile hub | `DriverDataService` |
| `DriverPickupRequestsScreen` | `/driver/pickup-requests` | Accept/decline missed-bus | ✅ Genuinely dynamic |
| `DriverDocumentsScreen` | `/driver/documents` | 6 compliance docs | ⚠️ File never uploaded |
| `DriverTripHistoryScreen` | `/driver/trips` | Trip log | ⚠️ Filters fake (`take(2)`/`take(6)`); ÷0 → `NaN%` |
| `DriverPerformanceScreen` | `/driver/performance` | Scorecard | 100% static, zero interactivity |
| `DriverPaymentHistoryScreen` | `/driver/payment-history` | Payments received | Static |
| `DriverSubscriptionScreen` | `/driver/subscription` | Plans | 🗑️ Unreachable; Upgrade is `() {}` |

---

## 8. Data Model / Schema (Draft)

### Firestore

```
users/{uid}
  role: 'parent'|'student'|'driver'|'admin'      ← source of truth, rule-enforced
  name, email, phone, photoUrl, lang, status
  fcmTokens: string[], createdAt, updatedAt

students/{studentId}
  name, grade, school, instituteType
  parentId → users/{uid}          routeId → routes/{id}
  stopId   → stops/{id}           busId   → buses/{id}
  studentIdNumber, subscriptionStatus, isTransportSuspended
  consecutiveAbsences: int

drivers/{uid}
  name, phone, licenseNumber, licenseExpiry, experienceYears
  busId → buses/{id}
  rating: double, ratingCount: int, reliabilityScore: double
  status, locationSharing: bool

buses/{busId}
  plateNumber, busNumber, capacity
  driverId → drivers/{uid}        routeId → routes/{id}
  status, insuranceExpiry, nextMaintenanceDate

routes/{routeId}
  name, busId, driverId, isActive
  polyline: string (encoded)
  stops: [{ stopId, name, lat, lng, scheduledTime, order, studentCount }]

trips/{tripId}
  routeId, busId, driverId
  date, type: 'morning'|'afternoon'
  startedAt, endedAt, status, onTime: bool

trips/{tripId}/attendance/{studentId}
  status: 'boarded'|'absent'|'pending'
  boardedAt, stopId, markedBy

payments/{paymentId}
  studentId, parentId, driverId
  month: 'YYYY-MM'
  amountPaisa: int                ← integer minor units, never strings
  status: 'paid'|'pending'|'overdue'
  method: 'cash'|'jazzcash'|'easypaisa'|'card'
  slipUrl, confirmedBy, confirmedAt, dueDate

missedBusRequests/{requestId}
  studentId, studentName, missedBusId, routeId
  currentStopId, destinationStopId
  status: 'searching'|'accepted'|'declined'|'noDrivers'|'cancelled'
  assignedDriverId, assignedBusId, etaMinutes, createdAt

chats/{chatId}                  participants: [uid, uid], lastMessage, updatedAt
chats/{chatId}/messages/{msgId} senderId, text, sentAt, readBy[]

notifications/{uid}/items/{id}  type, title, body, data, read, createdAt
ratings/{ratingId}              driverId, raterId, studentId, rating, weekKey, createdAt
documents/{docId}               driverId, type, fileUrl, status, expiryDate, verifiedBy
incidents/{incidentId}          severity, title, description, driverId, routeId, resolved
auditLogs/{logId}               adminId, actionType, targetId, description, timestamp
```

### Realtime Database — live GPS only

```json
{
  "liveLocations": {
    "<busId>": {
      "lat": 31.5204, "lng": 74.3587,
      "heading": 87.4, "speed": 34,
      "tripId": "<tripId>", "ts": 1754640000000
    }
  }
}
```

### Modelling rules for the migration

1. **Money is `int` paisa.** Never `'Rs.2,500'` strings parsed by regex (the current approach).
2. **Dates are `Timestamp`/`DateTime`.** Never `'Jun 15'` or `'2m ago'`.
3. **No `Color`/`IconData` in domain models** — keep presentation mapping in a separate UI layer.
4. **IDs are references,** not display names. Today `driver` is stored as `'Ahmed Raza'`.
5. **One enum definition per concept** in `transit_core`.

### Mock-data inconsistencies to resolve while seeding

| Problem | Detail |
|---|---|
| 3 driver names, same bus | `Ahmed Raza` / `Mike Johnson` / `Mike Thompson` |
| 3 stop vocabularies | `Oak Street` vs `Defence Pickup Point, Lahore` vs `Bus Stop, Gulberg` |
| Geography mismatch | Route waypoints in Lahore; driver "share location" mock in Islamabad |
| Locale mismatch | `Rs.` amounts with `+1 555-0101` US phone numbers |
| ID mismatch | `STU-2042` vs `STU-2024-042` |
| App name | "Transit Pro" vs "TransportKid v2.4.1" |
| Trip counts | `136` total vs 9 listed trips |

---

## 9. Setup & Run

### Prerequisites

- Flutter 3.38.10+ (Dart ^3.10.9) · Android Studio / Xcode · a Firebase account

### Steps

```bash
git clone <repo-url>
cd transit_pro
flutter pub get
flutter run
```

### ⚠️ Required configuration before maps work

The Google Maps key is still a placeholder — **maps render grey until this is fixed**:

- `android/app/src/main/AndroidManifest.xml:40` → `android:value="YOUR_API_KEY"`
- `ios/Runner/AppDelegate.swift:11` → `GMSServices.provideAPIKey("YOUR_API_KEY")`

Optionally set `RouteService.instance.apiKey` for real Directions routing. Without it, `RouteService` falls back to straight-line interpolation — a working safety net.

### Known configuration debt

| Item | Current | Should be |
|---|---|---|
| Android `applicationId` | `com.example.transit_pro` | `com.transitpro.transit_pro` |
| iOS bundle | `com.example.transitPro` | `com.transitpro.transitPro` |
| Web `appId` | Identical to admin app | Regenerate via FlutterFire |
| `test/` directory | Does not exist | Add |

### Firebase

Project **`transitpro-db`** (sender `231263449779`) is already configured for all platforms in `lib/firebase_options.dart`. Use the **Firebase Emulator Suite** during development to avoid consuming free-tier quota.

**Free (Spark) plan covers this project:** Auth (email/password + Google, unlimited) · Firestore 50k reads / 20k writes per day · Realtime Database 10 GB/month, 100 concurrent connections. Estimated pilot usage (~65 users, 2 buses) is roughly 8k reads and 500 writes per day — comfortably inside the free tier.

> ⚠️ **Cloud Storage is NOT provisioned.** Verified 2026-08-12: both `transitpro-db.firebasestorage.app` and `transitpro-db.appspot.com` return `404 — "The specified bucket does not exist."` The `storageBucket` value in `firebase_options.dart` is FlutterFire's *predicted default name*, **not** evidence the bucket exists.
>
> This project appears recent enough to fall under Google's post-2024 policy requiring the **Blaze plan** to provision a Storage bucket. Storage is needed for driver documents, payment slips, and profile photos (Phase 1).
>
> **This is the same blocker as Open Decision #1** — both Maps and Storage require a card on file. Enabling Blaze once solves both and still costs ~$0 under the free limits. Fallback without a card: OpenStreetMap for maps + Cloudinary (25 GB free) for files.
>
> Do **not** work around this by storing base64 images in Firestore — the 1 MB document cap and read costs make it a dead end.

---

## 10. Roadmap

12 weeks, solo. Sequenced so a **single vertical slice works end-to-end before widening**: one flow that genuinely works across two phones beats four roles that half-work.

### Phase 0 — Unblock (Week 1)
- [ ] Working Google Maps key in both apps *(or migrate to `flutter_map` + OpenStreetMap — see §11)*
- [ ] Fix `applicationId` / bundle id; regenerate the colliding web `appId`
- [ ] Create **`transit_core`** package: models, enums, theme, `glass_card`, `mini_chart` (from admin app), auth. Wire both apps via path dependency
- [x] ~~Delete `lib/screens/admin/` from this app~~ — **done 2026-08-08**; admin is now solely `transit_admin`
- [ ] Decide fate of the 6 dead screens
- [ ] Set up Firebase Emulator Suite

### Phase 1 — Real identity & real data (Weeks 2–5)
- [ ] Real email/password auth in both apps; real password reset
- [ ] **Role in Firestore + security rules** (replaces client-chosen role)
- [ ] Router auth guards
- [ ] Unify the two model systems into `transit_core`; add `toJson`/`fromJson`; split presentation from domain *(~2 weeks — the models embed `Color`/`IconData` and use string dates)*
- [ ] Firestore schema + `firestore.rules` + seed script
- [ ] Migrate parent + driver data paths; then student

### Phase 2 — Cross-device live tracking (Weeks 6–8) — **the centerpiece, protect this time**
- [ ] Driver publishes GPS → RTDB; point `BusTrackingService` at it
- [ ] Parent/student subscribe to live position
- [ ] Geofence events → **FCM** so alerts cross devices
- [ ] Add a real **Start / End Route** control (none exists today)
- [ ] Persist attendance to `trips/{id}/attendance`
- [ ] Real chat via Firestore `snapshots()` (~1 day; kills 3 fake echo bots)

### Phase 3 — AI (Weeks 9–10)
- [ ] **Safety & Delay Intelligence** — extend `SmartAlertService` (in `transit_admin`): route-deviation detection, unscheduled stops, harsh speed change, predicted late arrival. Ship as a scored rules engine, then train a small regression on pilot trip data for ETA. Visualize with `mini_chart.dart`
- [ ] **Gemini parent assistant** — function calling over Firestore: *"Where is Noorulain?"*, *"Was she late this week?"*, *"How much do I owe?"*

### Phase 4 — Pilot hardening (Weeks 11–12)
- [ ] Security-rules audit; parent/school consent flow; data-retention & deletion policy
- [ ] Crashlytics; multi-device real-world testing; seed real school data
- [ ] Widget tests for critical flows

### Explicitly out of scope — disclose as future work
Payment gateway (keep deep-link + manual slip confirmation — realistic without a merchant account) · automated document verification · CSV report generation · iOS background service parity

---

## 11. Open Decisions

| # | Decision | Options | Status |
|---|---|---|---|
| 1 | **Maps provider** | (a) Google Maps + billing enabled — 30 min, ~$0, card required. (b) `flutter_map` + OpenStreetMap — no key, no card, permanently free, ~3–5 days to migrate 4 map screens; loses `map_style.json` and camera tilt | ⏳ **Open — blocks Phase 0.** There is no keyless "demo" Google Maps path for a Flutter *mobile* app; the watermarked demo mode is a Maps **JavaScript** API behaviour and does not apply to the native Android/iOS SDK |
| 2 | **Azure $100 credit — best use** | (a) Azure OpenAI for the assistant (better rate limits than Gemini free). (b) Host the ETA model as a small FastAPI service on Container Apps — gives a real "backend service" to write about. (c) Hold as reserve if Firebase quota is exceeded during the pilot | ⏳ Open. Recommend **not** rebuilding the backend on Azure — Firebase's realtime + FCM story is worth more here. Note the credit expires (12 months on Azure for Students) |
| 1b | **File storage** | Verified 2026-08-12: **no Storage bucket exists** on `transitpro-db`. Needed for driver documents, payment slips, profile photos. (a) Enable Blaze — also solves #1, ~$0, card required. (b) Cloudinary 25 GB free, no card. (c) Supabase Storage 1 GB free | ⏳ **Open — same card blocker as #1.** Resolve both together |
| 3 | Dead screens | Route them, or delete | ⏳ Open |
| 4 | Student vs parent overlap | Student fees route into the parent payment flow; several student screens use parent widgets and purple accents | ⏳ Open |
| 5 | Per-day schedules | `DriverTimingSlots` has one global slot set; the UI implies per-day | ⏳ Open |
| 6 | Notification date grouping | Hardcoded to `['Today','Yesterday','Mon, Feb 23']` — other dates render invisibly | ⏳ Open |
| 7 | Admin panel | Standalone app only | ✅ **Decided 2026-08-08** |
| 8 | Database split | Firestore + RTDB for live GPS | ✅ Decided |
| 9 | AI scope | Both safety intelligence and assistant | ✅ Decided |
| 10 | Pilot | Confirmed school; real students and drivers | ✅ Confirmed |

---

## 12. Pilot Obligations (non-negotiable)

The pilot tracks **real children's live locations**. Before it starts:

1. **Written consent** from the school and from each participating parent.
2. **Role enforcement in security rules** — the current client-chosen role is unacceptable for live child location data.
3. **Data minimization** — retain raw GPS only as long as needed (suggest ≤30 days), keep aggregates.
4. **Documented deletion path** — a parent must be able to request removal of their child's data.
5. **Incident plan** — what happens if the app fails mid-route.

Budget ~1 week. Write this up as the **Ethics & Privacy** chapter — evaluators reward it, and it is genuinely required here.

---

## 13. Project Facts

| Metric | Value |
|---|---|
| Dart files (this app) | 79 (was 90 before admin removal) |
| Lines of Dart | ~40,000 |
| Screens | ~55 across 3 roles |
| Services | 14 singletons |
| i18n keys | ~590 × 2 languages, 699 call sites |
| Tests | **0** |
| Largest files | `parent_profile.dart` (2,327) · `payment_screens.dart` (2,174) · `language_provider.dart` (1,435) |
| Firebase project | `transitpro-db` (shared with `transit_admin`) |

---

## 14. For a Fresh AI Session — Start Here

1. This is a **Flutter mobile app**, one of **two** apps. The admin panel is a **separate project** at `../../transit_admin` sharing the Firebase project `transitpro-db`. Separate folders, separate repos, one cloud backend.
2. The UI is essentially complete and good. **The work is backend integration, not UI.**
3. **Everything is in-memory singletons.** Nothing crosses devices. That is the whole implementation phase.
4. **Do not trust screens that look functional** — see §6 for the stub list. Email/password login accepts anything.
5. Migration strategy: **keep the `ValueNotifier` service API, swap the internals for Firestore streams.** Most screens will not change.
6. Constraints: **solo developer, ~12 weeks, no budget beyond essentials, real pilot at a confirmed school.**
7. Before recommending anything, check §11 Open Decisions — several are unresolved and some may have moved on.
