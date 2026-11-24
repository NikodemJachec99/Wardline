import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';

/// Department occupancy: code badge, name, "29/32 beds", track, % label.
/// Colour is never alone: the % is always shown, and high wards also say
/// [flag] ("Full" / "Bottleneck") in words.
class WlDeptOccupancyBar extends StatelessWidget {
  const WlDeptOccupancyBar({
    required this.code,
    required this.name,
    required this.occupied,
    required this.capacity,
    this.flag,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String code;
  final String name;
  final int occupied;
  final int capacity;
  final String? flag;
  final bool selected;
  final VoidCallback? onTap;

  int get percent => capacity == 0 ? 0 : (occupied * 100 / capacity).round();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final o = c.occupancy(percent);
    final spoken =
        '$name, $occupied of $capacity beds, $percent percent, '
        '${(flag ?? o.word).toLowerCase()}';

    return Semantics(
      label: spoken,
      button: onTap != null,
      selected: selected,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radius.inputBr,
        child: Container(
          constraints: BoxConstraints(minHeight: t.space.touchMin),
          padding: EdgeInsets.symmetric(
            horizontal: t.space.xs,
            vertical: t.space.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? c.subtle : null,
            borderRadius: t.radius.inputBr,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space.xxs + 2,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: c.subtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      code,
                      style: t.typography.caption.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: t.space.xs),
                  Expanded(
                    child: Text(
                      name,
                      style: t.typography.callout.copyWith(color: c.text),
                    ),
                  ),
                  Text(
                    '$occupied/$capacity beds',
                    style: t.typography
                        .tabular(t.typography.caption)
                        .copyWith(color: c.textSecondary),
                  ),
                ],
              ),
              SizedBox(height: t.space.xs),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(t.radius.full),
                      child: SizedBox(
                        height: 8,
                        child: Stack(
                          children: [
                            Positioned.fill(child: ColoredBox(color: c.subtle)),
                            FractionallySizedBox(
                              widthFactor: (percent / 100).clamp(0.0, 1.0),
                              child: ColoredBox(color: o.fill),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: t.space.xs),
                  Text(
                    flag == null ? '$percent%' : '$percent% · $flag',
                    style: t.typography
                        .tabular(t.typography.caption)
                        .copyWith(color: c.text, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
