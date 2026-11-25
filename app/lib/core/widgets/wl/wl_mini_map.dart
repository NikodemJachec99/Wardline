import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

/// One floor, departments tinted by occupancy, the selected department
/// ringed, a patient pin. Tappable → full map focused on that floor.
///
/// STUB: API is final, rendering is implemented with the map (flow 5).
class WlMiniMap extends StatelessWidget {
  const WlMiniMap({
    required this.floor,
    this.highlightDepartment,
    this.patientInitials,
    this.onTap,
    super.key,
  });

  final int floor;
  final String? highlightDepartment;
  final String? patientInitials;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Semantics(
      button: onTap != null,
      label:
          'Map of floor $floor${highlightDepartment == null ? '' : ', $highlightDepartment highlighted'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radius.cardBr,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: t.colors.subtle,
            borderRadius: t.radius.cardBr,
            border: Border.all(color: t.colors.border),
          ),
          alignment: Alignment.center,
          child: Icon(WlIcons.map, color: t.colors.textSecondary),
        ),
      ),
    );
  }
}
