import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';

/// Department summary (components.md, Dashboard artboard): code badge ·
/// floor, name, "% · Full" + "N free of M", occupancy bar, status breakdown
/// dots. Colour is never alone: the % and the flag word are always printed.
class WlDepartmentCard extends StatelessWidget {
  const WlDepartmentCard({
    required this.code,
    required this.name,
    required this.floor,
    required this.occupied,
    required this.beds,
    this.breakdown = const {},
    this.flag,
    this.onTap,
    super.key,
  });

  final String code;
  final String name;
  final int floor;
  final int occupied;
  final int beds;
  final Map<PatientStatus, int> breakdown;

  /// "Bottleneck" etc. "Full" is added automatically when no bed is free.
  final String? flag;
  final VoidCallback? onTap;

  int get percent => beds == 0 ? 0 : (occupied * 100 / beds).round();
  int get free => (beds - occupied).clamp(0, beds);

  static String floorLabel(int floor) => floor == 0 ? 'Ground' : 'Floor $floor';

  String? get _word => free == 0 ? 'Full' : flag;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final o = c.occupancy(percent);
    final counts = [
      for (final s in PatientStatus.values)
        if ((breakdown[s] ?? 0) > 0) (s, breakdown[s]!),
    ];
    final spoken = [
      name,
      floorLabel(floor),
      '$occupied of $beds beds',
      '$percent percent',
      if (_word != null) _word!.toLowerCase(),
      '$free free',
      for (final (s, n) in counts) '${c.status(s).label} $n',
    ].join(', ');
    final small = t.typography.tabular(
      t.typography.subhead.copyWith(fontSize: 13, height: 18 / 13),
    );

    final body = Container(
      padding: EdgeInsets.all(t.space.lg - t.space.xxs),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: t.radius.cardBr,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.sm,
        children: [
          Row(
            spacing: t.space.xs,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: t.space.xs,
                  vertical: t.space.xxs,
                ),
                decoration: BoxDecoration(
                  color: c.subtle,
                  borderRadius: BorderRadius.circular(t.radius.chip - 2),
                ),
                child: Text(
                  code,
                  style: t.typography.caption.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  floorLabel(floor),
                  style: small.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          Text(name, style: t.typography.title3.copyWith(color: c.text)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: t.space.xs - 2,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: t.space.xs,
                children: [
                  Text(
                    _word == null ? '$percent%' : '$percent% · $_word',
                    style: small.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$free free of $beds',
                    style: small.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(t.radius.full),
                child: SizedBox(
                  height: t.space.xs,
                  child: Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: c.subtle)),
                      FractionallySizedBox(
                        widthFactor: (percent / 100).clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: ColoredBox(color: o.fill),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (counts.isNotEmpty)
            Container(
              padding: EdgeInsets.only(top: t.space.sm - 2),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Wrap(
                spacing: t.space.md - 2,
                runSpacing: t.space.xxs,
                children: [
                  for (final (s, n) in counts)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: t.space.xs - 2,
                      children: [
                        Container(
                          width: t.space.xs,
                          height: t.space.xs,
                          decoration: BoxDecoration(
                            color: c.status(s).base,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            text: '${c.status(s).label} ',
                            children: [
                              TextSpan(
                                text: '$n',
                                style: TextStyle(
                                  color: c.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          style: small.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: spoken,
      excludeSemantics: true,
      child: onTap == null
          ? body
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: t.radius.cardBr,
                child: body,
              ),
            ),
    );
  }
}
