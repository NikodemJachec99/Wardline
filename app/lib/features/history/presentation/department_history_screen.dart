import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import 'history_data.dart';
import 'history_widgets.dart';

/// `/history/dept/:code`: one ward's arrivals, departures and status
/// changes today (HistoryFlow artboard, "Department history" and "Empty
/// filter").
class DepartmentHistoryScreen extends ConsumerStatefulWidget {
  const DepartmentHistoryScreen({required this.departmentCode, super.key});

  final String departmentCode;

  @override
  ConsumerState<DepartmentHistoryScreen> createState() =>
      _DepartmentHistoryScreenState();
}

class _DepartmentHistoryScreenState
    extends ConsumerState<DepartmentHistoryScreen> {
  DeptSegment _segment = DeptSegment.all;
  String? _liveId;

  @override
  Widget build(BuildContext context) {
    ref.listen(hospitalProvider.select((s) => s.lastRemoteEvent), (_, next) {
      if (next != null) setState(() => _liveId = next.id);
    });
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = ref.watch(hospitalProvider);
    final now = ref.watch(historyNowProvider)();
    final code = widget.departmentCode.toUpperCase();
    final dept = s.department(code);

    if (dept == null) {
      return Scaffold(
        backgroundColor: c.page,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WlLargeTitle(title: 'History'),
              WlEmptyState(
                icon: WlIcons.building,
                title: 'Department not found',
                body: "There's no department with the code $code.",
              ),
            ],
          ),
        ),
      );
    }

    final day = departmentDay(s, code, now);
    final events = departmentEvents(s, code, now, segment: _segment);

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: WlLargeTitle(
                title: dept.name,
                subtitle: '${dept.code} · ${floorLabel(dept.floor)}',
              ),
            ),
            const SliverToBoxAdapter(child: HistoryConnectionBanner()),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
                child: _StatTiles(day: day, deptName: dept.name),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.gutter,
                  t.space.sm,
                  t.space.gutter,
                  0,
                ),
                child: HistorySegmented<DeptSegment>(
                  selected: _segment,
                  onChanged: (v) => setState(() => _segment = v),
                  segments: const [
                    (DeptSegment.all, 'All'),
                    (DeptSegment.arrivals, 'In'),
                    (DeptSegment.departures, 'Out'),
                    (DeptSegment.status, 'Status'),
                  ],
                ),
              ),
            ),
            if (events.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyDept(
                  title: _emptyTitle(dept.shortName),
                  body: _emptyBody(day, now),
                  onShowAll: _segment == DeptSegment.all
                      ? null
                      : () => setState(() => _segment = DeptSegment.all),
                ),
              )
            else ...[
              const SliverToBoxAdapter(child: HistoryGroupLabel('Today')),
              HistoryBox(
                sliver: SliverList.separated(
                  itemCount: events.length,
                  separatorBuilder: (context, _) => const HistoryDivider(),
                  itemBuilder: (context, i) => _DeptRow(
                    key: ValueKey(events[i].id),
                    snapshot: s,
                    code: code,
                    event: events[i],
                    live: events[i].id == _liveId,
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(
                height: t.space.lg + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// copy.md `history.empty`: "No transfers {direction} {department} today".
  String _emptyTitle(String name) => switch (_segment) {
    DeptSegment.all => 'No activity in $name today',
    DeptSegment.arrivals => 'No transfers into $name today',
    DeptSegment.departures => 'No transfers out of $name today',
    DeptSegment.status => 'No status changes in $name today',
  };

  String _emptyBody(DepartmentDay day, DateTime now) {
    final there = day.occupied == 1
        ? '1 patient is there now.'
        : '${day.occupied} patients are there now.';
    final when = now.hour < 12 ? 'this morning' : 'today';
    return '$there ${day.arrivals} arrived $when.';
  }
}

/// Occupancy, in, out and status changes today. Four across; 2 × 2 when
/// the text is large.
class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.day, required this.deptName});

  final DepartmentDay day;
  final String deptName;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final occ = c.occupancy(day.percent);
    final tiles = <Widget>[
      _Tile(
        value: '${day.percent}%',
        label: '${day.occupied}/${day.beds} beds',
        semantics:
            'Occupancy ${day.percent} percent, ${day.occupied} of '
            '${day.beds} beds, ${occ.word.toLowerCase()}',
        bar: (day.percent / 100).clamp(0.0, 1.0),
        barColor: occ.fill,
      ),
      _Tile(
        value: '${day.arrivals}',
        label: 'in today',
        semantics: '${day.arrivals} in today',
      ),
      _Tile(
        value: '${day.departures}',
        label: 'out today',
        semantics: '${day.departures} out today',
      ),
      _Tile(
        value: '${day.statusChanges}',
        label: 'status changes',
        semantics: '${day.statusChanges} status changes today',
      ),
    ];
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    Widget row(List<Widget> items) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, w) in items.indexed) ...[
            if (i > 0) SizedBox(width: t.space.xs),
            Expanded(child: w),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      label: '$deptName today',
      child: large
          ? Column(
              children: [
                row(tiles.sublist(0, 2)),
                SizedBox(height: t.space.xs),
                row(tiles.sublist(2)),
              ],
            )
          : row(tiles),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.label,
    required this.semantics,
    this.bar,
    this.barColor,
  });

  final String value;
  final String label;
  final String semantics;
  final double? bar;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(t.space.sm - 2),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: t.radius.inputBr,
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: t.typography
                  .tabular(t.typography.title2)
                  .copyWith(color: c.text),
            ),
            Text(
              label,
              style: t.typography.caption.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (bar != null) ...[
              SizedBox(height: t.space.xs - 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(t.radius.full),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: c.subtle),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: bar,
                        child: ColoredBox(color: barColor ?? c.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One row of the department feed: IN / OUT tag for transfers, the
/// doctor's avatar for status changes.
class _DeptRow extends StatelessWidget {
  const _DeptRow({
    required this.snapshot,
    required this.code,
    required this.event,
    required this.live,
    super.key,
  });

  final HospitalSnapshot snapshot;
  final String code;
  final HistoryEvent event;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = snapshot;
    final e = event;
    final patient = s.patient(e.patientId);
    final name = patient?.fullName ?? 'Unknown patient';
    final by = '${shortStaffName(e.byName)} · ${roleLabel(e.byRole)}';

    late final Widget lead;
    late final String title;
    late final String sub;
    late final String spoken;
    switch (e) {
      case LocationEvent(:final from, :final to) when to == code:
        lead = const _IoTag(incoming: true);
        title = from == null
            ? '$name · new admission'
            : '$name ← ${deptName(s, from)}';
        sub = by;
        spoken = from == null
            ? 'In, $name, new admission'
            : 'In, $name from ${deptName(s, from)}';
      case LocationEvent(:final to):
        lead = const _IoTag(incoming: false);
        title = '$name → ${deptName(s, to)}';
        final stay = stayBefore(s, e);
        sub = stay == null ? by : '$by · stayed ${duration(stay)}';
        spoken = 'Out, $name to ${deptName(s, to)}';
      case StatusEvent(:final to):
        lead = WlInitialsAvatar.staff(e.byName, role: e.byRole);
        title = '$name · ${WlStatusLabels.of(to)}';
        sub = by;
        spoken = '$name, status ${WlStatusLabels.of(to)}';
    }

    return Semantics(
      button: patient != null,
      label: '$spoken, by $by, ${hm(e.at)}',
      excludeSemantics: true,
      child: WlLiveHighlight(
        pulseKey: live ? e.id : null,
        child: InkWell(
          onTap: patient == null
              ? null
              : () => context.push(Routes.patient(e.patientId)),
          child: Container(
            constraints: BoxConstraints(minHeight: t.space.touchMin + 4),
            padding: EdgeInsets.symmetric(
              horizontal: t.space.md,
              vertical: t.space.sm - 2,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: FittedBox(fit: BoxFit.scaleDown, child: lead),
                ),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: t.typography.subhead.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        sub,
                        style: t.typography.caption.copyWith(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: t.space.xs),
                Text(
                  hm(e.at),
                  style: t.typography
                      .tabular(t.typography.subhead)
                      .copyWith(color: live ? c.primaryInk : c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "IN" / "OUT" text tag: direction is spelled out, never colour alone.
class _IoTag extends StatelessWidget {
  const _IoTag({required this.incoming});

  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.xxs, vertical: 2),
      decoration: BoxDecoration(
        color: incoming ? c.primarySoft : c.subtle,
        borderRadius: BorderRadius.circular(t.radius.chip / 2),
      ),
      child: Text(
        incoming ? 'IN' : 'OUT',
        maxLines: 1,
        softWrap: false,
        style: t.typography.overline.copyWith(
          color: incoming ? c.primaryInk : c.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _EmptyDept extends StatelessWidget {
  const _EmptyDept({required this.title, required this.body, this.onShowAll});

  final String title;
  final String body;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.only(top: t.space.xxl),
        child: Column(
          children: [
            WlEmptyState(icon: WlIcons.history, title: title, body: body),
            if (onShowAll != null)
              WlButton(
                label: 'Show all activity',
                variant: WlButtonVariant.secondary,
                fullWidth: false,
                dense: true,
                onPressed: onShowAll,
              ),
          ],
        ),
      ),
    );
  }
}
