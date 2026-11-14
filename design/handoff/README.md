# Wardline design handoff

Everything Claude Code (or a person) needs to build the Wardline UI in Flutter, matching the design canvas.

> SIMULATION ONLY. All names, IDs and numbers here are fictional.

## Source of truth

- **Design canvas** (private until shared from its Share menu): https://claude.ai/artifact/W1xGQWDTSiCacKQMSiUwqu
  - Page *Design system*: tokens and all `Wl*` components with their states.
  - Page *Screens*: dashboard (2 layouts, B chosen), patient profile, scan.
  - Page *Journeys*: transfer, status, sign in, patients list, history, notifications, settings, offline mode, admin, Android + large text.
  - Page *Map & analytics*: live map, map states, analytics (tablet), ward monitor, demo mode.
  - Page *Prototype & handoff*: clickable prototype (flows 1–5), two-device sync, motion spec, handoff tables.
- **Product rules and backend**: `docs/PLAN.md` (RPC names, error codes, RLS). Where this bundle and PLAN disagree, see "Decisions" below.

## Files

| File | What it is |
|---|---|
| `CLAUDE_CODE_BRIEF.md` | The brief to give Claude Code. Start here. |
| `tokens.json` | All design tokens, names exactly as on the canvas. |
| `flutter/wl_tokens.dart` | Ready `ThemeExtension<WlTokens>` + status/occupancy/role helpers. Move to `app/lib/core/theme/`. |
| `components.md` | Every `Wl*` widget: purpose, API, states, semantics. |
| `screens.md` | Every screen: route, components, states, data, role differences. |
| `flows.md` | The 6 prototype flows as acceptance criteria. |
| `motion.md` | Every animation: trigger, property, duration, easing, reduced-motion fallback. |
| `platform-and-a11y.md` | iOS/Android specifics, safe areas, accessibility rules. |
| `copy.md` | All user-facing English strings for states and errors. |
| `sample-data.json` | Departments (with map geometry), staff, patients, today's events. Consistent with every screen. |

## Decisions (resolve before coding)

1. **UI language.** The design brief says all UI copy is English. `docs/PLAN.md`, `shell_scaffold.dart` and the PLAN seed use Polish ("Pacjenci", "SOR", "Izba Przyjęć"). This bundle is English. If the team wants Polish, translate `copy.md` and keep the keys.
2. **No disabled actions.** PLAN says "button disabled + tooltip" offline. The design replaces the action with a one-line explanation ("Changes need a connection"). Role-forbidden actions are absent, not disabled.
3. **Map geometry.** PLAN's `map_x/y/w/h` values do not match the designed floor plans. Use `sample-data.json → departments[].map` (10 × 6 units per floor, lift core at x 8.5).
4. **Patient IDs.** Crockford Base32 excludes I, L, O, U. Three earlier design IDs contained `L`; they are fixed here (`HPT-9RT2KM5C`, `HPT-1QH8VX3B`, `HPT-9VG3HJ7N`).
5. **Glass.** Do not use `BackdropFilter` for the KPI cards: the gradient behind them is flat, so blur is invisible and costs GPU. White at 72% + a 60% white hairline looks identical.
6. **Optional features** (sync queue, pending transfers, admin, analytics, ward monitor, demo mode) come after the P0 core. Pending transfers add a second confirmation the core model doesn't have; ship without it unless you can defend it.
