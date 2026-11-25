import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/failures.dart';
import '../../../domain/models.dart';
import 'patient_filters_sheet.dart';
import 'patient_list_model.dart';

/// Patients list (`/patients`, artboard `PatientsList`): sticky search,
/// filter chips, compact cards grouped by department, live highlight for
/// changes made by others (flow 6), offline cache (flow 4).
class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  PatientFilter _filter = const PatientFilter();
  bool _scrolled = false;

  /// Realtime event that arrived while this screen was mounted; its card
  /// reads "Moved to X · now" for a minute.
  String? _liveEventId;
  Timer? _liveTimer;

  @override
  void dispose() {
    _liveTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onRemoteEvent(HistoryEvent? prev, HistoryEvent? next) {
    if (next == null || identical(prev, next)) return;
    setState(() => _liveEventId = next.id);
    _liveTimer?.cancel();
    _liveTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) setState(() => _liveEventId = null);
    });
  }

  Future<void> _openFilters(HospitalSnapshot snap) async {
    final result = await showPatientFiltersSheet(
      context,
      snapshot: snap,
      initial: _filter,
      query: _query,
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  Future<void> _refresh() async {
    try {
      await ref.read(hospitalRepositoryProvider).refresh();
    } on WlFailure {
      // Offline: the banner already says the list is cached.
    }
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<HistoryEvent?>(
      hospitalProvider.select((s) => s.lastRemoteEvent),
      _onRemoteEvent,
    );
    final t = WlTokens.of(context);
    final c = t.colors;
    final snap = ref.watch(hospitalProvider);
    final conn = ref.watch(connectivityProvider);
    final me = ref.watch(sessionProvider);
    final offline = !conn.online;
    final syncedAt = hm(conn.syncedAt);
    final stale =
        DateTime.now().difference(conn.syncedAt) > const Duration(minutes: 15);
    final loading = snap.patients.isEmpty;

    final visible = visiblePatients(snap, _filter, _query);
    final groups = groupByDepartment(snap, visible);
    final total = snap.patients.length;
    final live = snap.lastRemoteEvent?.id == _liveEventId
        ? snap.lastRemoteEvent
        : null;

    final subtitle = loading
        ? null
        : visible.length == total
        ? '$total patients'
        : '${visible.length} of $total patients';

    final header = WlLargeTitle(
      title: 'Patients',
      subtitle: subtitle,
      showBack: false,
      trailing: [
        if (conn.state != WlConnectionState.live)
          WlConnectionIndicator(state: conn.state),
        _FilterButton(
          activeCount: _filter.activeCount,
          onTap: loading ? null : () => _openFilters(snap),
        ),
      ],
    );

    final sticky = AnimatedContainer(
      duration: WlMotion.duration(context, t.motion.fast),
      decoration: BoxDecoration(
        color: c.page.withValues(alpha: 0.94),
        boxShadow: _scrolled ? t.elevation.e1 : null,
        border: Border(
          bottom: BorderSide(
            color: _scrolled ? c.border : c.page.withValues(alpha: 0),
          ),
        ),
      ),
      padding: EdgeInsets.only(top: t.space.xs, bottom: t.space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
            child: WlSearchBar(
              controller: _search,
              hint: offline
                  ? 'Search cached patients'
                  : 'Name, ID or department',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (loading)
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                t.space.xs,
                t.space.gutter,
                0,
              ),
              child: WlSkeletonScope(
                child: Row(
                  children: [
                    WlSkeleton(width: 64, height: 36, radius: t.radius.chip),
                    SizedBox(width: t.space.xs),
                    WlSkeleton(width: 112, height: 36, radius: t.radius.chip),
                    SizedBox(width: t.space.xs),
                    WlSkeleton(width: 84, height: 36, radius: t.radius.chip),
                  ],
                ),
              ),
            )
          else
            WlFilterChips(chips: _chips(snap, me)),
          if (offline)
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                t.space.xxs,
                t.space.gutter,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: WlCacheBadge(syncedAt: syncedAt, stale: stale),
              ),
            ),
        ],
      ),
    );

    final Widget body;
    if (loading) {
      body = ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          t.space.gutter,
          t.space.xxs,
          t.space.gutter,
          t.space.md,
        ),
        children: const [_SkeletonList()],
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth != 0) return false;
          final scrolled = n.metrics.pixels > 0;
          if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
          return false;
        },
        child: RefreshIndicator.adaptive(
          onRefresh: _refresh,
          color: c.primaryInk,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (visible.isEmpty)
                SliverToBoxAdapter(child: _empty(snap))
              else
                for (final g in groups)
                  _groupSliver(
                    context,
                    snap: snap,
                    group: g,
                    live: live,
                    cachedAsOf: offline ? syncedAt : null,
                  ),
              SliverPadding(padding: EdgeInsets.only(bottom: t.space.lg)),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: c.page,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (offline)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.gutter,
                  0,
                  t.space.gutter,
                  t.space.xxs,
                ),
                child: WlOfflineBanner(syncedAt: syncedAt),
              )
            else if (conn.backOnlineAt != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.gutter,
                  0,
                  t.space.gutter,
                  t.space.xxs,
                ),
                child: WlOfflineBanner.backOnline(syncedAt: syncedAt),
              ),
            sticky,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  List<WlFilterChipData> _chips(HospitalSnapshot snap, StaffMember? me) {
    final home = me?.homeDepartment;
    final dept = _filter.departments.length == 1
        ? snap.department(_filter.departments.first)
        : null;
    int countOf(PatientStatus s) =>
        snap.patients.where((p) => p.status == s).length;
    final statuses = [
      PatientStatus.admitted,
      PatientStatus.inTreatment,
      PatientStatus.readyForDischarge,
      if (snap.patients.any((p) => p.status == PatientStatus.discharged))
        PatientStatus.discharged,
    ];
    return [
      WlFilterChipData(
        label: 'All',
        count: snap.patients.length,
        selected: _filter.isEmpty,
        onTap: () => setState(() => _filter = const PatientFilter()),
      ),
      WlFilterChipData(
        label: _filter.departments.isEmpty
            ? 'Department'
            : dept?.shortName ?? '${_filter.departments.length} departments',
        dropdown: true,
        selected: _filter.departments.isNotEmpty,
        onTap: () => _openFilters(snap),
      ),
      if (home != null && snap.department(home) != null)
        WlFilterChipData(
          label: 'My ward',
          selected:
              _filter.departments.length == 1 &&
              _filter.departments.contains(home),
          onTap: () => setState(() {
            final mine =
                _filter.departments.length == 1 &&
                _filter.departments.contains(home);
            _filter = _filter.copyWith(departments: mine ? {} : {home});
          }),
        ),
      for (final s in statuses)
        WlFilterChipData(
          label: WlTokens.of(context).colors.status(s).shortLabel,
          count: countOf(s),
          selected: _filter.statuses.contains(s),
          onTap: () => setState(() => _filter = _filter.toggleStatus(s)),
        ),
    ];
  }

  Widget _empty(HospitalSnapshot snap) {
    final q = _query.trim();
    final dept = _filter.departments.length == 1
        ? snap.department(_filter.departments.first)
        : null;
    final where = dept == null ? '' : ' in ${dept.shortName}';
    return WlEmptyState(
      icon: WlIcons.search,
      title: q.isEmpty
          ? 'No patients match these filters'
          : 'No patients match "$q"$where',
      body: 'Check the spelling, or search by patient ID, e.g. HPT-7K3M9QX2.',
      primary: _filter.isEmpty
          ? null
          : WlStateAction(
              'Clear filters',
              () => setState(() => _filter = const PatientFilter()),
            ),
      secondary: q.isEmpty ? null : WlStateAction('Clear search', _clearSearch),
    );
  }

  Widget _groupSliver(
    BuildContext context, {
    required HospitalSnapshot snap,
    required PatientGroup group,
    required HistoryEvent? live,
    required String? cachedAsOf,
  }) {
    final t = WlTokens.of(context);
    final d = group.department;
    final scaler = MediaQuery.textScalerOf(context);
    final stacked = scaler.scale(1) > 1.3;
    final header = _GroupHeader(
      department: d,
      shown: group.patients.length,
      occupied: snap.occupancy(d.code),
    );
    return SliverMainAxisGroup(
      key: ValueKey('group-${d.code}'),
      slivers: [
        if (stacked)
          SliverToBoxAdapter(child: header)
        else
          SliverPersistentHeader(
            pinned: true,
            delegate: _GroupHeaderDelegate(
              extent: math.max(32, scaler.scale(16) + t.space.xs),
              child: header,
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            t.space.gutter,
            t.space.xxs,
            t.space.gutter,
            t.space.sm,
          ),
          sliver: SliverList.separated(
            itemCount: group.patients.length,
            separatorBuilder: (_, _) => SizedBox(height: t.space.xs),
            itemBuilder: (context, i) {
              final p = group.patients[i];
              final isLive = live != null && live.patientId == p.id;
              final moved = isLive && live is LocationEvent ? live : null;
              final location =
                  snap.department(p.location)?.shortName ?? p.location;
              return WlPatientCard.compact(
                key: ValueKey(p.id),
                name: p.fullName,
                age: p.age,
                status: p.status,
                subtitle: moved == null
                    ? location
                    : 'Moved to ${snap.department(moved.to)?.shortName ?? moved.to} · now',
                highlightKey: isLive ? live.id : null,
                cachedAsOf: moved == null ? cachedAsOf : null,
                onTap: () => context.push(Routes.patient(p.id)),
                onShowOnMap: () => context.push(Routes.mapFor(patientId: p.id)),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 44 visual / 48 hit filter button with an active-filter count.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      label: activeCount == 0 ? 'Filters' : 'Filters, $activeCount active',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: t.space.touchMin,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: c.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: t.radius.inputBr,
                  side: BorderSide(color: c.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox.square(
                    dimension: t.space.touchMin - t.space.xxs,
                    child: Icon(WlIcons.filter, size: 20, color: c.text),
                  ),
                ),
              ),
              if (activeCount > 0)
                PositionedDirectional(
                  top: -t.space.xxs,
                  end: -t.space.xxs,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: EdgeInsets.symmetric(horizontal: t.space.xxs),
                    decoration: BoxDecoration(
                      color: c.primaryInk,
                      borderRadius: BorderRadius.circular(t.radius.full),
                    ),
                    child: Text(
                      '$activeCount',
                      textAlign: TextAlign.center,
                      style: t.typography
                          .tabular(t.typography.caption)
                          .copyWith(
                            color: c.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "INTERNAL MEDICINE · 29" + "91% · 3 free" (occupancy = colour + %).
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.department,
    required this.shown,
    required this.occupied,
  });

  final Department department;
  final int shown;
  final int occupied;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final d = department;
    final pct = d.beds == 0 ? 0 : (occupied * 100 / d.beds).round();
    final free = math.max(0, d.beds - occupied);
    final occ = c.occupancy(pct);
    final high = occ.level == OccupancyLevel.high;
    final style = t.typography
        .tabular(t.typography.caption)
        .copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.24);
    final right = free == 0 ? '$pct% · Full' : '$pct% · $free free';
    return Semantics(
      header: true,
      label:
          '${d.name}, $shown patients, $pct percent occupied, ${occ.word}, '
          '${free == 0 ? 'full' : '$free beds free'}',
      excludeSemantics: true,
      child: Container(
        color: c.page,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.gutter + t.space.xxs,
          vertical: t.space.xxs,
        ),
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: t.space.xs,
            children: [
              Text(
                '${d.name.toUpperCase()} · $shown',
                style: style.copyWith(color: c.textSecondary),
              ),
              Text(
                right,
                style: style.copyWith(
                  color: high ? c.dangerPressed : c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  _GroupHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(height: extent, child: child);

  @override
  bool shouldRebuild(_GroupHeaderDelegate old) =>
      old.extent != extent || old.child != child;
}

/// Loading: skeleton cards keep the card rhythm (artboard `PatientsList` 5).
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    const widths = [0.6, 0.52, 0.66, 0.48, 0.58];
    return WlSkeletonScope(
      child: Column(
        children: [
          for (final w in widths)
            Padding(
              padding: EdgeInsets.only(bottom: t.space.xs),
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: t.radius.cardBr,
                  border: Border.all(color: c.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Container(width: 4, color: c.border),
                    SizedBox(width: t.space.sm),
                    const WlSkeleton(height: 40, circle: true),
                    SizedBox(width: t.space.sm),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WlSkeleton(width: box.maxWidth * w, height: 12),
                            SizedBox(height: t.space.xs),
                            WlSkeleton(
                              width: box.maxWidth * (1 - w) * 0.9,
                              height: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: t.space.sm),
                    const WlSkeleton(width: 72, height: 24, radius: 6),
                    SizedBox(width: t.space.sm),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
