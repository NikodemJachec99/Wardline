# Backend (Supabase)

> Stub. Uzupełnia osoba odpowiedzialna w ramach swojego issue. Źródło: [PLAN.md](PLAN.md#5-model-danych-i-backend-sql-gotowy-do-migracji).

## Od zera do działającego projektu

1. Zainstaluj Supabase CLI 3.0.0 i Docker.
2. `supabase start` w katalogu głównym repo.
3. `supabase db reset` (migracje + `seed.sql`).
4. Konta testowe: skrypt przez Admin API (TODO, hasła tylko lokalnie).
5. Skopiuj URL i **anon key** do `app/.env.json`. `service_role` nigdy nie trafia do aplikacji.

## Migracje

`supabase/migrations/`: schemat, RLS i granty, RPC, realtime, analityka (PLAN §5.1–5.4, §8.2).

## iOS: NFC entitlement (krok ręczny)

API GitHub ani `flutter create` tego nie ustawią. Raz, na Macu, z płatnym kontem Apple Developer Program:

1. `open app/ios/Runner.xcworkspace`
2. Target **Runner** → **Signing & Capabilities** → wybierz Team.
3. **+ Capability** → **Near Field Communication Tag Reading**.
4. Xcode utworzy `Runner/Runner.entitlements` z kluczem `com.apple.developer.nfc.readersession.formats` = `TAG` (dla NDEF wystarczy). Zacommituj ten plik i zmianę w `project.pbxproj`.
5. `NFCReaderUsageDescription` jest już w `Info.plist`.
6. Sprawdź na fizycznym iPhonie (XS lub nowszy): odczyt taga NDEF.

Darmowe konto Personal Team zwykle nie obsługuje tej capability. Sprawdzić w W1.

