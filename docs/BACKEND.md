# Backend (Supabase)

> Źródło: [PLAN.md](PLAN.md#5-model-danych-i-backend-sql-gotowy-do-migracji).

## Od zera do działającego projektu

1. Zainstaluj Supabase CLI 3.0.0 i Docker.
2. `supabase start` w katalogu głównym repo.
3. `supabase db reset` (migracje + `seed.sql`, jeśli jest).
4. Konta testowe (#18): `bash tools/seed_accounts/seed_accounts.sh` (niżej).
5. Skopiuj URL i **anon key** do `app/.env.json`. `service_role` nigdy nie trafia do aplikacji.
6. `supabase test db` (pgTAP z `supabase/tests/`).

## Migracje

| Plik | Co | Issue |
|---|---|---|
| `0001_schema.sql` | enumy, `locations`, `profiles`, `patients`, `location_history`, `status_history`, indeksy, `current_user_role()`, **RLS włączony bez polityk** (domyślnie wszystko zablokowane) | #14, #17 |
| `0002_rls.sql` | read policies for `authenticated` on all 5 tables, all grants revoked from `anon`, write grants revoked from `authenticated` (PLAN §5.2). Append-only history: UPDATE/DELETE/TRUNCATE on both history tables fail with `PT403` for everyone, incl. the owner and `service_role` (#28) | #27, #28 |
| `0003_rpc.sql` | `transfer_patient`, `set_patient_status` (PLAN §5.3) | #29, #30 |
| `0004_realtime.sql` | **jeszcze nie ma**: publikacja realtime (PLAN §5.4) | #42 |

RLS is on since `0001`. With `0002_rls.sql`, signed-in staff (`authenticated`) read all 5 tables and write nothing directly: a REST `PATCH /rest/v1/patients` fails with `permission denied` (42501). `anon` has no privileges at all. Writes go only through the `SECURITY DEFINER` RPCs in `0003`. Tests: `supabase/tests/0002_rls_test.sql`.

## Projekt w chmurze

Supabase, organizacja zespołu, projekt **Wardline**:

- ref: `fqbyyrsmmhyvlakacioj`, region `eu-west-2`
- URL: `https://fqbyyrsmmhyvlakacioj.supabase.co`
- Klucz `anon` (publishable) bierzecie z panelu (Project Settings › API) do `app/.env.json`. `service_role` nigdy do aplikacji ani do repo.

Wgrane: `0001`, `0003`. Historia migracji w chmurze ma wersje `0001` i `0003`.

**`0002_rls.sql` (#27) is in the repo but not yet applied to the cloud project.** Apply it with the `db push --include-all` below once the PR is merged.

```bash
supabase link --project-ref fqbyyrsmmhyvlakacioj
supabase db push --include-all   # --include-all, bo 0002 jest starsze niż wgrane 0003
```

Konta testowe w chmurze: `SUPABASE_URL` i `SUPABASE_SERVICE_ROLE_KEY` z panelu w `tools/seed_accounts/.env.local`, potem `bash tools/seed_accounts/seed_accounts.sh`.

### Kontrakt RPC

Jedyne ścieżki zapisu. Obie są `SECURITY DEFINER`, wykonywalne tylko przez `authenticated` (nie `anon`). Czas i autor pochodzą z serwera (`now()`, `auth.uid()`).

```sql
transfer_patient(p_patient_id uuid, p_to text, p_expected_version int,
                 p_request_id uuid, p_identified_by text default null)   -- tylko nurse
set_patient_status(p_patient_id uuid, p_status patient_status, p_expected_version int,
                   p_request_id uuid, p_reason text default null)        -- tylko doctor
```

| Kod | Kiedy |
|---|---|
| `PT401` | brak sesji (`auth.uid()` null) |
| `PT403` | zła rola (nurse dla transferu, doctor dla statusu) |
| `PT404` | nieznany pacjent |
| `PT409` | `p_expected_version` nieaktualna; `detail` = JSON `{current_location, status, version}`. Klient pokazuje ekran konfliktu, **bez auto-retry**. |
| `PT422` | zły / ten sam oddział, ten sam status, wypis bez powodu, brak `p_request_id`, request id użyte dla innego pacjenta |

Ten sam `p_request_id` zwraca to samo zdarzenie (podwójny tap, "Check status" po timeoucie). `version` jest wspólna dla lokalizacji i statusu (decyzja z PLAN §5.3).

## Konta testowe (#18)

`tools/seed_accounts/seed_accounts.sh` tworzy przez Admin API pięć fikcyjnych kont z profilami:

| Login | Osoba | Rola | Oddział |
|---|---|---|---|
| `nurse1@wardline.test` | Anna Nowak | nurse | INT |
| `nurse2@wardline.test` | Marek Kowal | nurse | ER |
| `doctor1@wardline.test` | Dr Piotr Zając | doctor | INT |
| `doctor2@wardline.test` | Dr Julia Wróbel | doctor | CAR |
| `admin@wardline.test` | Katarzyna Wilk | admin | — |

```bash
cat > tools/seed_accounts/.env.local <<'ENV'
WARDLINE_PASSWORD=wymysl-wlasne-haslo
ENV
bash tools/seed_accounts/seed_accounts.sh
```

- URL i klucz `service_role` skrypt bierze z `supabase status` (lokalnie) albo z `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY`.
- Hasła i klucz tylko w `.env.local` albo w zmiennych środowiskowych. `.env.*` jest w `.gitignore`. **Nigdy w repo.**
- Można puszczać wielokrotnie: istniejące konto dostaje nowe hasło i zaktualizowany profil.
- Rolę nadaje tylko ten skrypt (service role) albo admin. Aplikacja nie ma ścieżki do zmiany roli; brak polityki UPDATE dochodzi w `0002_rls.sql` (#27).
- `home_location` ustawia się tylko wtedy, gdy oddział już istnieje (seed oddziałów to #19).

## iOS: NFC entitlement (issue #11)

Co już jest w repo:

- `app/ios/Runner/Runner.entitlements` z `com.apple.developer.nfc.readersession.formats` = `TAG` (NTAG213 przez sesję tagów `nfc_manager`).
- `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` w Debug, Release i Profile targetu Runner (`project.pbxproj`).
- `Info.plist`: `NFCReaderUsageDescription`, `NSCameraUsageDescription` i `com.apple.developer.nfc.readersession.iso7816.select-identifiers` (`D2760000850101`, aplikacja NDEF). CoreNFC wymaga tego klucza przy sesji ISO 14443.

Czego nie da się zrobić z repo (jednorazowo, na Macu):

1. `open app/ios/Runner.xcworkspace`.
2. Target **Runner** → **Signing & Capabilities** → wybierz **Team**.
3. Sprawdź, czy na liście jest capability **Near Field Communication Tag Reading** (Xcode wczyta ją z `Runner.entitlements`). Jeśli Xcode pokazuje błąd "Personal development teams do not support the Near Field Communication Tag Reading capability", to konto jest darmowe (Personal Team) i **NFC na iPhonie nie zadziała**. Potrzebne płatne Apple Developer Program (99 USD/rok) albo konto zespołu uczelni.
4. Nie commituj `DEVELOPMENT_TEAM` z prywatnego konta, jeśli zespół buduje z różnych kont. Ustaw go lokalnie w Xcode.
5. Wpisz poniżej, z jakiego konta podpisujemy build.
6. Test na fizycznym iPhonie (XS lub nowszy): Scan → **Start scanning** → przyłóż tag → ID na ekranie.

**Konto do podpisu:** _do uzupełnienia (imię, typ konta: Personal Team / Apple Developer Program)._

CI buduje iOS z `--no-codesign`, więc entitlement nie psuje pipeline'u.
