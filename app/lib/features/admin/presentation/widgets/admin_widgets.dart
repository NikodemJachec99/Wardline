import 'package:flutter/material.dart';

import '../../../../core/theme/wl_tokens.dart';
import '../../../../core/widgets/wl/wl.dart';

/// Grey info box saying what is simulated (no real NFC write, no printer,
/// no server). Admin and demo screens only.
class SimulationNote extends StatelessWidget {
  const SimulationNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm + 2,
        vertical: t.space.sm,
      ),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: t.radius.inputBr,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(WlIcons.info, size: 18, color: c.textSecondary),
          SizedBox(width: t.space.sm - 2),
          Expanded(
            child: Text(
              text,
              style: t.typography.subhead.copyWith(
                color: c.status(PatientStatus.discharged).fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Role label chip in the role colours ("Nurse", "Doctor", "Admin",
/// "Current").
class RoleChip extends StatelessWidget {
  const RoleChip({required this.role, this.text, super.key});

  final UserRole role;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final r = t.colors.role(role);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.xs, vertical: 3),
      decoration: BoxDecoration(
        color: r.bg,
        borderRadius: BorderRadius.circular(t.radius.chip - 2),
      ),
      child: Text(
        text ?? r.label,
        style: t.typography.caption.copyWith(
          color: r.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Overline group title ("PATIENTS · 3 SELECTED").
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: t.typography.overline.copyWith(color: t.colors.textSecondary),
      ),
    );
  }
}

/// Three-step progress (Program wristband: 1 Patient, 2 Write, 3 Verify).
class StepBar extends StatelessWidget {
  const StepBar({required this.labels, required this.current, super.key});

  final List<String> labels;

  /// 0-based. Steps before it are done; `current == labels.length` = all
  /// done.
  final int current;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      label:
          'Step ${(current + 1).clamp(1, labels.length)} of ${labels.length}'
          ', ${labels[current.clamp(0, labels.length - 1)]}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, l) in labels.indexed) ...[
            if (i > 0) SizedBox(width: t.space.xxs + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < current
                          ? c.primaryInk
                          : i == current
                          ? c.primary
                          : c.border,
                      borderRadius: BorderRadius.circular(t.radius.chip / 4),
                    ),
                  ),
                  SizedBox(height: t.space.xxs + 2),
                  Text(
                    '${i + 1} $l',
                    style: t.typography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: i < current
                          ? c.primaryInk
                          : i == current
                          ? c.text
                          : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
