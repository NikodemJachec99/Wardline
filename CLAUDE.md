# Wardline: instrukcje dla Claude Code

Szpitalna aplikacja do śledzenia pacjentów (Flutter iOS + Android, Supabase). Projekt uczelniany. **SIMULATION ONLY: tylko fikcyjne dane.**

## Design jest obowiązkowy

**Przed każdą pracą dotykającą UI, tekstów, ekranów, widgetów, animacji, nawigacji, dostępności albo flow użytkownika wczytaj skill `wardline-design`** (`.agents/skills/wardline-design/SKILL.md`) i trzymaj się go. Dotyczy też review PR i planowania issue. Nie wymyślasz własnych kolorów, odstępów, tekstów ani układów: wszystko jest w `design/` i `app/lib/core/theme/wl_tokens.dart`.

Skill leży w `.agents/skills/wardline-design/` (standard Agent Skills, czytają go też Codex, Copilot, Gemini CLI, Cursor). Claude Code czyta tylko `.claude/skills/`, więc hook `SessionStart` z `.claude/settings.json` przy każdym starcie sesji kopiuje go tam skryptem `tools/sync-agent-skills.sh`. Kopia w `.claude/skills/` jest lokalna i w `.gitignore`: **edytujesz tylko `.agents/skills/`**. Jeśli skill nie pojawia się na liście, uruchom `bash tools/sync-agent-skills.sh` albo przeczytaj `SKILL.md` bezpośrednio z `.agents/skills/wardline-design/`.

- Topologia (gdzie co leży): `.agents/skills/wardline-design/topology.md`
- Checklista przed PR: `.agents/skills/wardline-design/checklist.md`
- Brief implementacji: `design/handoff/CLAUDE_CODE_BRIEF.md`

## Źródła prawdy

- UI / UX: `design/` (handoff + canvas), według skilla `wardline-design`.
- Produkt, backend, RPC, RLS, błędy `PTxxx`, offline: `docs/PLAN.md`.
- Proces (gałęzie, commity, PR, review): `CONTRIBUTING.md`.

## Zasady, których nie łamiesz

- Skan NFC/QR tylko otwiera pacjenta, nigdy nie zapisuje.
- Uprawnienia egzekwuje backend (RLS + RPC). Akcji spoza roli nie renderujesz.
- Sukces dopiero po odpowiedzi serwera. `PT409` → ekran konfliktu, bez auto-retry.
- Offline: tylko odczyt, akcje zastąpione "Changes need a connection".
- Zero sekretów w repo; klucz `service_role` nigdy w aplikacji. `.env.json` jest w `.gitignore`.

## Komendy (z katalogu `app/`)

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Tytuł PR i commity: Conventional Commits. Opis PR wg `.github/pull_request_template.md`, zawsze `Closes #NR`.
