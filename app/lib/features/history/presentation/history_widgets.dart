// Small building blocks shared by the History screens (HistoryFlow
// artboard). Candidates for core widgets once another feature needs them.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';

/// Segmented control (`.seg` on the artboard): `subtle` track, white
/// selected pill. 48dp hit height, one semantics node per segment.
class HistorySegmented<T> extends StatelessWidget {
  const HistorySegmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      constraints: BoxConstraints(minHeight: t.space.touchMin),
      padding: EdgeInsets.all(t.space.xxs - 1),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: BorderRadius.circular(t.radius.chip + 2),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (value, label) in segments)
              Expanded(
                child: _Segment(
                  label: label,
                  on: value == selected,
                  onTap: () => onChanged(value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      selected: on,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: WlMotion.duration(context, t.motion.base),
          curve: t.motion.out,
          constraints: BoxConstraints(minHeight: t.space.touchMin - 6),
          padding: EdgeInsets.symmetric(horizontal: t.space.xxs),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.surface : c.subtle,
            borderRadius: t.radius.chipBr,
            boxShadow: on ? t.elevation.e1 : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: t.typography.subhead.copyWith(
                color: on ? c.text : c.textSecondary,
                fontWeight: on ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uppercase group label ("LAST 30 MINUTES").
class HistoryGroupLabel extends StatelessWidget {
  const HistoryGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.gutter + t.space.xxs,
        t.space.md,
        t.space.gutter + t.space.xxs,
        t.space.xs - 2,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: t.typography.overline.copyWith(color: t.colors.textSecondary),
        ),
      ),
    );
  }
}

/// White rounded box (`.box`) around a sliver of rows.
class HistoryBox extends StatelessWidget {
  const HistoryBox({required this.sliver, super.key});

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: t.radius.cardBr,
          border: Border.all(color: c.border),
        ),
        sliver: SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          sliver: sliver,
        ),
      ),
    );
  }
}

/// Hairline between rows inside a [HistoryBox].
class HistoryDivider extends StatelessWidget {
  const HistoryDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = WlTokens.of(context).colors;
    return Container(height: 1, color: c.border);
  }
}

/// Offline banner (or the 3s "Back online" variant) for read-only screens.
class HistoryConnectionBanner extends ConsumerWidget {
  const HistoryConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = WlTokens.of(context);
    final conn = ref.watch(connectivityProvider);
    final Widget? banner = !conn.online
        ? WlOfflineBanner(syncedAt: hm(conn.syncedAt))
        : conn.backOnlineAt != null
        ? WlOfflineBanner.backOnline(syncedAt: hm(conn.syncedAt))
        : null;
    if (banner == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.gutter,
        0,
        t.space.gutter,
        t.space.sm,
      ),
      child: banner,
    );
  }
}

/// Connection pill in the History header. The artboard draws a static dot
/// here (no pulse), so the ticker is muted.
class HistoryConnectionPill extends ConsumerWidget {
  const HistoryConnectionPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectivityProvider.select((c) => c.state));
    return TickerMode(
      enabled: state != WlConnectionState.live,
      child: WlConnectionIndicator(state: state),
    );
  }
}
