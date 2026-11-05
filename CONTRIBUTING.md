# Jak pracujemy

Źródło prawdy dla zakresu i priorytetów: [docs/PLAN.md](docs/PLAN.md). Tablica: [Wardline project](https://github.com/users/NikodemJachec99/projects/4).

## Flow pracy

```
issue → gałąź → PR → review → squash merge
```

1. Bierzesz issue z kolumny **Ready**, przypisujesz się i przesuwasz na **In progress**.
2. Robisz gałąź od aktualnego `main`.
3. Otwierasz PR wcześnie (może być draft). Po otwarciu karta idzie na **In review**.
4. Po zielonym CI i review: **squash merge**. Gałąź usuwa się sama.

Na `main` nikt nie pushuje bezpośrednio. Wszystko idzie przez PR.

## Nazewnictwo gałęzi

```
feat/<nr-issue>-krotki-opis     feat/23-transfer-confirmation
fix/<nr-issue>-krotki-opis      fix/41-qr-permission-crash
chore/…  docs/…  test/…  ci/…
```

Małe litery, myślniki, bez polskich znaków.

## Commity

[Conventional Commits](https://www.conventionalcommits.org/): `typ: opis` albo `typ(zakres): opis`.

Typy: `feat`, `fix`, `chore`, `docs`, `test`, `ci`, `refactor`, `perf`, `style`.

```
feat(transfer): block double tap on confirm button
fix(scan): handle cancelled iOS NFC session
```

Tytuł PR też musi być Conventional Commit, bo squash zrobi z niego commit na `main`. Pilnuje tego workflow `PR title`.

## Pull request

- **Mały.** Celuj w < ~400 linii zmian, nie licząc plików generowanych (`*.g.dart`, `pubspec.lock`, pliki platformowe z `flutter create`). Większy temat = kilka PR.
- **Zawsze `Closes #NR`** w opisie.
- **Zrzut albo nagranie** przy każdej zmianie UI.
- **Zmiany w `supabase/`**: opisz wpływ na RLS / RPC / granty (kto co może po zmianie) i dodaj test pgTAP.
- Wypełnij szablon PR, łącznie z checklistą DoD.

## Review

Reguły na `main` (ruleset `main-protection`):

- wymagane 2 approve, w tym approve CODEOWNERA (@NikodemJachec99),
- nowy push unieważnia wcześniejsze approve,
- wszystkie wątki review muszą być rozwiązane,
- wymagany zielony check `ci-ok`.

Jak robić review:

- [ ] Kod robi to, co mówi issue i kryteria akceptacji?
- [ ] Skan nie zapisuje lokalizacji? Sukces dopiero po odpowiedzi backendu?
- [ ] Błędy `PTxxx` obsłużone, stany loading / empty / error są?
- [ ] Testy dodane i sensowne?
- [ ] Brak sekretów, brak danych, które wyglądają na prawdziwe?
- [ ] Rozumiem ten kod na tyle, żeby wytłumaczyć go prowadzącemu?

Komentarze pisz jako pytania („Co się stanie, jak tu przyjdzie PT409?”), nie rozkazy. **Request changes** tylko przy realnym problemie (bug, bezpieczeństwo, złamanie zasad z planu). Drobiazgi oznaczaj `nit:` i zatwierdzaj.

## Definition of Done

- [ ] Zielone CI (`ci-ok`).
- [ ] Review zgodnie z regułami powyżej.
- [ ] Przetestowane na fizycznym urządzeniu, jeśli dotyczy NFC, kamery albo realtime (etykieta `needs-device-test`).
- [ ] Zaktualizowane `docs/`, jeśli zmienia się zachowanie, schemat albo uprawnienia.
- [ ] Zero sekretów w repo.

## Zasady bezpieczeństwa

- **Uprawnienia egzekwuje backend** (RLS + RPC `SECURITY DEFINER` z kontrolą roli). UI tylko je odzwierciedla. Żadnych zapisów bezpośrednio do tabel.
- **Skan NFC/QR nigdy nie zmienia lokalizacji.** Tylko otwiera rekord.
- **Sukces dopiero po odpowiedzi backendu.** Żadnych optymistycznych checkmarków.
- Offline: zapisy zablokowane, nic nie kolejkujemy po cichu.
- Na tagach i w QR tylko identyfikator `HPT-XXXXXXXX`. Zero danych medycznych.
- Tylko fikcyjne dane. Klucz `service_role` nigdy w aplikacji ani w repo. `.env.json` jest w `.gitignore`. Push protection blokuje wykryte sekrety.

## Wymóg kursu

**Każdy członek zespołu musi umieć wyjaśnić cały system**: flow skan → transfer → realtime, RLS, RPC, idempotencję i konflikty. „To robił X” na pytanie prowadzącego to minus dla wszystkich. Dlatego review robią wszyscy, a w W7 każdy ma issue „opisz flow własnymi słowami” i pisze własny test pgTAP.
