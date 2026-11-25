import 'package:flutter/material.dart';

import '../../../core/theme/wl_tokens.dart';

/// Segmented control from the MapLive / Analytics artboards: subtle track,
/// the selected segment on a white raised pill. Every segment is a 48dp
/// button with a selected state for screen readers.
class MapSegmented<T> extends StatelessWidget {
  const MapSegmented({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.semanticsLabel,
    this.expand = true,
    super.key,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// "Floor", "View".
  final String semanticsLabel;

  /// Segments share the width equally; otherwise they hug their labels.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Container(
        padding: EdgeInsets.all(t.space.xxs - 1),
        decoration: BoxDecoration(
          color: c.subtle,
          borderRadius: BorderRadius.circular(t.radius.chip + 2),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          spacing: 2,
          children: [
            for (final (v, label) in options)
              if (expand)
                Expanded(child: _segment(context, v, label))
              else
                _segment(context, v, label),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, T v, String label) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final on = v == value;
    return Semantics(
      button: true,
      selected: on,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: WlMotion.duration(context, t.motion.fast),
          curve: t.motion.out,
          constraints: BoxConstraints(minHeight: t.space.touchMin - 6),
          padding: EdgeInsets.symmetric(horizontal: t.space.xs + 2),
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
