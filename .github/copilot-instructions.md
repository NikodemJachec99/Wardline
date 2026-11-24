# Wardline: GitHub Copilot

Every UI change must follow the Wardline design. Before generating UI code, read `.agents/skills/wardline-design/SKILL.md`, `topology.md` and `checklist.md` in the same folder.

- Colours, spacing, radius, elevation, motion, typography: only `WlTokens.of(context)` from `app/lib/core/theme/wl_tokens.dart`. No `Color(0x…)`, `Colors.*` or raw numbers in screens.
- Widgets: reuse `Wl*` widgets from `app/lib/core/widgets/wl/` (names in `design/handoff/components.md`).
- UI copy: English, from `design/handoff/copy.md`.
- Scan never writes. Role-forbidden actions are not rendered. Success only after the server responds. Offline replaces write actions with "Changes need a connection".
- Fictional data only. No secrets.
