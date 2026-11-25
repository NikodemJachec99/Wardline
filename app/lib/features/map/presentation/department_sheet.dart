import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';
import 'map_data.dart';
import 'map_geometry.dart';

/// Department tapped (MapLive / MapStates "Department tapped"): everything
/// about the ward in a floating sheet. Read-only; live counts.
class DepartmentSheet extends ConsumerStatefulWidget {
  const DepartmentSheet({required this.code, super.key});

  final String code;

  @override
  ConsumerState<DepartmentSheet> createState() => _DepartmentSheetState();
}

class _DepartmentSheetState extends ConsumerState<DepartmentSheet> {
  static const int _preview = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = ref.watch(hospitalProvider);
    final d = s.department(widget.code);
    if (d == null) {
      return const WlEmptyState(
        icon: WlIcons.building,
        title: 'Department not found',
      );
    }
    final occ = occupancyOf(s, d);
    final o = c.occupancy(occ.percent);
    final stats = dayStats(s, d.code);
    final patients = patientsIn(s, d.code);
    final shown = _all ? patients : patients.take(_preview).toList();
    final small = t.typography.tabular(
      t.typography.subhead.copyWith(fontSize: 13, height: 18 / 13),
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: d.name,
      explicitChildNodes: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: t.space.sm,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.code} · ${floorName(d.floor)}',
                        style: t.typography.caption.copyWith(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Wrap(
                        spacing: t.space.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              d.name,
                              style: t.typography.title2.copyWith(
                                fontSize: 21,
                                color: c.text,
                              ),
                            ),
                          ),
                          if (occ.flag != null) _FlagBadge(occ.flag!),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  style: IconButton.styleFrom(backgroundColor: c.subtle),
                  icon: Icon(WlIcons.close, color: c.text, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            Semantics(
              container: true,
              label: occ.spoken,
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: t.space.xs - 2,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: t.space.xs,
                    children: [
                      Text(
                        '${occ.occupied} of ${occ.beds} beds · ${occ.percent}%',
                        style: small.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        occ.free == 0 ? 'Full' : '${occ.free} free',
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
                            widthFactor: (occ.percent / 100).clamp(0.0, 1.0),
                            heightFactor: 1,
                            child: ColoredBox(color: o.fill),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _StatusDots(breakdown: breakdownFor(s, d.code)),
            Row(
              spacing: t.space.xs,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Stat(
                    '${stats.inToday} / ${stats.outToday}',
                    'In / out today',
                  ),
                ),
                Expanded(
                  child: _Stat('${stats.dischargesToday}', 'Discharges today'),
                ),
                Expanded(
                  child: _Stat(
                    stats.averageStay == null
                        ? '–'
                        : stayLabel(stats.averageStay!),
                    'Avg. stay',
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: t.space.sm - 2,
              children: [
                Text(
                  'Last transfer',
                  style: small.copyWith(color: c.textSecondary),
                ),
                Text(
                  stats.lastTransfer ?? 'None today',
                  style: small.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (patients.isEmpty)
              Container(
                padding: EdgeInsets.all(t.space.sm),
                decoration: BoxDecoration(
                  borderRadius: t.radius.inputBr,
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  'No patients here',
                  style: t.typography.subhead.copyWith(color: c.textSecondary),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: t.radius.inputBr,
                  border: Border.all(color: c.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, p) in shown.indexed)
                      _PatientRow(patient: p, first: i == 0),
                    if (patients.length > _preview)
                      _MoreRow(
                        text: _all
                            ? 'Show fewer'
                            : '+ ${patients.length - _preview} more patients here',
                        onTap: () => setState(() => _all = !_all),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: t.space.sm,
                          vertical: t.space.xs,
                        ),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: c.border)),
                        ),
                        child: Text(
                          'All patients shown',
                          style: t.typography.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            WlButton(
              label: 'Department history',
              variant: WlButtonVariant.secondary,
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go(Routes.departmentHistory(d.code));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge(this.word);

  final String word;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xs - 1,
        vertical: t.space.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: c.occupancy(100).tint,
        borderRadius: BorderRadius.circular(t.radius.chip - 2),
      ),
      child: Text(
        word,
        style: t.typography.overline.copyWith(
          letterSpacing: 0,
          color: c.dangerPressed,
        ),
      ),
    );
  }
}

class _StatusDots extends StatelessWidget {
  const _StatusDots({required this.breakdown});

  final Map<PatientStatus, int> breakdown;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final items = [
      for (final s in PatientStatus.values)
        if ((breakdown[s] ?? 0) > 0) (s, breakdown[s]!),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: t.space.md - 2,
      runSpacing: t.space.xxs,
      children: [
        for (final (s, n) in items)
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
                style: t.typography
                    .tabular(t.typography.caption)
                    .copyWith(color: c.textSecondary),
              ),
            ],
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm - 2,
        vertical: t.space.xs,
      ),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: t.radius.inputBr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: t.typography
                .tabular(t.typography.title3)
                .copyWith(fontSize: 17, color: c.text),
          ),
          Text(
            label,
            style: t.typography.overline.copyWith(
              letterSpacing: 0,
              fontWeight: FontWeight.w400,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.first});

  final Patient patient;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final st = c.status(patient.status);
    return Semantics(
      button: true,
      label: '${patient.fullName}, ${st.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push(Routes.patientRecord(patient.id));
        },
        child: Container(
          constraints: BoxConstraints(minHeight: t.space.touchMin),
          padding: EdgeInsets.symmetric(horizontal: t.space.sm),
          decoration: BoxDecoration(
            border: first ? null : Border(top: BorderSide(color: c.border)),
          ),
          child: Row(
            spacing: t.space.sm - 2,
            children: [
              Container(
                width: t.space.xxs,
                height: t.space.md + t.space.xxs,
                decoration: BoxDecoration(
                  color: st.base,
                  borderRadius: BorderRadius.circular(t.space.xxs / 2),
                ),
              ),
              Expanded(
                child: Text(
                  patient.fullName,
                  style: t.typography.subhead.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                st.shortLabel,
                style: t.typography.caption.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: t.space.touchMin),
          padding: EdgeInsets.symmetric(horizontal: t.space.sm),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Text(
            text,
            style: t.typography.caption.copyWith(color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}
