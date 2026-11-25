# Motion spec

Tokens: `motion.fast` 120ms · `motion.base` 220ms · `motion.slow` 380ms · `easing.out` = `Curves.easeOutCubic` · `motion.sheetSpring` = `SpringDescription(mass: 1, stiffness: 420, damping: 38)` (damping ratio ≈ 0.93, no visible bounce).

Reduced motion is on when `MediaQuery.disableAnimations` **or** the in-app "Reduce motion" switch is on → `WlMotion.reduced(context)`. Nothing that confirms a write may animate before the server answers.

| Element | Trigger | Property | Duration | Easing | Reduced motion | Flutter |
|---|---|---|---|---|---|---|
| Card stagger | Dashboard first build (not on tab return) | opacity 0→1, y +8→0 | base 220, +40ms per card, max 6 | out | opacity 120ms, no offset, no stagger | `FadeTransition` + `SlideTransition`, `Interval` per index |
| KPI count-up | First data; live value change | integer tween old→new | 760 first load, slow 380 live | out | final value at once | `TweenAnimationBuilder<int>`; semantics announces final value only |
| Sparkline / chart draw-in | First time on screen per session | path trim 0→1; bar height 0→v | slow 380, bars +20ms each | out | static final chart | `CustomPainter(progress)`, `PathMetric.extractPath` |
| NFC rings | Scan screen idle / listening | 3 rings: scale .42→1, alpha .55→0, offset 1s | 3000 loop | out | 3 static rings at 18/12/7% alpha | `AnimationController..repeat()`; stop on dispose |
| Live pulse | Connection = live | ring 0→7px, alpha .45→0 | 2000 loop | out | static dot | pause when app is backgrounded |
| Scan-area brighten | Tag read OK (iOS: after system sheet closes) | bg #F3F5F8→#D5F0F1, scale .92→1; check pops .6→1 | slow 380; check 220 @120ms | out | colour swap, no scale | `HapticFeedback.mediumImpact()` on the same frame |
| Bottom sheet | open / drag / close | y 100%→0 | sheetSpring; close fast 120 | spring; easeInCubic on exit | fade 120ms | `showModalBottomSheet(sheetAnimationStyle:)` + `SpringSimulation` |
| Scrim | with any sheet | alpha 0→.32 | base 220 | out | same | `ModalBarrier` `colors.scrim` |
| Transfer A→B indicator | Confirm screen visible | dot moves along dashed connector, fades in/out | 1600 loop; 900 while saving | easeInOutCubic | static arrow | stops on success / conflict / timeout |
| Button micro-scale | pointer down / up | scale 1→.98→1 | fast 120 | out | none (pressed colour only) | `AnimatedScale` inside `WlButton`; not when loading |
| Loading → checkmark | RPC returned 200 (never before) | circle stroke 0→1, then tick stroke | 380 + 260 @300ms | out | static check, 120ms fade | `CustomPainter`; driven by `AsyncData`, not by the tap |
| Spinner | request in flight | rotate 360° | 800 loop | linear | kept (essential), 1600 loop | `CircularProgressIndicator.adaptive`, 20dp |
| Live-update row highlight | Realtime event for a visible row | bg `primarySoft` hold, fade to surface | 2400 (hold 60%) @300ms | out | static "Updated" dot for 5s | `TweenAnimationBuilder<Color?>`; `ValueKey(patient.id)` keeps scroll |
| Feed entry | New event in a visible activity feed (realtime, own write, refetch); not on first build | height 0→auto, opacity 0→1, y −8→0 | base 220 | out | appears at once; live highlight / "Updated" dot still marks it | `SizeTransition` + `FadeTransition`, keyed by event id so existing rows never replay |
| Status colour cross-fade | status changed | chip bg/fg + 4dp status bar | base 220 | out | instant | `AnimatedContainer` / `ColorTween`; icon via `AnimatedSwitcher` |
| Tab indicator slide | tab change | pill x-position + label weight | base 220 | out | instant | custom `WlBottomNav`, `AnimatedPositioned` |
| Pull-to-refresh | overscroll ≥ 72dp | indicator follows finger, spins while loading | follows drag; settle 220 | out | platform default, no bounce | `RefreshIndicator.adaptive` |
| Skeleton shimmer | load > 300ms | gradient x −200→+200 | 1200 loop | linear | static grey blocks | `ShaderMask` over `WlSkeleton`, one controller per screen |
| Map dot movement | Realtime transfer, both departments visible | dot travels A→B, then 2s ring on B | 2600 once per event | easeInOutCubic | dot appears on B + 2s highlight | map `CustomPainter`; queue events, max 3 at once |
| Route draw | route opened | polyline dash offset → 0; stops pop in order | 900; stops +80ms each | out | full route at once | `PathMetric`; stops are widgets with semantics |
| Page push | navigation | slide 24pt + fade (Android); Cupertino on iOS | base 220 | out | crossfade 120 | `CustomTransitionPage`; keep iOS swipe-back |
| Toast | show / auto-dismiss after 4s | y +8→0, fade | base 220 in, fast 120 out | out | fade only | overlay above nav, `liveRegion: true` |
| Map floor / 2D-3D switch | segmented control | crossfade + plate scale .96→1 | base 220 | out | instant swap | `AnimatedSwitcher` keyed by floor + mode |
