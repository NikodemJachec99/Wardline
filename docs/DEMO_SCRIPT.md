# Demo script (~12 min)

> Source: [PLAN.md §13](PLAN.md#13-scenariusz-demonstracji-końcowej-demo_scriptmd--12-minut). Test steps and expected results: [TESTING.md](TESTING.md#how-to-run-each-test). SIMULATION ONLY: every patient, account and tag is fictional; say so in the first minute.

**Order is deliberate:** architecture → acceptance tests 1–8 → bonus. Everything that is graded comes first. If time runs out, cut the bonus, never a test.

## Who does what

Proposal by area of the code; confirm it at the first rehearsal.

| Role | Person | Device |
|---|---|---|
| Architecture, backend, terminal (tests 5, 8) | @NikodemJachec99 | laptop + projector |
| Phone A: iPhone, signed in as `nurse1` (tests 1, 2, 6) | @Foreist13 | iPhone, mirrored |
| Phone B: Android, signed in as `doctor1` (tests 2–4, 7, bonus) | @szymonkunysz11 | Android, mirrored |

Whoever's area it is speaks; the others operate. Every member must be able to explain any part of the system if asked (#57).

## Timeline

| Time | Section | Speaks | Taps / types |
|---|---|---|---|
| 0:00–1:00 | Architecture | Nikodem | — |
| 1:00–3:00 | Test 1: same patient via NFC and QR | Foreist13 | Phone A |
| 3:00–5:00 | Tests 2 + 3: transfer, live on the second phone, history | Nikodem | Phone A, Phone B |
| 5:00–6:00 | Test 4: status change as Doctor | Szymon | Phone B |
| 6:00–7:30 | Test 5: backend refuses a UI bypass | Nikodem | terminal |
| 7:30–9:00 | Test 6: unknown ID, cancel, no NFC, camera denied | Foreist13 | Phone A, Phone B |
| 9:00–10:00 | Test 7: offline | Szymon | Phone B |
| 10:00–11:00 | Test 8: double tap and parallel transfers | Nikodem | Phone A, second nurse phone, terminal |
| 11:00–12:00 | Bonus: map, day timeline, demo mode | Szymon | Phone B |

## Script

### 0:00 Architecture (Nikodem)
- One slide: Flutter app (iOS + Android) → Supabase (Postgres, Auth, Realtime). Writes go only through two RPCs, `transfer_patient` (nurse) and `set_patient_status` (doctor); RLS blocks everything else.
- Say: "All patients, IDs and accounts are fictional. This is a simulation."
- Say: "A scan only opens a record; it never moves anyone."

### 1:00 Test 1: same patient via NFC and QR (Foreist13, Phone A)
1. Sign in as `nurse1` (show the email; type the password off-screen or use autofill).
2. Scan → hold the card's wristband tag → "Patient identified", quick summary sheet. Read out the name and `HPT-…` ID.
3. Close, Scan → QR code → the QR on the same card → the same name and ID.
- Say: "Both carriers hold only the ID. The lookup is read-only: nothing was written."

### 3:00 Tests 2 + 3: transfer, live update, history (Nikodem speaks)
1. Phone B (`doctor1`) stays on the dashboard, visible next to Phone A.
2. Phone A: the same patient → Transfer patient → Radiology → Confirm transfer.
3. Point at Phone A: spinner, then the checkmark **only after the server answered**.
4. Point at Phone B, no refresh: KPI "Transfers today" counts up; on Patients the row is highlighted with the new department; on the map the patient's dot moves. (A doctor's feed lists status changes, so the transfer is not in it.)
5. Phone A: Back to patient → History: "Transferred", From → To, time, nurse's initials. Tap it: Server confirmed hh:mm:ss.
- Say: "Time and author come from the server (`now()`, `auth.uid()`), not from the phone."

### 5:00 Test 4: status change as Doctor (Szymon, Phone B)
1. Open the same patient → Change status → Ready for Discharge → Save status.
2. Toast "Status updated · Ready for Discharge · location unchanged"; Phone A shows the new status.
- Say: "Location and status are separate fields; a doctor can't move patients, a nurse can't change status."

### 6:00 Test 5: backend refuses a UI bypass (Nikodem, terminal)
Prepare the terminal before the demo (see Preparation) so no key or password is typed on the projector.
1. `curl` as the nurse to `rpc/set_patient_status` → `PT403`, "Only doctors can change a patient's status."
2. `curl -X PATCH /rest/v1/patients` as the nurse → nothing changed (0 rows today; `permission denied` after #27).
3. `curl` without a user token → `permission denied for function set_patient_status`.
- Say: "The app hides the button, but the database is what refuses. The same rule is a pgTAP test in CI."
- Commands: [TESTING.md › test 5](TESTING.md#how-to-run-each-test).

### 7:30 Test 6: edge cases (Foreist13)
1. Phone A: scan the `HPT-ZZZZZZZZ` test tag → "HPT-ZZZZZZZZ isn't registered".
2. Phone A: scan the `HELLO` tag → "This tag doesn't contain a Wardline patient ID".
3. iPhone: Start scanning → Cancel → quiet return, no error.
4. Phone B with NFC off → "NFC isn't available on this device", switches to QR.
5. Phone B with camera denied → "Camera access is off", Open Settings / Use NFC instead.

### 9:00 Test 7: offline (Szymon, Phone B)
1. Airplane mode on → "You're offline" banner with the sync time, cached list still there.
2. Open a patient → Change status is replaced by "Changes need a connection" (not greyed out, nothing queued).
3. Airplane mode off → "Back online · synced hh:mm".

### 10:00 Test 8: double tap and parallel transfers (Nikodem)
1. Phone A: open a patient → choose a department → triple-tap Confirm transfer → one checkmark, one history entry.
2. Phone A (`nurse1`) and a second phone (`nurse2`) open the same patient, pick different departments, confirm on "3, 2, 1" → one checkmark, one conflict screen "Refresh and choose again", no automatic retry.
3. Terminal: result of `tools/concurrency_test` (50 parallel calls → 1 success, 49 × PT409).

### 11:00 Bonus (Szymon, Phone B)
1. Dashboard → Hospital map: 3D floors, occupancy colours with %, Full / Bottleneck in words.
2. History → day timeline of today's transfers.
3. Sign in as `admin@wardline.test` (the admin area is admin-only) → Profile → Admin → Demo mode → Live transfers: transfers play on both phones.

The Analytics screen exists as a tablet route but has no entry point in the phone UI, so it is not part of the demo.

## Preparation

**The day before**
- [ ] Both phones on the same `main` build (note the SHA in [TESTING.md](TESTING.md#device-matrix)).
- [ ] Cards and test tags printed with `tools/generate_tags`, tags encoded and checked on both phones.
- [ ] Test accounts work (`nurse1`, `nurse2`, `doctor1`); passwords in the team password manager.
- [ ] Backup recordings of every test ready on the laptop (see Recordings).

**30 minutes before**
- [ ] Phones charged, brightness up, Do Not Disturb on, auto-lock off.
- [ ] Mirroring works: iPhone (QuickTime over cable on a Mac, or AirPlay), Android (`scrcpy`).
- [ ] Starting state: the demo patient is back in the starting department and status (reset with SQL or demo mode).
- [ ] Terminal: `URL`, `ANON` and the nurse's token already set in the shell; nothing secret will be typed or echoed on the projector. `service_role` is never used in the demo.
- [ ] Airplane mode off, NFC on, camera allowed (except for the deliberate test 6 cases).

**If something fails live:** say what should have happened, play the backup recording of that test, move on. Never debug on stage.

## Dependencies

Tests 2–4 and 8 need the app on the real backend: Supabase repository (#16), read policies (#27) and realtime (#42), plus the concurrency script. Test 5 works against the cloud project today. Tests 1, 6 and 7 can be rehearsed on demo data now. If a dependency is not ready on demo day, show that test from the backup recording and say so.

## Recordings

- iPhone: Control Center → Screen Recording. Android: Quick Settings → Screen record, or `scrcpy --record test-02.mp4`.
- One file per test and platform: `test-01-nfc-qr-ios.mp4`, `test-02-transfer-both.mp4`, …
- Upload to the team drive and link them in the Proof column of [TESTING.md](TESTING.md#results).
- Full demo run: record the projector output of a rehearsal as the final demo video.

## Rehearsals

Two full runs with a timer before the real demo (#63).

| # | Date | Duration | What went wrong | Fix |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
