# Prototype flows = acceptance criteria

Try them on the canvas page *Prototype & handoff* (P1 for flows 1–5, P2 for flow 6). Each step is a check for an integration test.

## 1. Nurse: scan → transfer
1. Dashboard → tap **Scan NFC** (or the raised Scan tab).
2. Scan screen shows rings and "Scanning opens the record — it never moves the patient." iOS: tap **Start scanning** → system sheet. Android: listening already.
3. Read OK → scan area brightens, haptic, quick summary sheet: name, ID, status chip, last location + time. **No write has happened** (assert: zero RPC calls).
4. Tap **Transfer →** → destination sheet. Type "rad" → Radiology is the only match. Current location (Laboratory) is marked and not selectable.
5. Confirm screen: Laboratory → Radiology with moving dot, "Performed by Anna Nowak · Nurse", "Status … unchanged".
6. Tap **Confirm transfer** → spinner, back/cancel hidden; a second tap does nothing (assert: one RPC call, one `client_request_id`).
7. RPC 200 → checkmark draws, "Patient moved to Radiology", then **Back to patient** → profile shows Radiology "since 10:46 · Anna Nowak" and a highlighted new timeline item at the top.

## 2. Conflict
1. Confirm transfer while the server version is newer (Marek Kowal moved Jan to Cardiology at 10:41).
2. RPC returns `PT409` → conflict sheet: Who (Marek Kowal · Nurse), When (10:41), Where (Laboratory → Cardiology), "Your change wasn't saved."
3. **Refresh and choose again** → refetch → summary shows Cardiology with "Updated · moved by Marek Kowal at 10:41". Assert: no automatic retry.

## 3. Doctor: change status
1. Patients → search "Kowalczyk" → only Jan Kowalczyk → open profile.
2. Sticky action is **Change status** (no Transfer button anywhere).
3. Sheet: 4 statuses, In Treatment marked "Current", Ready for Discharge selected, note "Location doesn't change". **Save status** → spinner → profile shows Ready for Discharge (colour cross-fade), location unchanged, toast "Status updated · Ready for Discharge · location unchanged", new timeline item.

## 4. Offline
1. Go offline → offline banner, connection indicator "Offline", list shows "Cached · synced 10:42 · may be outdated" and "as of 10:42" on cards.
2. Open a patient → profile shows the cache badge; the action is replaced by "Changes need a connection." Transfer confirm, if reached, shows the same instead of the button.
3. Back online → "Back online · synced 10:47" for 3s, full refetch (Realtime does not replay missed events), cache badges disappear.

## 5. Map
1. Dashboard → **Hospital map** card → 3D view, three floors, heat colours + % labels, bottleneck markers on ICU and INT.
2. Tap **RAD** → department sheet: occupancy, free beds, patients there.
3. Tap a patient → route view: numbered stops, path drawn, lift marked at each floor change, list of stops with times.

## 6. Two devices
1. Left: Nurse on iPhone confirms Laboratory → Radiology.
2. Within ~1s of the RPC commit, right: Doctor on Android, Patients list: Jan's card flashes and reads "Moved to Radiology · now"; toast "Jan Kowalczyk moved to Radiology · by A. Nowak". No manual refresh. Scroll position unchanged.
