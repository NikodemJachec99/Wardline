# Wl components

One section per widget. Names map 1:1 to Flutter classes in `app/lib/core/widgets/wl/`. Every value comes from `WlTokens`. "States" = what needs a golden test.

## WlButton
- **Variants**: `primary` (fill `primaryInk`, white label), `secondary` (white, `borderStrong` 1px), `destructive` (fill `danger`), `text` (no fill, `primaryInk` label).
- **API**: `WlButton({required String label, VoidCallback? onPressed, WlButtonVariant variant, IconData? icon, bool loading = false, String? loadingLabel, bool fullWidth = true})`.
- **Size**: 56 high (primary actions), 48 (secondary in sheets); radius `radius.input`; label `type.label`.
- **States**: default · pressed (scale 0.98 + `primaryInkPressed` / `subtle` / `dangerPressed`) · focus (2px white gap + 2px `primary` ring) · disabled (`border` fill, `textDisabled` label; use only for invalid forms, never for role or offline) · loading (spinner 20dp + `loadingLabel`, `aria-busy`, taps ignored).
- **Semantics**: button; when loading, `label: "$loadingLabel"`, `enabled: false`.

## WlStatusChip
- **API**: `WlStatusChip(PatientStatus status, {WlChipSize size = md, bool short = false})`.
- **Look**: bg `status.bg`, icon + text `status.fg`, md 32 high / radius 8 / 14px, sm 24 / radius 6 / 12px. `short` renders "Ready" but keeps the full semantics label.
- **States**: 4 statuses × md/sm. Display only, not tappable.
- **Semantics**: `label: "Status: ${style.label}"`, icon excluded.

## WlInitialsAvatar
- **Patient**: neutral `subtle` circle + `border` hairline, initials `textSecondary`. Sizes 56/40/32. Never a photo, never status-coloured.
- **Staff**: role bg + 2px inset ring in role colour + initials in role fg. Always paired with a visible role label somewhere nearby (doctor violet = In Treatment violet).
- **Semantics**: excluded when the name is next to it; otherwise `label: name`.

## WlPatientCard
- **Compact** (lists): 72–80 high, 4dp left status bar (`status.base`), avatar 40, name + age, sub line (location or "Moved to X · now"), `WlStatusChip(sm)`, chevron. Whole card is one button.
- **Expanded** (profile header): avatar 56, name `title1`, age · ID (`type.id`), then two separate rows: Status (chip) and Last location (map-pin + name + floor + "since HH:MM · by").
- **States**: default · pressed · live highlight (`WlLiveHighlight`, see motion) · cached (sub line "as of 10:42") · swiped (actions: View profile, Show on map; never transfer) · skeleton.
- **Semantics**: one merged node: "Jan Kowalczyk, 54, Laboratory, In Treatment, button"; swipe actions as `customSemanticsActions`.

## WlKpiCard
- **API**: `WlKpiCard({label, int value, List<double> trend, String delta, bool loading, bool cached})`.
- Glass surface (`glassFill` + `glassBorder`, radius 16), label `caption` secondary, value `type.kpi` with count-up, sparkline 64×24 (`primaryInk` 1.75 stroke, 14% area), delta in `textSecondary` (neutral: more patients isn't good or bad).
- **States**: default · loading (skeleton bars) · cached (value in secondary + "Synced 10:42" warning chip).
- **Semantics**: "Transfers today, 42, up 5 versus last hour". Count-up frames are not announced.

## WlDeptOccupancyBar
- Row: code badge, name, "29/32 beds", 8–10dp track (`subtle`) with fill `occupancy(%).fill`, % label (tabular). Tappable in charts (selected row bg `subtle`).
- **Semantics**: "Internal Medicine, 29 of 32 beds, 91 percent, high".

## WlSearchBar
- 48 high, radius 12, `subtle` fill, search icon, placeholder "Name, ID or department". Focus: white fill, 1px `primary` border + 3px `primarySoft` ring, clear button (32dp icon in a 48dp target).
- **Sticky**: pinned under the large title; when content scrolls under it, background `page` at 94% + `elevation.e1`.

## WlFilterChips
- Horizontal scroll, 36 visual / 48 hit, radius 8. Selected: `primarySoft` + 1px `primary` + `primaryInk` 600 + check icon. Counts in tabular figures. Dropdown chips ("Department ▾", "Status ▾") open a sheet.

## WlBottomNav
- 64 + bottom inset. Tabs: Dashboard, Patients, Scan, History, Profile. Selected: 56×30 `primarySoft` pill behind icon + `primaryInk` label 600. Scan: raised 64dp `primary` circle, 4dp white ring, `elevation.e2`, white scan-line icon 28.
- Android: same component on 80dp + gesture inset.

## WlBottomSheet
- Radius 24 top, handle 36×5, padding 16 / bottom 34, `elevation.e3`, scrim 32%. Spring open, `motion.fast` close. Locks (no drag-dismiss, no barrier dismiss) while a request is in flight.
- Variants used: quick summary (scan), choose destination, change status, department, conflict, timeout, filters, patients-on-map (draggable, half/full).

## WlTimelineItem
- Node 32dp circle (transfer `primarySoft`/`primaryInk`, status `status.inTreatment.bg/fg`, admission `status.admitted.bg/fg`), 2dp rail, title + time (tabular) + line + staff (initials 20dp, name, role in role fg). Expandable details (From, To, identified by, server confirmed, time in previous dept). New item: live highlight.

## WlActivityFeedItem
- Staff avatar 32 + "Who did what" (bold patient), sub line (from/to or status change), time ago. Live variant: `primarySoft` bg fading out + teal dot.

## WlTransferPath
- Big (confirm): From card (`subtle`) → dashed connector with moving dot → To card (`primarySoft` + 1.5px `primary`). Inline: "Internal Medicine → Laboratory" with teal arrow. Pending: To card dashed `borderStrong`, "Choose department".
- **Semantics**: "From Laboratory to Radiology".

## WlOfflineBanner · WlCacheBadge · WlConnectionIndicator
- Banner: `warningBg` + `warningBorder`, wifi-off icon, "You're offline. Showing data from 10:42. It may be out of date." Back-online variant: green, auto-hides 3s.
- CacheBadge: neutral `Cached · synced 10:42` under 15 min, warning style `… · may be outdated` after.
- ConnectionIndicator: Live (green dot + pulse) · Reconnecting… (amber spinner, after 3s) · Offline (grey wifi-off, after 15s or OS offline).

## WlEmptyState · WlErrorState
- 56dp icon circle, title `title3`, body `subhead` secondary, one primary and at most one secondary action. Error variants: load failed (danger), conflict PT409 (warning, Who/When/Where table), timeout (neutral, request reference), unknown tag, NFC unavailable, camera denied. Copy in `copy.md`.

## WlSkeleton
- `subtle`/`#EEF1F5` blocks shaped like the real content; shimmer 1.2s; shown only after 300ms to avoid flashing.

## WlToast
- White card, `elevation.e2`, radius 16, 32dp icon circle, title + body, optional text action ("Try again", "View"). Above the nav, 4s, live region. Success toast only after server confirmation.

## WlMiniMap · WlDepartmentCard
- MiniMap: one floor, isometric or flat, departments tinted by occupancy, selected dept 3dp `primary` ring, patient pin (initials in `primaryInk` circle). Tappable → full map focused on that floor.
- DepartmentCard: code · floor, name, occupancy bar + "% · N free", status breakdown dots. Full map uses the same data with the 3D/2D renderer (`sample-data.json` geometry).
