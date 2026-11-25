# Testy

> Stub. Uzupełnia osoba odpowiedzialna w ramach swojego issue. Źródło: [PLAN.md](PLAN.md#12-testy-akceptacyjne-z-pdf-i-jak-je-zaliczyć).

## Macierz urządzeń

| Urządzenie | OS | NFC | QR | Realtime | Offline | Konflikty | Uwagi |
|---|---|---|---|---|---|---|---|
| iPhone | iOS __ | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Android z NFC | Android __ | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Android bez NFC / NFC off | Android __ | fallback ☐ | ☐ | — | — | — | test 6 |

## Uruchomienie na fizycznym urządzeniu (issue #12)

Android:

```bash
cd app
flutter devices
flutter run -d <id-telefonu>
```

Telefon: Opcje programisty → Debugowanie USB. NFC: Ustawienia → Połączone urządzenia → NFC włączone.

iOS (tylko Mac z Xcode):

```bash
cd app
flutter run -d <id-iphone>
```

Najpierw jednorazowo podpis w Xcode, patrz [BACKEND.md → iOS: NFC entitlement](BACKEND.md#ios-nfc-entitlement-issue-11). Na iPhonie: Ustawienia → Prywatność → Tryb dewelopera → włącz. Przy pierwszym uruchomieniu: Ustawienia → Ogólne → VPN i urządzenia → zaufaj certyfikatowi.

Test NFC (#13): tag NTAG213 z jednym rekordem NDEF Text, np. `HPT-7K3M9QXA` (zapis aplikacją NFC Tools). Ten sam tag na obu telefonach ma pokazać ten sam payload. Wynik wpisz do macierzy wyżej (model, wersja OS).

## 8 testów akceptacyjnych

| # | Test | iOS | Android | Dowód |
|---|---|---|---|---|
| 1 | Login + ten sam pacjent przez NFC i QR | ☐ | ☐ | |
| 2 | Transfer jako Nurse, zmiana na drugim urządzeniu | ☐ | ☐ | |
| 3 | Wpis historii: from, to, czas serwera, aktor | ☐ | ☐ | |
| 4 | Zmiana statusu jako Doctor | ☐ | ☐ | |
| 5 | Backend odrzuca nieautoryzowane zmiany (bypass UI) | — | — | |
| 6 | Nieznany ID, anulowanie, brak NFC, odmowa kamery | ☐ | ☐ | |
| 7 | Offline: baner, cache, blokada zapisów | ☐ | ☐ | |
| 8 | Powtórne wysłanie i równoległe transfery | ☐ | ☐ | |

## Testy automatyczne

pgTAP (`supabase test db`), Dart unit + widget (`flutter test`), integration_test, `tools/concurrency_test`.

## Znane ograniczenia

TODO.

