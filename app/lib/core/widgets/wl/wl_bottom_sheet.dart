import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';

/// Opens a Wardline sheet: radius 24 top, handle, scrim 32%, e3 shadow.
///
/// Pass [busy] for sheets that send a request: while it is true the sheet
/// can't be closed by back, barrier tap or drag (drag is off for such
/// sheets).
Future<T?> showWlBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  ValueListenable<bool>? busy,
  bool isScrollControlled = true,
}) {
  final t = WlTokens.of(context);
  final reduced = WlMotion.reduced(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    enableDrag: busy == null,
    backgroundColor: const Color(0x00000000),
    barrierColor: t.colors.scrim,
    elevation: 0,
    sheetAnimationStyle: AnimationStyle(
      duration: reduced ? t.motion.fast : t.motion.slow,
      reverseDuration: t.motion.fast,
      curve: t.motion.out,
    ),
    builder: (context) {
      final sheet = WlBottomSheet(child: builder(context));
      if (busy == null) return sheet;
      return ValueListenableBuilder<bool>(
        valueListenable: busy,
        builder: (context, isBusy, child) =>
            PopScope(canPop: !isBusy, child: child!),
        child: sheet,
      );
    },
  );
}

/// The sheet surface. Use through [showWlBottomSheet].
class WlBottomSheet extends StatelessWidget {
  const WlBottomSheet({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: t.radius.sheetBr,
          boxShadow: t.elevation.e3,
        ),
        padding: EdgeInsets.fromLTRB(
          t.space.md,
          t.space.xs,
          t.space.md,
          (safe > 0 ? safe : t.space.md) + t.space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: EdgeInsets.only(bottom: t.space.sm),
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: BorderRadius.circular(t.radius.full),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
