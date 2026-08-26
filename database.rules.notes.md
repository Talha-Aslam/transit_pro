# Realtime Database rules — notes

`database.rules.json` must be strict JSON (no comments, no duplicate keys) —
the Firebase console's rules editor validates it against the RTDB rules
schema, which rejects non-standard keys like `"//"` and does not reliably
support `//`/`/* */` comments either. Rationale lives here instead.

## Scope

Live bus positions only. Everything else lives in Firestore (see
`firestore.rules`). This database exists because Firestore bills per
document write, and a 3-hour route publishing every 5 seconds is ~2,160
writes per bus per day.

Deploy with: `firebase deploy --only database`

## `liveLocations/$busId`

Any signed-in user may watch a bus. The payload is a coordinate and a
speed — it does not identify any child. Restricting reads to just the
assigned families would need a per-bus roster mirrored into RTDB, which
is Phase 4 work if the pilot warrants it.

Writes are restricted to the driver currently assigned to the bus.
`driverId` is pinned to the writer's own uid so one driver cannot spoof
another bus's position.
