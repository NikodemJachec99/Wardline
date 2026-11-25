import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/wl_tokens.dart';
import '../../../../core/widgets/wl/wl.dart';
import '../../../../data/hospital_repository.dart';
import '../../../../domain/models.dart';
import '../../application/clock.dart';
import '../../application/dashboard_stats.dart';
import 'dashboard_parts.dart';

/// "Hospital map · 3 floors · 2 bottlenecks" with bottleneck chips and a
/// stack of floor plates coloured by occupancy. Opens the map.
class MapEntryCard extends StatelessWidget {
  const MapEntryCard({required this.stats, required this.onTap, super.key});

  final DashboardStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final b = stats.bottlenecks;
    final floors = '${stats.floors} floors';
    final count = b.isEmpty
        ? null
        : '${b.length} bottleneck${b.length == 1 ? '' : 's'}';
    final spoken = [
      'Hospital map',
      floors,
      ?count,
      for (final d in b)
        '${d.department.name} ${d.percent} percent ${d.flag!.toLowerCase()}',
    ].join(', ');

    return DashCard(
      onTap: onTap,
      semanticsLabel: spoken,
      padding: EdgeInsets.fromLTRB(
        t.space.md,
        t.space.sm + 2,
        t.space.sm + 2,
        t.space.sm + 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hospital map',
                  style: t.typography.label.copyWith(color: c.text),
                ),
                Text.rich(
                  TextSpan(
                    style: t.typography.subhead.copyWith(
                      color: c.textSecondary,
                    ),
                    children: [
                      TextSpan(text: count == null ? floors : '$floors · '),
                      if (count != null)
                        TextSpan(
                          text: count,
                          style: TextStyle(
                            color: c.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (b.isNotEmpty) ...[
                  SizedBox(height: t.space.xs),
                  Wrap(
                    spacing: t.space.xxs + 2,
                    runSpacing: t.space.xxs + 2,
                    children: [for (final d in b) _BottleneckChip(d)],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: t.space.sm),
          _FloorPlates(stats.occupancy),
          SizedBox(width: t.space.xxs),
          Icon(WlIcons.chevronRight, size: 20, color: c.textSecondary),
        ],
      ),
    );
  }
}

class _BottleneckChip extends StatelessWidget {
  const _BottleneckChip(this.d);

  final DeptOccupancy d;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final o = t.colors.occupancy(d.percent);
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: EdgeInsets.symmetric(horizontal: t.space.xs),
      decoration: BoxDecoration(
        color: o.tint,
        borderRadius: BorderRadius.circular(t.radius.chip - 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: o.fill, shape: BoxShape.circle),
          ),
          SizedBox(width: t.space.xxs + 2),
          Text(
            '${d.code} ${d.percent}%',
            style: t.typography
                .tabular(t.typography.caption)
                .copyWith(
                  color: t.colors.dangerPressed,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Three floor plates (top floor first), one segment per department sized
/// by beds and filled with its occupancy colour. Decorative.
class _FloorPlates extends StatelessWidget {
  const _FloorPlates(this.depts);

  final List<DeptOccupancy> depts;

  static const double _w = 84;
  static const double _plate = 20;
  static const double _gap = 6;
  static const double _inner = 3;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final floors = depts.map((d) => d.department.floor).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return ExcludeSemantics(
      child: SizedBox(
        width: _w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, f) in floors.indexed) ...[
              if (i > 0) const SizedBox(height: _gap),
              Container(
                height: _plate,
                padding: const EdgeInsets.all(_inner),
                decoration: BoxDecoration(
                  color: c.subtle,
                  borderRadius: BorderRadius.circular(_gap),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (j, d)
                        in depts
                            .where((d) => d.department.floor == f)
                            .indexed) ...[
                      if (j > 0) const SizedBox(width: _inner),
                      Expanded(
                        flex: d.beds.clamp(1, 999),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.occupancy(d.percent).fill,
                            borderRadius: BorderRadius.circular(_inner),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder for the map card (DashLoading).
class MapEntryCardSkeleton extends StatelessWidget {
  const MapEntryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return DashCard(
      padding: EdgeInsets.all(t.space.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hospital map',
                  style: t.typography.label.copyWith(color: t.colors.text),
                ),
                SizedBox(height: t.space.xs),
                const WlSkeletonScope(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WlSkeleton(width: 140, height: 12),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          WlSkeleton(width: 72, height: 24),
                          SizedBox(width: 6),
                          WlSkeleton(width: 72, height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: t.space.sm),
          const WlSkeletonScope(child: WlSkeleton(width: 84, height: 72)),
        ],
      ),
    );
  }
}

/// Doctor: "5 of your patients are ready" (home department).
class ReadyCard extends StatelessWidget {
  const ReadyCard({
    required this.count,
    required this.departmentName,
    required this.onTap,
    super.key,
  });

  final int count;
  final String departmentName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final ready = c.status(PatientStatus.readyForDischarge);
    final title = count == 1
        ? '1 of your patients is ready'
        : '$count of your patients are ready';
    final sub = '${ready.label} · $departmentName';
    return DashCard(
      onTap: onTap,
      semanticsLabel: '$title, $sub',
      padding: EdgeInsets.fromLTRB(
        t.space.md,
        t.space.sm + 2,
        t.space.sm + 2,
        t.space.sm + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: ready.bg, shape: BoxShape.circle),
            child: Icon(
              WlIcons.forStatus(PatientStatus.readyForDischarge),
              size: 20,
              color: ready.fg,
            ),
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.typography
                      .tabular(t.typography.label)
                      .copyWith(color: c.text),
                ),
                Text(
                  sub,
                  style: t.typography.subhead.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          Icon(WlIcons.chevronRight, size: 20, color: c.textSecondary),
        ],
      ),
    );
  }
}

/// "Recent transfers" (nurse) / "Recent status changes" (doctor). The row
/// for the latest realtime event replays the live highlight.
/// Live activity feed. Events that appear after the first build (realtime,
/// own writes, refetch) slide in with [_FeedEntry]; the remote one is also
/// highlighted. The first build does not animate (the card stagger does).
class ActivityFeedCard extends StatefulWidget {
  const ActivityFeedCard({
    required this.title,
    required this.snapshot,
    required this.events,
    required this.now,
    required this.onSeeAll,
    required this.onOpenPatient,
    super.key,
  });

  final String title;
  final HospitalSnapshot snapshot;
  final List<HistoryEvent> events;
  final DateTime now;
  final VoidCallback onSeeAll;
  final ValueChanged<String> onOpenPatient;

  @override
  State<ActivityFeedCard> createState() => _ActivityFeedCardState();
}

class _ActivityFeedCardState extends State<ActivityFeedCard> {
  /// Event ids already shown; null before the first build.
  Set<String>? _seen;

  @override
  Widget build(BuildContext context) {
    final ActivityFeedCard(:title, :snapshot, :events, :onSeeAll) = widget;
    final t = WlTokens.of(context);
    final c = t.colors;
    final live = snapshot.lastRemoteEvent?.id;
    final seen = _seen;
    final fresh = {
      if (seen != null)
        for (final e in events)
          if (!seen.contains(e.id)) e.id,
    };
    _seen = {...?seen, for (final e in events) e.id};
    return Semantics(
      container: true,
      liveRegion: true,
      child: DashCard(
        padding: EdgeInsets.only(bottom: t.space.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.md,
                t.space.xxs,
                t.space.xs,
                0,
              ),
              child: SectionHeader(
                title: title,
                action: 'See all',
                onAction: onSeeAll,
              ),
            ),
            if (events.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.md,
                  0,
                  t.space.md,
                  t.space.md,
                ),
                child: Text(
                  'Nothing yet today',
                  style: t.typography.subhead.copyWith(color: c.textSecondary),
                ),
              ),
            for (final (i, e) in events.indexed)
              _FeedEntry(
                key: ValueKey(e.id),
                animate: fresh.contains(e.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (i > 0)
                      Divider(height: 1, thickness: 1, color: c.border),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: t.space.sm),
                      child: _feedItem(e, live == e.id),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _feedItem(HistoryEvent e, bool isLive) {
    final ActivityFeedCard(:snapshot, :now, :onOpenPatient) = widget;
    final p = snapshot.patient(e.patientId);
    String dept(String? code) =>
        code == null ? '' : (snapshot.department(code)?.name ?? code);
    final role = switch (e.byRole) {
      UserRole.nurse => 'Nurse',
      UserRole.doctor => 'Doctor',
      UserRole.admin => 'Admin',
    };
    final (String action, String sub) = switch (e) {
      LocationEvent(:final from, :final to) => (
        from == null ? 'admitted' : 'moved',
        from == null
            ? 'to ${dept(to)} · $role'
            : '${dept(from)} → ${dept(to)} · $role',
      ),
      StatusEvent(:final to) => (
        'updated',
        '${WlStatusLabels.of(to)} · $role'
            '${p == null ? '' : ' · ${dept(p.location)}'}',
      ),
    };
    return WlActivityFeedItem(
      key: ValueKey(e.id),
      actorName: e.byName,
      actorRole: e.byRole,
      action: action,
      patientName: p?.fullName ?? 'a patient',
      subline: sub,
      timeAgo: timeAgo(e.at, now),
      live: isLive,
      highlightKey: isLive ? e.id : null,
      onTap: p == null ? null : () => onOpenPatient(p.id),
    );
  }
}

/// Feed entry (motion.md "Feed entry"): a new row opens its height and
/// slides down into place while fading in, over `motion.base`. Reduced
/// motion: the row appears at once (the live highlight / "Updated" dot
/// still marks it).
class _FeedEntry extends StatefulWidget {
  const _FeedEntry({required this.animate, required this.child, super.key});

  final bool animate;
  final Widget child;

  @override
  State<_FeedEntry> createState() => _FeedEntryState();
}

class _FeedEntryState extends State<_FeedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late final CurvedAnimation _curve;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _curve = CurvedAnimation(
      parent: _c,
      curve: WlTokens.of(context).motion.out,
    );
    if (widget.animate && !WlMotion.reduced(context)) {
      _c.duration = WlTokens.of(context).motion.base;
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final curve = _curve;
    return SizeTransition(
      sizeFactor: curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curve,
        child: AnimatedBuilder(
          animation: curve,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -t.space.xs * (1 - curve.value)),
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Loading placeholder for the feed (DashLoading: two skeleton rows).
class ActivityFeedSkeleton extends StatelessWidget {
  const ActivityFeedSkeleton({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    Widget row(double a, double b) => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.md,
        vertical: t.space.sm,
      ),
      child: Row(
        children: [
          const WlSkeleton(height: 32, circle: true),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: a,
                  child: const WlSkeleton(height: 12),
                ),
                SizedBox(height: t.space.xs),
                FractionallySizedBox(
                  widthFactor: b,
                  child: const WlSkeleton(height: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.md,
              t.space.sm + 2,
              t.space.md,
              t.space.xxs,
            ),
            child: Text(
              title,
              style: t.typography.title3.copyWith(color: t.colors.text),
            ),
          ),
          WlSkeletonScope(
            child: Column(
              children: [
                row(0.7, 0.5),
                Divider(height: 1, thickness: 1, color: t.colors.border),
                row(0.62, 0.44),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Patients per department": floor segments, occupancy rows (highest
/// first, bottlenecks say "Bottleneck"/"Full"), selected department panel
/// with "Open" → department history.
class OccupancySection extends StatefulWidget {
  const OccupancySection({
    required this.stats,
    required this.initialSelection,
    required this.onOpen,
    super.key,
  });

  final DashboardStats stats;
  final String? initialSelection;
  final ValueChanged<String> onOpen;

  @override
  State<OccupancySection> createState() => _OccupancySectionState();
}

class _OccupancySectionState extends State<OccupancySection> {
  int? _floor; // null = all floors
  late String? _selected = widget.initialSelection;

  List<DeptOccupancy> get _rows => widget.stats.occupancy
      .where((d) => _floor == null || d.department.floor == _floor)
      .toList();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final rows = _rows;
    final floors =
        widget.stats.occupancy.map((d) => d.department.floor).toSet().toList()
          ..sort();
    final sel = rows.firstWhere(
      (d) => d.code == _selected,
      orElse: () => rows.first,
    );

    final detailText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${sel.department.name} · ${floorLabel(sel.department.floor)}',
          style: t.typography.subhead.copyWith(
            color: c.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${sel.occupied} of ${sel.beds} beds · ${sel.percent}% · '
          '${sel.flag ?? c.occupancy(sel.percent).word} · ${sel.free} free',
          style: t.typography
              .tabular(t.typography.caption)
              .copyWith(color: c.textSecondary),
        ),
      ],
    );
    final open = LinkButton(
      label: 'Open',
      semanticsLabel: 'Open ${sel.department.name} history',
      onTap: () => widget.onOpen(sel.code),
    );

    return DashCard(
      padding: EdgeInsets.only(top: t.space.sm + 2, bottom: t.space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.md),
            child: SectionHeader(
              title: 'Patients per department',
              trailingText:
                  '${widget.stats.patients} of ${widget.stats.beds} beds',
            ),
          ),
          SizedBox(height: t.space.sm - 2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.md),
            child: _FloorSegments(
              floors: floors,
              selected: _floor,
              onChanged: (f) => setState(() {
                _floor = f;
                final first = _rows.firstOrNull;
                if (first != null && !_rows.any((d) => d.code == _selected)) {
                  _selected = first.code;
                }
              }),
            ),
          ),
          SizedBox(height: t.space.xs),
          for (final d in rows)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.xs),
              child: WlDeptOccupancyBar(
                key: ValueKey(d.code),
                code: d.code,
                name: d.department.name,
                occupied: d.occupied,
                capacity: d.beds,
                flag: d.flag,
                selected: d.code == sel.code,
                onTap: () => setState(() => _selected = d.code),
              ),
            ),
          Container(
            margin: EdgeInsets.fromLTRB(
              t.space.md,
              t.space.xxs,
              t.space.md,
              t.space.xxs,
            ),
            padding: EdgeInsets.fromLTRB(
              t.space.sm,
              t.space.xxs,
              t.space.xxs,
              t.space.xxs,
            ),
            decoration: BoxDecoration(
              color: c.subtle,
              borderRadius: t.radius.inputBr,
            ),
            child: largeText(context)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: t.space.xs),
                      detailText,
                      open,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: detailText),
                      open,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// All · Ground · Floor 1 · Floor 2 (segmented, 48dp tall in total).
class _FloorSegments extends StatelessWidget {
  const _FloorSegments({
    required this.floors,
    required this.selected,
    required this.onChanged,
  });

  final List<int> floors;
  final int? selected;
  final ValueChanged<int?> onChanged;

  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final options = <(int?, String)>[
      (null, 'All'),
      for (final f in floors) (f, floorLabel(f)),
    ];
    return Container(
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: BorderRadius.circular(t.radius.input - 2),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (value, label) in options)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: value == selected,
                  label: value == null ? 'All floors' : label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(value),
                    child: AnimatedContainer(
                      duration: WlMotion.duration(context, t.motion.base),
                      curve: t.motion.out,
                      constraints: BoxConstraints(
                        minHeight: t.space.touchMin - 2 * _inset,
                      ),
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(horizontal: t.space.xxs),
                      decoration: BoxDecoration(
                        color: value == selected ? c.surface : null,
                        borderRadius: BorderRadius.circular(t.radius.chip),
                        boxShadow: value == selected ? t.elevation.e1 : null,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: t.typography.subhead.copyWith(
                          color: value == selected ? c.text : c.textSecondary,
                          fontWeight: value == selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Your departments · Most used this week": horizontal mini cards.
class YourDepartmentsStrip extends StatelessWidget {
  const YourDepartmentsStrip({
    required this.departments,
    required this.snapshot,
    required this.onOpen,
    super.key,
  });

  final List<Department> departments;
  final HospitalSnapshot snapshot;
  final ValueChanged<String> onOpen;

  static const double _cardWidth = 148;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
          child: const SectionHeader(
            title: 'Your departments',
            trailingText: 'Most used this week',
          ),
        ),
        SizedBox(height: t.space.sm - 2),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, d) in departments.indexed) ...[
                  if (i > 0) SizedBox(width: t.space.sm - 2),
                  SizedBox(
                    width: _cardWidth,
                    child: _DeptMiniCard(
                      d: DeptOccupancy(
                        department: d,
                        occupied: snapshot.occupancy(d.code),
                      ),
                      onTap: () => onOpen(d.code),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeptMiniCard extends StatelessWidget {
  const _DeptMiniCard({required this.d, required this.onTap});

  final DeptOccupancy d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final o = c.occupancy(d.percent);
    final name = d.department.name;
    return DashCard(
      onTap: onTap,
      semanticsLabel:
          '$name, ${floorLabel(d.department.floor)}, ${d.percent} percent, '
          '${(d.flag ?? o.word).toLowerCase()}, ${d.free} free',
      padding: EdgeInsets.all(t.space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${d.code} · ${floorLabel(d.department.floor)}',
            style: t.typography.caption.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: t.space.xxs),
          Text(
            name,
            style: t.typography.callout.copyWith(
              color: c.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          SizedBox(height: t.space.xs - 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(t.radius.full),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: c.subtle)),
                  FractionallySizedBox(
                    widthFactor: (d.percent / 100).clamp(0.0, 1.0),
                    heightFactor: 1,
                    alignment: AlignmentDirectional.centerStart,
                    child: ColoredBox(color: o.fill),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: t.space.xs - 2),
          Text.rich(
            TextSpan(
              style: t.typography
                  .tabular(t.typography.caption)
                  .copyWith(color: c.textSecondary),
              children: [
                TextSpan(
                  text: '${d.percent}%',
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' · ${d.free} free'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
