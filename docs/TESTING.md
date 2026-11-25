# Testing

> Source: [PLAN.md §12](PLAN.md#12-testy-akceptacyjne-z-pdf-i-jak-je-zaliczyć) (acceptance tests) and [§17](PLAN.md#17-macierz-urządzeń-testingmd--do-uzupełnienia-realnymi-danymi) (device matrix). SIMULATION ONLY: every patient, account and tag is fictional.

This file is the record of what was tested, on which devices, with what result and proof. Results are filled in during the team run of the 8 acceptance tests (#52). Until then a result is ☐, and a test that cannot run yet says what it is waiting for.

**Legend:** ✅ passed · ❌ failed (link the bug issue) · ☐ not run yet · — not applicable

## Where we are (25 Nov 2026)

| Area | State | Blocks tests |
|---|---|---|
| App data | Runs on the bundled demo hospital (`app/assets/demo/sample-data.json`). The Supabase repository is #16. | 1–4, 7, 8 against the real backend |
| Schema and RPCs | In the cloud project: `0001_schema.sql`, `0003_rpc.sql` (role checks, PT401/403/404/409/422, idempotency). | — |
| RLS | Enabled on all 5 tables with **no policies** (deny by default). Read policies, revoked write grants and append-only triggers are `0002_rls.sql` (#27). | 2–4 (the app can't read), part of 5 |
| Realtime | Publication not set up yet (#42). | 2 |
| Concurrency script | `tools/concurrency_test` is a skeleton. | 8 (script part) |
| iOS NFC | Needs a paid Apple Developer account for the NFC capability ([BACKEND.md](BACKEND.md#ios-nfc-entitlement-issue-11)). | 1, 6 on iPhone |

The app's flows already work end to end on demo data (scan, transfer, status, offline, conflict), so tests 1, 6 and 7 can be rehearsed on phones today.

## Device matrix

Fill in one row per phone used in #52. **Build** = the commit SHA of `main` that was installed.

| Device (model) | OS version | Build | NFC | QR | Realtime | Offline | Conflicts | Notes |
|---|---|---|---|---|---|---|---|---|
| iPhone ______ (XS or newer) | iOS __ | `_______` | ☐ | ☐ | ☐ | ☐ | ☐ | system NFC sheet |
| Android with NFC ______ | Android __ | `_______` | ☐ | ☐ | ☐ | ☐ | ☐ | reader mode |
| Android without NFC / NFC off ______ | Android __ | `_______` | fallback ☐ | ☐ | — | — | — | test 6 |

## Running on a physical device

Android:

```bash
cd app
flutter devices
flutter run -d <phone-id>
```

Phone: Developer options → USB debugging. NFC: Settings → Connected devices → NFC on.

iOS (Mac with Xcode only):

```bash
cd app
flutter run -d <iphone-id>
```

First set up signing in Xcode once, see [BACKEND.md → iOS: NFC entitlement](BACKEND.md#ios-nfc-entitlement-issue-11). On the iPhone: Settings → Privacy → Developer Mode → on. On first launch: Settings → General → VPN & Device Management → trust the certificate.

NFC tags: NTAG213 with one NDEF **Text** record holding only the ID, e.g. `HPT-7K3M9QX2`. Print the cards and the test tags with [`tools/generate_tags`](../tools/generate_tags/README.md); encode with NFC Tools. The same tag must show the same payload on both phones.

## Acceptance tests

Accounts: `nurse1`, `nurse2`, `doctor1`, `doctor2` `@wardline.test` ([BACKEND.md → test accounts](BACKEND.md#konta-testowe-18)). Passwords are in the team password manager, never in the repo. Save every proof (screen recording, screenshot, terminal log) in the team drive and link it in the **Proof** column.

### Results

| # | Test | iOS | Android | Proof | Bugs |
|---|---|---|---|---|---|
| 1 | Sign in + the same patient via NFC and QR | ☐ | ☐ | | |
| 2 | Transfer as Nurse, change visible on the second device | ☐ | ☐ | | |
| 3 | History entry: from, to, server time, actor | ☐ | ☐ | | |
| 4 | Status change as Doctor | ☐ | ☐ | | |
| 5 | Backend refuses unauthorized changes (UI bypass) | — | — | | |
| 6 | Unknown ID, cancelled scan, no NFC, camera denied | ☐ | ☐ | | |
| 7 | Offline: banner, cache, writes blocked | ☐ | ☐ | | |
| 8 | Repeated send and parallel transfers | ☐ | ☐ | | |

### How to run each test

**1. Sign in + the same patient via NFC and QR.** Phone: iPhone and Android.
1. Sign in as `nurse1`.
2. Scan → hold the wristband tag of a printed card → **Patient identified**, quick summary sheet. Note the name and `HPT-…` ID. Close the sheet.
3. Scan → **QR code** → scan the QR on the same card.
4. Expected: the same patient and ID, and **nothing was written** (scanning only opens the record; the patient's history has no new entry).
Proof: screen recording.

**2. Transfer as Nurse, change visible on the second device.** Needs #16, #27, #42.
1. iPhone `nurse1`, Android `doctor1`, both on the dashboard.
2. iPhone: open a patient → **Transfer patient** → choose a department → **Confirm transfer**.
3. Expected on the iPhone: spinner, then the checkmark only after the server answered, then the new location.
4. Expected on the Android within a few seconds, without refreshing: the dashboard KPI "Transfers today" counts up, the patient row is highlighted in Patients with the new department, the dot moves on the map. (A doctor's dashboard feed lists status changes, so the transfer is not in it; a second nurse would see it in "Recent transfers".)
Proof: one recording showing both phones.

**3. History entry: from, to, server time, actor.**
1. After test 2, open the same patient → History.
2. Expected: the newest entry is "Transferred", `From → To`, the time, and the nurse's initials and role. Tap it: details show From, To, Identified by, Server confirmed (hh:mm:ss).
3. SQL in the Supabase SQL editor (proof that time and actor come from the server):
   ```sql
   select from_location, to_location, created_at, updated_by, identified_by
   from location_history order by created_at desc limit 1;
   ```
Proof: screenshot of the timeline + screenshot of the query result.

**4. Status change as Doctor.**
1. Android `doctor1`: open a patient → **Change status** → **Ready for Discharge** → **Save status**.
2. Expected: the status chip changes, the location stays the same, toast "Status updated · Ready for Discharge · location unchanged", a new "Status changed" entry. The iPhone shows the new status.
3. SQL: `select from_status, to_status, changed_by, created_at from status_history order by created_at desc limit 1;`
Proof: recording + query result.

**5. Backend refuses unauthorized changes (UI bypass).** Terminal only, no app.

```bash
URL=https://fqbyyrsmmhyvlakacioj.supabase.co
ANON=<anon key from Project Settings › API>   # publishable, not service_role

# Sign in as the nurse and keep the access token.
NURSE_JWT=$(curl -s "$URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"email":"nurse1@wardline.test","password":"<from the password manager>"}' \
  | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

# a) Nurse calls the status RPC → PT403
curl -s "$URL/rest/v1/rpc/set_patient_status" \
  -H "apikey: $ANON" -H "Authorization: Bearer $NURSE_JWT" -H "Content-Type: application/json" \
  -d '{"p_patient_id":"<patient uuid>","p_status":"discharged","p_expected_version":1,
       "p_request_id":"00000000-0000-4000-8000-000000000001","p_reason":"test"}'

# b) Nurse writes the table directly, skipping the RPC
curl -s -X PATCH "$URL/rest/v1/patients?id=eq.<patient uuid>" \
  -H "apikey: $ANON" -H "Authorization: Bearer $NURSE_JWT" -H "Content-Type: application/json" \
  -H "Prefer: return=representation" -d '{"status":"discharged"}'

# c) No user token at all → the RPC is not executable for anon
curl -s "$URL/rest/v1/rpc/set_patient_status" -H "apikey: $ANON" \
  -H "Content-Type: application/json" -d '{}'
```

Expected:
- a) `"code":"PT403"`, "Only doctors can change a patient's status."
- b) today: `[]`, 0 rows changed (RLS has no write policy). After `0002_rls.sql` (#27) revokes the write grants: `permission denied for table patients` (`42501`).
- c) `permission denied for function set_patient_status` (`42501`, HTTP 401).
- Afterwards the patient's status is unchanged (check in the app or with SQL).

The same rule is covered automatically by `supabase/tests/0003_set_patient_status_roles_test.sql` (#60). Proof: terminal log.

**6. Unknown ID, cancelled scan, no NFC, camera denied.** Use the test tags from `tools/generate_tags` (end of `qr_sheet.pdf`).

| Case | Steps | Expected |
|---|---|---|
| Unknown ID | scan the `HPT-ZZZZZZZZ` tag | "HPT-ZZZZZZZZ isn't registered", no record opened |
| Wrong format | scan the `HELLO` tag / QR | "This tag doesn't contain a Wardline patient ID" |
| Empty tag / URL tag | scan them | the same "doesn't contain a Wardline patient ID" |
| Cancelled (iOS) | Start scanning → Cancel in the system sheet | quiet return, no message |
| No NFC | NFC off on Android (or a phone without NFC) | "NFC isn't available on this device", switches to QR after 2 s; Android offers **Open NFC settings** |
| Camera denied | deny camera access, open QR | "Camera access is off" with **Open Settings** and **Use NFC instead** |

Proof: recording per platform.

**7. Offline: banner, cache, writes blocked.**
1. Open the Patients list and a patient (so they are cached), then turn on airplane mode.
2. Expected: "You're offline" banner with the sync time, cached data still shown with the cache badge, and every write action replaced by "Changes need a connection" (no greyed-out buttons, nothing queued).
3. Open a patient that was never loaded → "Connect to load".
4. Turn airplane mode off → "Back online · synced hh:mm" and fresh data.
Proof: recording.

**8. Repeated send and parallel transfers.** Needs #16 and the concurrency script.
1. Triple-tap **Confirm transfer** quickly → exactly one transfer: `select count(*) from location_history where client_request_id = '<id>';` → 1.
2. iPhone `nurse1` and Android `nurse2` open the same patient, choose different departments and confirm at the same time → one sees the checkmark, the other the conflict screen ("Refresh and choose again"), never an automatic retry.
3. `tools/concurrency_test` with 50 parallel calls → exactly 1 success, 49 × PT409, +1 history row.
Proof: recording of step 2, query result of step 1, script log of step 3.

## Automated tests

| Suite | Command | Where | What it covers |
|---|---|---|---|
| Dart unit + widget | `cd app && flutter test` | local, CI `analyze-test` | patient code parser, KPI and feed logic, every screen's states (loading, empty, error, offline), role-based actions, scan never writes, conflict and timeout flows, text scale 2.0, reduced motion |
| Golden images | part of `flutter test` | **CI only** (`ubuntu-latest`) | pixel snapshots of widgets and screens; they were generated on Linux and fail on Windows and macOS because fonts render differently, so run them in CI or regenerate on Linux |
| pgTAP | `supabase test db` | local with Docker, CI `supabase-db-test` | schema, `patient_code` CHECK, RPC privileges (`0001_schema_test.sql`); only a doctor changes status (`0003_set_patient_status_roles_test.sql`, #60). RLS, idempotency and PT409 tests: #31 |
| Python | `python -m unittest discover tools/generate_tags` | local | tag CSV and QR sheet generator |
| Concurrency | `tools/concurrency_test` | local / demo | skeleton, see test 8 |

## Known limitations

Written to be honest, not to look good. Update it after #52.

- **No automatic positioning.** The system knows only transfers that a nurse confirmed. A patient who walks to another ward without a scan is still shown in the old one.
- **Realtime does not replay missed events.** After a reconnect the app refetches everything; changes made while offline are seen only after that refetch.
- **One version for location and status.** A doctor's status change and a nurse's transfer of the same patient at the same moment conflict even though they touch different fields (PLAN §5.3 decision: simpler and safe, sometimes a false conflict).
- **iOS NFC uses the system sheet.** The app can't show its own UI while the iPhone is reading, and NFC needs a paid Apple Developer account.
- **Offline is read-only.** Nothing is queued; every change needs a connection (by design).
- **The app still runs on demo data** until the Supabase repository (#16), read policies (#27) and realtime (#42) land. Results above are only valid for the build named in the device matrix.
- **Golden tests are Linux-only** (see Automated tests).
- **Timeline entries from earlier days show only the time** (e.g. "15:20" for yesterday). Known, to be fixed together with a golden refresh.
- **Sign-in shows every failure as "You're offline".** Once Supabase Auth is wired (#16), server errors need their own message.
