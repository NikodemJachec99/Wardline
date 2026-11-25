import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import '../../map/presentation/map_data.dart';
import '../../map/presentation/map_geometry.dart';
import 'analytics_data.dart';

enum _Filter { all, admitted, inTreatment, ready, moved }

/// Ward monitor (tablet; WardMonitor artboard): occupancy, patients table,
/// recent movements, quick filters. Read-only, large type for a wall screen.
class WardMonitorScreen extends ConsumerStatefulWidget {
  const WardMonitorScreen({required this.departmentCode, super.key});

  final String departmentCode;

  @override
  ConsumerState<WardMonitorScreen> createState() => _WardMonitorScreenState();
}

class _WardMonitorScreenState extends ConsumerState<WardMonitorScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = ref.watch(hospitalProvider);
    final conn = ref.watch(connectivityProvider);
    final d = s.department(widget.departmentCode);
    if (d == null) {
      return Scaffold(
        backgroundColor: c.page,
        body: SafeArea(
          child: Column(
            children: [
              const WlLargeTitle(title: 'Ward monitor'),
              Expanded(
                child: WlEmptyState(
                  icon: WlIcons.monitor,
                  title: 'Department not found',
                  body: 'No department has the code ${widget.departmentCode}.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    final now = snapshotNow(s);
    final occ = occupancyOf(s, d);
    final patients = patientsIn(s, d.code);
    final today = transfersToday(s);
    final movedIds = {
      for (final e in today)
        if (e.to == d.code || e.from == d.code) e.patientId,
    };
    final counts = breakdownFor(s, d.code);
    final rows =
        patients.where((p) {
          return switch (_filter) {
            _Filter.all => true,
            _Filter.admitted => p.status == PatientStatus.admitted,
            _Filter.inTreatment => p.status == PatientStatus.inTreatment,
            _Filter.ready => p.status == PatientStatus.readyForDischarge,
            _Filter.moved => movedIds.contains(p.id),
          };
        }).toList()..sort((a, b) {
          final ra = a.status == PatientStatus.readyForDischarge ? 0 : 1;
          final rb = b.status == PatientStatus.readyForDischarge ? 0 : 1;
          if (ra != rb) return ra - rb;
          return b.statusSince.compareTo(a.statusSince);
        });
    final feed = _feed(s, d.code, now);
    final inToday = today.where((e) => e.to == d.code).length;
    final outToday = today.where((e) => e.from == d.code).length;
    final remote = s.lastRemoteEvent;

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 900;
            final pad = wide ? t.space.xl : t.space.gutter;
            final header = _Header(
              department: d,
              occupancy: occ,
              now: now,
              conn: conn.state,
              wide: wide,
            );
            final filters = WlFilterChips(
              padding: EdgeInsets.zero,
              chips: [
                for (final (f, label, n) in [
                  (_Filter.all, 'All', patients.length),
                  (
                    _Filter.admitted,
                    'Admitted',
                    counts[PatientStatus.admitted] ?? 0,
                  ),
                  (
                    _Filter.inTreatment,
                    'In Treatment',
                    counts[PatientStatus.inTreatment] ?? 0,
                  ),
                  (
                    _Filter.ready,
                    'Ready for Discharge',
                    counts[PatientStatus.readyForDischarge] ?? 0,
                  ),
                  (_Filter.moved, 'Moved today', movedIds.length),
                ])
                  WlFilterChipData(
                    label: label,
                    count: n,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
              ],
            );
            final table = _PatientsTable(
              rows: rows,
              total: patients.length,
              snapshot: s,
              wide: wide,
              remote: remote,
            );
            final movements = _Movements(
              items: feed,
              inToday: inToday,
              outToday: outToday,
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(
                pad,
                t.space.lg,
                pad,
                MediaQuery.paddingOf(context).bottom + t.space.xl,
              ),
              children: [
                if (Navigator.of(context).canPop())
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      icon: Icon(WlIcons.back, color: c.text),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                if (!conn.online) ...[
                  WlOfflineBanner(syncedAt: hm(conn.syncedAt)),
                  SizedBox(height: t.space.md),
                ],
                header,
                SizedBox(height: t.space.lg - t.space.xxs),
                filters,
                SizedBox(height: t.space.lg - t.space.xxs),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: t.space.lg - t.space.xxs,
                    children: [
                      Expanded(flex: 2, child: table),
                      Expanded(child: movements),
                    ],
                  )
                else ...[
                  table,
                  SizedBox(height: t.space.md),
                  movements,
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<_FeedItem> _feed(HospitalSnapshot s, String code, DateTime now) {
    final here = {for (final p in patientsIn(s, code)) p.id};
    String name(String id) => s.patient(id)?.fullName ?? 'Patient';
    String dept(String? c) => s.department(c ?? '')?.shortName ?? c ?? '';
    final out = <_FeedItem>[];
    for (final e in s.events) {
      if (!sameDay(e.at, now) || e.at.isAfter(now)) continue;
      switch (e) {
        case LocationEvent(:final from, :final to) when to == code:
          out.add(
            _FeedItem(
              _Tag.inbound,
              from == null
                  ? '${name(e.patientId)} · admitted'
                  : '${name(e.patientId)} ← ${dept(from)}',
              e,
            ),
          );
        case LocationEvent(:final from, :final to) when from == code:
          out.add(_FeedItem(_Tag.out, '${name(e.patientId)} → ${dept(to)}', e));
        case StatusEvent(:final to) when here.contains(e.patientId):
          out.add(
            _FeedItem(
              _Tag.status,
              '${name(e.patientId)} · ${WlTokens.of(context).colors.status(to).shortLabel}',
              e,
            ),
          );
        default:
          break;
      }
      if (out.length >= 8) break;
    }
    return out;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.department,
    required this.occupancy,
    required this.now,
    required this.conn,
    required this.wide,
  });

  final Department department;
  final DeptOccupancy occupancy;
  final DateTime now;
  final WlConnectionState conn;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final o = occupancy;
    final st = c.occupancy(o.percent);
    final high = st.level == OccupancyLevel.high;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${department.code} · ${floorName(department.floor)} · Ward monitor',
          style: t.typography.label.copyWith(color: c.textSecondary),
        ),
        Semantics(
          header: true,
          child: Text(
            department.name,
            style: t.typography.display.copyWith(
              fontSize: wide ? 38 : null,
              color: c.text,
            ),
          ),
        ),
      ],
    );
    final bar = Semantics(
      container: true,
      label: o.spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.xs,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: t.space.sm,
            children: [
              Text.rich(
                TextSpan(
                  text: '${o.occupied}',
                  children: [
                    TextSpan(
                      text: ' / ${o.beds} beds',
                      style: t.typography.title2.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                style: t.typography
                    .tabular(t.typography.display)
                    .copyWith(color: c.text),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: t.space.xs,
                children: [
                  if (high)
                    Icon(WlIcons.alert, size: 20, color: c.dangerPressed),
                  Text(
                    o.full
                        ? '${o.percent}% · Full'
                        : '${o.percent}% · ${o.free} free',
                    style: t.typography
                        .tabular(t.typography.title2)
                        .copyWith(color: high ? c.dangerPressed : c.text),
                  ),
                ],
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(t.radius.full),
            child: SizedBox(
              height: t.space.md - 2,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: c.subtle)),
                  FractionallySizedBox(
                    widthFactor: (o.percent / 100).clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: st.fill),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final clock = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      spacing: t.space.xs - 2,
      children: [
        Text(
          hm(now),
          style: t.typography
              .tabular(t.typography.display)
              .copyWith(
                fontSize: wide ? 38 : null,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
        ),
        WlConnectionIndicator(state: conn),
      ],
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.md,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              WlConnectionIndicator(state: conn),
            ],
          ),
          bar,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: t.space.xl,
      children: [
        Expanded(flex: 10, child: title),
        Expanded(flex: 12, child: bar),
        clock,
      ],
    );
  }
}

class _PatientsTable extends StatelessWidget {
  const _PatientsTable({
    required this.rows,
    required this.total,
    required this.snapshot,
    required this.wide,
    required this.remote,
  });

  final List<Patient> rows;
  final int total;
  final HospitalSnapshot snapshot;
  final bool wide;
  final HistoryEvent? remote;

  String _lastMove(Patient p) {
    final now = snapshotNow(snapshot);
    for (final e in snapshot.events.whereType<LocationEvent>()) {
      if (e.patientId != p.id || e.to != p.location) continue;
      final from = e.from == null
          ? 'Admitted'
          : '← ${snapshot.department(e.from!)?.shortName ?? e.from}';
      final when = sameDay(e.at, now) ? hm(e.at) : _dayMonth(e.at);
      return '$from · $when';
    }
    final since = sameDay(p.locationSince, now)
        ? hm(p.locationSince)
        : _dayMonth(p.locationSince);
    return 'Here since $since';
  }

  static String _dayMonth(DateTime t) {
    const m = [
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
    return '${t.day} ${m[t.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final head = t.typography.overline.copyWith(color: c.textSecondary);
    final big = t.typography.title3.copyWith(fontWeight: FontWeight.w400);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final tableLayout = wide && !large;

    Widget row(Patient p, int i) {
      final name = Text.rich(
        TextSpan(
          text: p.fullName,
          children: [
            TextSpan(
              text: ' ${p.age}',
              style: t.typography.tabular(big).copyWith(color: c.textSecondary),
            ),
          ],
        ),
        style: big.copyWith(color: c.text, fontWeight: FontWeight.w600),
      );
      final since = Text(
        hm(p.statusSince),
        style: t.typography.tabular(big).copyWith(color: c.text),
      );
      final move = Text(
        _lastMove(p),
        style: t.typography
            .tabular(t.typography.body)
            .copyWith(color: c.textSecondary),
      );
      final live = remote?.patientId == p.id;
      final content = Container(
        constraints: BoxConstraints(minHeight: t.space.action),
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.xs,
        ),
        decoration: BoxDecoration(
          border: i == 0 ? null : Border(top: BorderSide(color: c.border)),
        ),
        child: tableLayout
            ? Row(
                spacing: t.space.md,
                children: [
                  Expanded(flex: 34, child: name),
                  Expanded(
                    flex: 24,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: WlStatusChip(p.status, short: true),
                    ),
                  ),
                  Expanded(flex: 12, child: since),
                  Expanded(flex: 30, child: move),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: t.space.xxs,
                children: [
                  name,
                  Wrap(
                    spacing: t.space.sm,
                    runSpacing: t.space.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [WlStatusChip(p.status, short: true), since],
                  ),
                  move,
                ],
              ),
      );
      return Semantics(
        key: ValueKey(p.id),
        label:
            '${p.fullName}, ${p.age}, ${c.status(p.status).label} since '
            '${hm(p.statusSince)}, last move ${_lastMove(p)}',
        excludeSemantics: true,
        child: live
            ? WlLiveHighlight(pulseKey: remote!.id, child: content)
            : content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: t.radius.cardBr,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.only(top: t.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tableLayout)
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.md,
                0,
                t.space.md,
                t.space.sm - 2,
              ),
              child: ExcludeSemantics(
                child: Row(
                  spacing: t.space.md,
                  children: [
                    Expanded(flex: 34, child: Text('PATIENT', style: head)),
                    Expanded(flex: 24, child: Text('STATUS', style: head)),
                    Expanded(flex: 12, child: Text('SINCE', style: head)),
                    Expanded(flex: 30, child: Text('LAST MOVE', style: head)),
                  ],
                ),
              ),
            ),
          if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.all(t.space.md),
              child: Text(
                'No patients match this filter',
                style: t.typography.body.copyWith(color: c.textSecondary),
              ),
            )
          else
            for (final (i, p) in rows.indexed)
              Container(
                decoration: BoxDecoration(
                  border: i == 0 && tableLayout
                      ? Border(top: BorderSide(color: c.border))
                      : null,
                ),
                child: row(p, i),
              ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: t.space.md,
              vertical: t.space.sm,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Text(
              'Showing ${rows.length} of $total · Ready first',
              style: t.typography
                  .tabular(t.typography.callout)
                  .copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tag { inbound, out, status }

class _FeedItem {
  const _FeedItem(this.tag, this.title, this.event);

  final _Tag tag;
  final String title;
  final HistoryEvent event;
}

class _Movements extends StatelessWidget {
  const _Movements({
    required this.items,
    required this.inToday,
    required this.outToday,
  });

  final List<_FeedItem> items;
  final int inToday;
  final int outToday;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final treat = c.status(PatientStatus.inTreatment);
    final dis = c.status(PatientStatus.discharged);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          t.space.lg - t.space.xxs,
          t.space.md + 2,
          t.space.lg - t.space.xxs,
          t.space.xs,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: t.radius.cardBr,
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: t.space.sm,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Recent movements',
                    style: t.typography.title3.copyWith(
                      fontSize: 20,
                      color: c.text,
                    ),
                  ),
                ),
                Text(
                  'In $inToday · Out $outToday',
                  style: t.typography
                      .tabular(t.typography.subhead)
                      .copyWith(color: c.textSecondary),
                ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.space.md),
                child: Text(
                  'No movements today',
                  style: t.typography.body.copyWith(color: c.textSecondary),
                ),
              ),
            for (final (i, it) in items.indexed)
              Container(
                padding: EdgeInsets.symmetric(vertical: t.space.md - 2),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: t.space.md - 2,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: t.space.xxs / 2),
                      padding: EdgeInsets.symmetric(
                        horizontal: t.space.xs,
                        vertical: t.space.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: switch (it.tag) {
                          _Tag.inbound => c.primarySoft,
                          _Tag.out => dis.bg,
                          _Tag.status => treat.bg,
                        },
                        borderRadius: BorderRadius.circular(t.radius.chip - 2),
                      ),
                      child: Text(
                        switch (it.tag) {
                          _Tag.inbound => 'IN',
                          _Tag.out => 'OUT',
                          _Tag.status => 'STATUS',
                        },
                        style: t.typography.overline.copyWith(
                          fontWeight: FontWeight.w700,
                          color: switch (it.tag) {
                            _Tag.inbound => c.primaryInk,
                            _Tag.out => dis.fg,
                            _Tag.status => treat.fg,
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.title,
                            style: t.typography.title3.copyWith(
                              fontSize: 17,
                              color: c.text,
                            ),
                          ),
                          Text(
                            '${hm(it.event.at)} · ${shortStaffName(it.event.byName)}',
                            style: t.typography
                                .tabular(t.typography.callout)
                                .copyWith(
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
