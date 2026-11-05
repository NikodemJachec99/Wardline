<!-- Tytuł PR = Conventional Commit (np. "feat: add transfer confirmation sheet"). Squash bierze go jako commit na main. -->

## Powiązane issue

Closes #

## Co i dlaczego

<!-- 2-5 zdań. Co się zmienia i po co. -->

## Jak przetestowano

- [ ] `flutter analyze` i `flutter test` lokalnie
- [ ] Emulator / symulator
- [ ] Fizyczny Android (model, wersja):
- [ ] Fizyczny iOS (model, wersja):
- [ ] `supabase test db` (jeśli zmiany w `supabase/`)

## Zrzuty / nagranie

<!-- Wymagane przy zmianach UI. Przeciągnij plik tutaj. -->

## Wpływ na bezpieczeństwo

- [ ] Brak zmian w RLS / RPC / grantach
- [ ] Zmiany w RLS / RPC / grantach, opis poniżej (kto co może po zmianie, testy pgTAP)
- [ ] Brak sekretów w diffie (`service_role`, hasła, `.env.json`)

<!-- Opis wpływu na uprawnienia, jeśli dotyczy -->

## Definition of Done

- [ ] Zielone CI (`ci-ok`)
- [ ] PR mały (< ~400 linii poza plikami generowanymi) albo uzasadnione, czemu większy
- [ ] Skan nie zapisuje lokalizacji; sukces pokazywany dopiero po odpowiedzi backendu (jeśli dotyczy)
- [ ] Przetestowane na fizycznym urządzeniu (NFC / kamera / realtime)
- [ ] Zaktualizowane `docs/` (jeśli dotyczy)
