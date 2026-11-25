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
