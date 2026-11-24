# Checklista zgodności z designem

Przechodzisz ją przed otwarciem PR z UI i przy review cudzego PR. Każde "nie" to poprawka albo jedno zdanie w PR, dlaczego wyjątek.

## Źródło

- [ ] W opisie PR jest nazwa artboardu (np. `TransferFlow` krok 5) i zrzut ekranu z aplikacji obok niego.
- [ ] Wszystkie stany ekranu z `design/handoff/screens.md` istnieją (loading, empty, error, offline + specyficzne).
- [ ] Teksty pochodzą z `design/handoff/copy.md` (albo zostały tam dopisane w tym PR). Język UI: angielski.

## Tokeny i widgety

- [ ] Zero `Color(0x…)`, `Colors.*`, surowych `EdgeInsets`/`BorderRadius`/`Duration` w ekranach. Grep:
  ```bash
  grep -rnE "Color\(0x|Colors\.|Duration\(milli|BorderRadius\.circular\([0-9]|EdgeInsets\.(all|symmetric|only)\([0-9]" app/lib/features app/lib/app
  ```
  Wynik ma być pusty (wartości żyją w `app/lib/core/theme/wl_tokens.dart`).
- [ ] Użyte istniejące `Wl*` widgety; nowy widget ma nazwę z `components.md` i leży w `app/lib/core/widgets/wl/`.
- [ ] Brak `BackdropFilter`, zdjęć pacjentów, emoji, ciemnego motywu.
- [ ] Brak 6. zakładki w nawigacji.

## Zasady produktu

- [ ] Skan nie wywołuje żadnego zapisu (RPC, insert, update).
- [ ] Akcje spoza roli nie są renderowane (nie `onPressed: null`).
- [ ] Offline: akcja zapisu zastąpiona tekstem "Changes need a connection", nie wyszarzona.
- [ ] Sukces (checkmark, toast) dopiero po odpowiedzi RPC. Spinner + blokada podwójnego tapnięcia. Jeden `client_request_id` na intencję.
- [ ] `PT409` → ekran konfliktu, bez auto-retry.
- [ ] Status = kolor + ikona + tekst; obłożenie = kolor + %.
- [ ] Lokalizacja i status w osobnych wierszach / komponentach.

## Dostępność i platformy

- [ ] Każdy interaktywny element ≥ 48×48dp i ma `Semantics` z etykietą.
- [ ] Test przy `TextScaler.linear(2)` bez overflow.
- [ ] Reduced motion: `WlMotion.reduced(context)` daje fallback z `motion.md`.
- [ ] Brand teal (`colors.primary`) nie jest kolorem tekstu.
- [ ] Safe area z `MediaQuery.paddingOf` / `SafeArea`, bez stałych liczb.

## Testy

- [ ] Golden / widget test dla każdego nowego stanu.
- [ ] Jeśli PR realizuje flow z `design/handoff/flows.md`: test sprawdza jego asercje (np. liczba wywołań RPC).
- [ ] `dart format`, `flutter analyze`, `flutter test` zielone lokalnie.
