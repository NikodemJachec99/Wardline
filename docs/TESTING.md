# Testy

> Stub. Uzupełnia osoba odpowiedzialna w ramach swojego issue. Źródło: [PLAN.md](PLAN.md#12-testy-akceptacyjne-z-pdf-i-jak-je-zaliczyć).

## Macierz urządzeń

| Urządzenie | OS | NFC | QR | Realtime | Offline | Konflikty | Uwagi |
|---|---|---|---|---|---|---|---|
| iPhone | iOS __ | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Android z NFC | Android __ | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Android bez NFC / NFC off | Android __ | fallback ☐ | ☐ | — | — | — | test 6 |

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

