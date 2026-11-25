import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_dept_occupancy_bar.dart';

/// Department summary: code · floor, name, occupancy bar + "% · N free",
/// status breakdown dots.
///
/// STUB: API is final, the full card is implemented with the map (flow 5).
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
  final String? flag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: t.colors.surface,
        borderRadius: t.radius.cardBr,
        border: Border.all(color: t.colors.border),
      ),
      child: WlDeptOccupancyBar(
        code: code,
        name: name,
        occupied: occupied,
        capacity: beds,
        flag: flag,
        onTap: onTap,
      ),
    );
  }
}
