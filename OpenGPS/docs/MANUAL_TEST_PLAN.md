# Manual test plan (controlled test app)

Use **three distinct checks**. Never treat OpenGPS map movement alone as proof of system-wide simulation.

## A — In-app preview only

1. Install OpenGPS.
2. Backend: **In-App Preview**.
3. Set coordinates far from your real city; tap **Start**.
4. Confirm OpenGPS status: “In-app preview active…”.
5. Open **Apple Maps** (or any unrelated app): it must still show **real** location (or ask permission normally).
6. **Pass:** OpenGPS moves; other apps do not.

## B — Core Location simulation for an app under test (requires host)

1. Create or open **your** test app that displays `CLLocationManager` coordinates.
2. On a Mac, run that test app from Xcode with Debug → Simulate Location (or scheme GPX from OpenGPS export).
3. Confirm the **test app** shows simulated coordinates.
4. Optionally check whether other apps also change (behavior can depend on host tool / session); record what you observe.
5. Clear simulation (Don’t Simulate Location / host `clear`).
6. **Pass:** Documented host path changes the app under test. OpenGPS preview alone is insufficient for this column.

## C — System-wide claim

1. Only after B, with host still injecting.
2. Check a second app you control.
3. OpenGPS must **not** show “System-wide GPS spoofing active”.
4. If you toggle “Confirm host simulation after external verification”, the banner must still say user confirmation / verify in a test app.
5. Disconnect USB/tunnel; OpenGPS developer backend should report connection lost when the host flag is cleared.
6. **Pass:** No false system-wide claim; restore steps return real GNSS.

## Additional cases

| Case | Steps | Expected |
|---|---|---|
| Permission denial | Deny location; tap Use current real location | Clear denial message; preview still works |
| Malformed GPX | Import broken XML | Error; no crash |
| Route pause/resume | Multi-waypoint GPX backend; pause; resume | Pin freezes then continues |
| Unsupported messaging | Read FEASIBILITY / status on Apple Developer backend without host | “requires development host” |
