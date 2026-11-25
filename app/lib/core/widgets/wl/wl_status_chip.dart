import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

enum WlChipSize { md, sm }

/// Patient status: colour + icon + text, never colour alone. Display only.
class WlStatusChip extends StatelessWidget {
  const WlStatusChip(
    this.status, {
    this.size = WlChipSize.md,
    this.short = false,
    super.key,
  });

  final PatientStatus status;
  final WlChipSize size;

  /// Dense lists: "Ready" instead of "Ready for Discharge". Semantics keep the
  /// full label.
  final bool short;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final s = t.colors.status(status);
    final md = size == WlChipSize.md;
    final textStyle = (md ? t.typography.subhead : t.typography.caption)
        .copyWith(color: s.fg, fontWeight: FontWeight.w600);
    return Semantics(
      label: 'Status: ${s.label}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: WlMotion.duration(context, t.motion.base),
        curve: t.motion.out,
        constraints: BoxConstraints(minHeight: md ? 32 : 24),
        padding: EdgeInsets.symmetric(
          horizontal: md ? t.space.sm - 2 : t.space.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(md ? t.radius.chip : 6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(WlIcons.forStatus(status), size: md ? 16 : 14, color: s.fg),
            SizedBox(width: md ? 6 : t.space.xxs),
            Flexible(
              child: Text(short ? s.shortLabel : s.label, style: textStyle),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status labels without a BuildContext (toasts, semantics, tests).
abstract final class WlStatusLabels {
  static String of(PatientStatus s) => WlTokens.light.colors.status(s).label;
}
