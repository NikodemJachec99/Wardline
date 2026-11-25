// Sections of the patient profile (artboards `Profile`, `ProfileDoctor`,
// `ProfileOffline`): titled cards, medical info rows, status stepper and the
// history timeline built from location_history ∪ status_history.

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import 'patient_list_model.dart';

/// "HH:MM:SS" for "Server confirmed".
String hms(DateTime t) => '${hm(t)}:${t.second.toString().padLeft(2, '0')}';

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Today, 08:12 · 13 Nov 2026" (or without "Today, ").
String admittedLabel(DateTime at, DateTime now) {
  final today =
      at.year == now.year && at.month == now.month && at.day == now.day;
  return '${today ? 'Today, ' : ''}${hm(at)} · '
      '${at.day} ${_months[at.month - 1]} ${at.year}';
}

/// Overline title + white bordered card (artboard sections).
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
    super.key,
  });

  final String title;
  final String? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space.xxs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title.toUpperCase(),
                    style: t.typography.overline.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: t.typography
                      .tabular(t.typography.caption)
                      .copyWith(color: c.textSecondary),
                ),
            ],
          ),
        ),
        SizedBox(height: t.space.xs),
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: t.radius.cardBr,
            border: Border.all(color: c.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Label / value rows; stacked above text scale 1.3.
class ProfileInfoRows extends StatelessWidget {
  const ProfileInfoRows({required this.rows, super.key});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final labelStyle = t.typography.subhead.copyWith(color: c.textSecondary);
    final valueStyle = t.typography
        .tabular(t.typography.callout)
        .copyWith(color: c.text, fontWeight: FontWeight.w600);
    return Column(
      children: [
        for (final (i, (k, v)) in rows.indexed)
          Container(
            constraints: BoxConstraints(minHeight: t.space.touchMin),
            padding: EdgeInsets.symmetric(
              horizontal: t.space.md,
              vertical: t.space.sm,
            ),
            decoration: BoxDecoration(
              border: i == rows.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: c.border)),
            ),
            child: MergeSemantics(
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k, style: labelStyle),
                        SizedBox(height: t.space.xxs),
                        Text(v, style: valueStyle),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k, style: labelStyle),
                        SizedBox(width: t.space.sm),
                        Expanded(
                          child: Text(
                            v,
                            textAlign: TextAlign.end,
                            style: valueStyle,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}

/// Admitted → In Treatment → Ready → Discharged, reached steps in their
/// status colour with the time they were reached. Vertical above 1.3.
class StatusStepper extends StatelessWidget {
  const StatusStepper({
    required this.current,
    required this.reachedAt,
    super.key,
  });

  final PatientStatus current;

  /// When each status was (last) reached.
  final Map<PatientStatus, DateTime> reachedAt;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    const steps = PatientStatus.values;
    final currentIndex = steps.indexOf(current);

    Widget step(PatientStatus s) {
      final i = steps.indexOf(s);
      final reached = i <= currentIndex;
      final style = c.status(s);
      final at = reached ? reachedAt[s] : null;
      final label = s == PatientStatus.readyForDischarge
          ? style.shortLabel
          : style.label;
      final bar = AnimatedContainer(
        duration: WlMotion.duration(context, t.motion.base),
        height: 4,
        decoration: BoxDecoration(
          color: reached ? style.base : c.border,
          borderRadius: BorderRadius.circular(t.radius.full),
        ),
      );
      final texts = [
        Text(
          label,
          style: t.typography.overline.copyWith(
            letterSpacing: 0,
            color: reached ? style.fg : c.textSecondary,
            fontWeight: reached ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        if (at != null)
          Text(
            hm(at),
            style: t.typography
                .tabular(t.typography.overline)
                .copyWith(
                  letterSpacing: 0,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
          ),
      ];
      return Semantics(
        container: true,
        label:
            '${style.label}${i == currentIndex
                ? ', current step'
                : reached
                ? ', done'
                : ', not reached'}${at == null ? '' : ', at ${hm(at)}'}',
        excludeSemantics: true,
        child: stacked
            ? Padding(
                padding: EdgeInsets.only(bottom: t.space.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: t.space.sm),
                      child: SizedBox(width: t.space.lg, child: bar),
                    ),
                    SizedBox(width: t.space.sm),
                    Expanded(
                      child: Wrap(spacing: t.space.xs, children: texts),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar,
                  SizedBox(height: t.space.xs - 2),
                  ...texts,
                ],
              ),
      );
    }

    return Semantics(
      label: 'Status progress',
      container: true,
      child: stacked
          ? Column(children: [for (final s in steps) step(s)])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, s) in steps.indexed) ...[
                  if (i > 0) SizedBox(width: t.space.xxs),
                  Expanded(child: step(s)),
                ],
              ],
            ),
    );
  }
}

/// Builds timeline rows (newest first) for one patient.
List<WlTimelineItem> buildTimeline({
  required HospitalSnapshot snapshot,
  required Patient patient,
  required List<HistoryEvent> history,
  required Set<String> highlight,
}) {
  String dept(String code) => snapshot.department(code)?.name ?? code;
  String short(String code) => snapshot.department(code)?.shortName ?? code;
  String deptFloor(String code) {
    final d = snapshot.department(code);
    if (d == null) return code;
    return '${d.shortName} · ${d.floor == 0 ? 'Ground' : 'Floor ${d.floor}'}';
  }

  String identified(String? how) => switch (how) {
    'NFC' => 'NFC wristband',
    'QR' => 'QR code',
    null => 'Not recorded',
    _ => how,
  };

  LocationEvent? olderLocation(int index) {
    for (var j = index + 1; j < history.length; j++) {
      final e = history[j];
      if (e is LocationEvent) return e;
    }
    return null;
  }

  final items = <WlTimelineItem>[];
  for (final (i, e) in history.indexed) {
    final isLast = i == history.length - 1;
    final key = highlight.contains(e.id) ? e.id : null;
    switch (e) {
      case LocationEvent(isAdmission: true):
        items.add(
          WlTimelineItem(
            key: ValueKey(e.id),
            kind: WlTimelineKind.admission,
            title: 'Admitted',
            time: hm(e.at),
            line: dept(e.to),
            staffName: e.byName,
            staffRole: e.byRole,
            isLast: isLast,
            highlightKey: key,
            details: [
              ('To', deptFloor(e.to)),
              ('Wristband issued', patient.code),
              ('Initial status', WlStatusLabels.of(PatientStatus.admitted)),
              ('Server confirmed', hms(e.at)),
            ],
          ),
        );
      case LocationEvent(:final from?, :final to):
        final prev = olderLocation(i);
        items.add(
          WlTimelineItem(
            key: ValueKey(e.id),
            kind: WlTimelineKind.transfer,
            title: 'Transferred',
            time: hm(e.at),
            line: '${short(from)} → ${short(to)}',
            staffName: e.byName,
            staffRole: e.byRole,
            isLast: isLast,
            highlightKey: key,
            details: [
              ('From', deptFloor(from)),
              ('To', deptFloor(to)),
              ('Identified by', identified(e.identifiedBy)),
              ('Server confirmed', hms(e.at)),
              if (prev != null)
                ('Time in previous dept', duration(e.at.difference(prev.at))),
            ],
          ),
        );
      case LocationEvent():
        break;
      case StatusEvent(:final from, :final to, :final reason):
        final where = olderLocation(i);
        final fromLabel = from == null ? null : WlStatusLabels.of(from);
        items.add(
          WlTimelineItem(
            key: ValueKey(e.id),
            kind: WlTimelineKind.status,
            statusForNode: to,
            title: 'Status changed',
            time: hm(e.at),
            line: fromLabel == null
                ? WlStatusLabels.of(to)
                : '$fromLabel → ${WlStatusLabels.of(to)}',
            staffName: e.byName,
            staffRole: e.byRole,
            isLast: isLast,
            highlightKey: key,
            details: [
              if (fromLabel != null) ('From', fromLabel),
              ('To', WlStatusLabels.of(to)),
              if (where != null) ('Location at the time', dept(where.to)),
              if (reason != null && reason.trim().isNotEmpty)
                ('Reason', reason),
              ('Server confirmed', hms(e.at)),
            ],
          ),
        );
    }
  }
  return items;
}

/// Floor label used in the location detail ("Ground floor", "Floor 1").
String profileFloor(Department? d) => d == null ? '' : floorLabel(d.floor);
