import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

@immutable
class WlFilterChipData {
  const WlFilterChipData({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.count,
    this.dropdown = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final int? count;

  /// "Department ▾" style chip that opens a sheet.
  final bool dropdown;
}

/// Horizontal chips, 36 visual / 48 hit.
class WlFilterChips extends StatelessWidget {
  const WlFilterChips({required this.chips, this.padding, super.key});

  final List<WlFilterChipData> chips;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ?? EdgeInsets.symmetric(horizontal: t.space.gutter),
      child: Row(
        children: [
          for (final (i, chip) in chips.indexed) ...[
            if (i > 0) SizedBox(width: t.space.xs),
            _Chip(chip),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.data);

  final WlFilterChipData data;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final on = data.selected;
    final fg = on ? c.primaryInk : c.text;
    final style = t.typography.subhead.copyWith(
      color: fg,
      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
    );
    return Semantics(
      button: true,
      selected: on,
      label: data.count == null ? data.label : '${data.label}, ${data.count}',
      excludeSemantics: true,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: t.radius.chipBr,
        child: SizedBox(
          height: t.space.touchMin,
          child: Center(
            child: AnimatedContainer(
              duration: WlMotion.duration(context, t.motion.fast),
              height: 36,
              padding: EdgeInsets.symmetric(horizontal: t.space.sm),
              decoration: BoxDecoration(
                color: on ? c.primarySoft : c.surface,
                borderRadius: t.radius.chipBr,
                border: Border.all(color: on ? c.primary : c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (on) ...[
                    Icon(WlIcons.check, size: 16, color: fg),
                    SizedBox(width: t.space.xxs),
                  ],
                  Text(data.label, style: style),
                  if (data.count != null) ...[
                    SizedBox(width: t.space.xxs + 2),
                    Text(
                      '${data.count}',
                      style: t.typography
                          .tabular(style)
                          .copyWith(color: on ? c.primaryInk : c.textSecondary),
                    ),
                  ],
                  if (data.dropdown) ...[
                    SizedBox(width: t.space.xxs),
                    Icon(WlIcons.chevronDown, size: 16, color: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
