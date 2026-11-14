# Brief for Claude Code: implement the Wardline UI

You are implementing the Wardline Flutter app UI in `app/` from this handoff bundle. Read, in order: `design/handoff/README.md`, `tokens.json`, `components.md`, `screens.md`, `flows.md`, `motion.md`, `platform-and-a11y.md`, `copy.md`, then `docs/PLAN.md` sections 2, 5 and 6 for the backend contract.

## Non-negotiable product rules

1. Scanning (NFC or QR) only opens a patient. It never writes anything.
2. Nurse can transfer (RPC `transfer_patient`). Doctor can change status (RPC `set_patient_status`). Actions a role can't perform are **not rendered**, never shown disabled.
3. Location and status are separate fields, separate components, separate rows.
4. Success (checkmark, toast) only after the RPC returns. Button shows a spinner and ignores repeat taps while in flight. One `client_request_id` per user intent, reused for "Check status" after a timeout.
5. Offline: browse cached data (Drift) with `WlCacheBadge` + `WlOfflineBanner`; every write action is replaced by "Changes need a connection". No silent queueing (the sync queue is a P3 flag, default OFF).
6. `PT409` → conflict screen with who, from → to, when, and "Refresh and choose again". Never auto-retry.
7. Status is always colour + icon + text. Occupancy is always colour + % label.

## Implementation order (each step = one PR, green CI)

1. **Theme**: done in PR #70 (`app/lib/core/theme/wl_tokens.dart`, `buildTheme()` registers `WlTokens.light`, Inter 400–700 bundled). Remaining: add `lucide_icons_flutter` (or equivalent) for icons. Widget test: `Theme.of(context).extension<WlTokens>()` is not null.
2. **Core widgets** in `app/lib/core/widgets/wl/`: `WlButton`, `WlStatusChip`, `WlInitialsAvatar`, `WlPatientCard`, `WlSearchBar`, `WlFilterChips`, `WlBottomNav`, `WlBottomSheet`, `WlSkeleton`, `WlToast`, `WlOfflineBanner`, `WlCacheBadge`, `WlConnectionIndicator`, `WlEmptyState`, `WlErrorState`. Golden test per widget per state listed in `components.md`.
3. **Shell + navigation**: replace the Material `NavigationBar` in `shell_scaffold.dart` with `WlBottomNav` (raised Scan button). English labels: Dashboard, Patients, Scan, History, Profile.
4. **Patients list → profile** (flows 3 and 4): sticky search, filter chips, live highlight, offline cached state, empty/loading/error.
5. **Scan** (flow 1, first half): NFC ready (iOS user-initiated session, Android reader mode), QR mode, all edge states from `copy.md`, quick summary sheet.
6. **Transfer** (flows 1, 2, 6): destination sheet with search, confirm screen with `WlTransferPath`, saving, success with checkmark draw, conflict, timeout, offline replacement.
7. **Change status** (flow 3).
8. **Dashboard** (layout B) with `WlKpiCard`, feed, occupancy, map entry card.
9. **History**, notifications, settings (Reduce motion switch).
10. **Map** (flow 5), then optional features.

## Definition of done per screen

- All states in `screens.md` exist and have a golden or widget test.
- Text scale 2.0 renders without overflow (test with `MediaQuery(textScaler: TextScaler.linear(2))`).
- Reduced motion path works (`WlMotion.reduced(context)` true → fallbacks from `motion.md`).
- Every interactive element ≥ 48×48 dp and has a semantics label (`platform-and-a11y.md`).
- No hard-coded colours, sizes or durations: only `WlTokens`.

## Don't

- Don't rename `Wl*` widgets or tokens.
- Don't add a 6th tab (the map is reached from the dashboard card and the profile mini map).
- Don't use `BackdropFilter` for the glass cards.
- Don't show patient photos, emojis, neon or dark "terminal" styling.
- Don't store anything but the patient ID on NFC tags or in QR codes.
