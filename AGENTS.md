# Wardline: instrukcje dla agentów AI (Codex, Cursor, Copilot, Gemini, inne)

**SIMULATION ONLY: tylko fikcyjne dane.**

## Design jest obowiązkowy

Każda zmiana dotykająca UI, tekstów, ekranów, widgetów, animacji, nawigacji, dostępności albo flow użytkownika **musi** być zgodna z designem Wardline. Zanim zaczniesz, przeczytaj:

1. `.agents/skills/wardline-design/SKILL.md`: zasady, hierarchia źródeł, czego nie wolno.
2. `.agents/skills/wardline-design/topology.md`: ekran → artboard → spec → ścieżka w kodzie.
3. `.agents/skills/wardline-design/checklist.md`: sprawdzasz przed PR.

To skill w standardzie [Agent Skills](https://agentskills.io/specification): Codex, Copilot, Gemini CLI i Cursor wykrywają `.agents/skills/` same. Claude Code dostaje lokalną kopię w `.claude/skills/` (hook + `tools/sync-agent-skills.sh`, kopia nie jest commitowana). Edytujesz tylko `.agents/skills/`. Nie wymyślasz kolorów, odstępów, tekstów ani układów. Wartości tylko z `app/lib/core/theme/wl_tokens.dart` (`WlTokens.of(context)`), teksty z `design/handoff/copy.md`, wygląd z `design/canvas/*.dc.html`.

Pozostałe zasady i komendy: `CLAUDE.md` i `CONTRIBUTING.md`.
