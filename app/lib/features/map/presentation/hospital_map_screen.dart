import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import 'department_sheet.dart';
import 'find_patient_sheet.dart';
import 'map_data.dart';
import 'map_geometry.dart';
import 'map_motion.dart';
import 'map_segmented.dart';
import 'map_view.dart';

/// Hospital map (flow 5; MapLive + MapStates artboards). Read-only.
///
/// - [floor]: show only that floor (0 Ground, 1, 2).
/// - [departmentCode]: open that department's sheet.
/// - [patientId]: open the patient's route today.
class HospitalMapScreen extends ConsumerStatefulWidget {
  const HospitalMapScreen({
    this.floor,
    this.departmentCode,
    this.patientId,
    super.key,
  });

  final int? floor;
  final String? departmentCode;
  final String? patientId;

  @override
  ConsumerState<HospitalMapScreen> createState() => _HospitalMapScreenState();
}

class _LiveMove {
  _LiveMove({
    required this.id,
    required this.from,
    required this.to,
    required this.label,
    required this.controller,
    required this.reduced,
  });

  final String id;
  final String from;
  final String to;

  /// "Adam Wójcik · Emergency → Radiology".
  final String label;
  final AnimationController controller;
  final bool reduced;
}

class _HospitalMapScreenState extends ConsumerState<HospitalMapScreen>
    with TickerProviderStateMixin {
  int? _floor;
  MapMode _mode = MapMode.iso;
  bool _list = false;
  String? _selected;
  String? _routePatient;
  bool _routeFromParam = false;
  late final AnimationController _route = AnimationController(vsync: this)
    ..addListener(_tick);
  final List<_LiveMove> _moves = [];

  @override
  void initState() {
    super.initState();
    final f = widget.floor;
    _floor = f != null && f >= 0 && f < kFloorCount ? f : null;
    final snapshot = ref.read(hospitalProvider);
    if (widget.patientId != null &&
        snapshot.patient(widget.patientId!) != null) {
      _routePatient = widget.patientId;
      _routeFromParam = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_routePatient != null) _startRoute();
      final code = widget.departmentCode;
      if (code != null && snapshot.department(code) != null) {
        final d = snapshot.department(code)!;
        if (_floor != null && _floor != d.floor) setState(() => _floor = null);
        _openDepartment(code);
      }
    });
  }

  @override
  void dispose() {
    _route.dispose();
    for (final m in _moves) {
      m.controller.dispose();
    }
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------- actions

  Future<void> _openDepartment(String code) async {
    setState(() => _selected = code);
    await showWlBottomSheet<void>(
      context: context,
      builder: (_) => DepartmentSheet(code: code),
    );
    if (mounted) setState(() => _selected = null);
  }

  Future<void> _findPatient() async {
    final id = await showWlBottomSheet<String>(
      context: context,
      builder: (_) => const FindPatientSheet(),
    );
    if (id != null && mounted) {
      setState(() {
        _routePatient = id;
        _routeFromParam = false;
      });
      _startRoute();
    }
  }

  void _startRoute() {
    final stops = routeToday(ref.read(hospitalProvider), _routePatient!);
    _route.duration =
        MapMotion.routeDraw + MapMotion.stopStagger * stops.length;
    if (WlMotion.reduced(context)) {
      _route.value = 1;
    } else {
      _route.forward(from: 0);
    }
  }

  void _exitRoute() {
    if (_routeFromParam) {
      Navigator.of(context).maybePop();
      return;
    }
    _route.stop();
    setState(() => _routePatient = null);
  }

  void _onRemote(HistoryEvent? prev, HistoryEvent? next) {
    if (next is! LocationEvent || next.from == null) return;
    if (prev != null && prev.id == next.id) return;
    if (_moves.any((m) => m.id == next.id)) return;
    final s = ref.read(hospitalProvider);
    final name = s.patient(next.patientId)?.fullName ?? 'Patient';
    String dept(String code) => s.department(code)?.shortName ?? code;
    final reduced = WlMotion.reduced(context);
    final controller = AnimationController(
      vsync: this,
      duration: reduced
          ? MapMotion.arrivalRing
          : MapMotion.dotTravel + MapMotion.arrivalRing,
    );
    final move = _LiveMove(
      id: next.id,
      from: next.from!,
      to: next.to,
      label: '$name · ${dept(next.from!)} → ${dept(next.to)}',
      controller: controller,
      reduced: reduced,
    );
    controller
      ..addListener(_tick)
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed && mounted) {
          setState(() => _moves.remove(move));
          controller.dispose();
        }
      });
    setState(() {
      _moves.add(move);
      while (_moves.length > MapMotion.maxMovements) {
        _moves.removeAt(0).controller.dispose();
      }
    });
    controller.forward();
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    ref.listen<HistoryEvent?>(
      hospitalProvider.select((s) => s.lastRemoteEvent),
      _onRemote,
    );
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = ref.watch(hospitalProvider);
    final conn = ref.watch(connectivityProvider);

    final inRoute = _routePatient != null && s.patient(_routePatient!) != null;
    return PopScope(
      canPop: !inRoute || _routeFromParam,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inRoute) _exitRoute();
      },
      child: Scaffold(
        backgroundColor: c.page,
        body: SafeArea(
          bottom: false,
          child: inRoute
              ? _routeBody(context, s, conn)
              : _mapBody(context, s, conn),
        ),
      ),
    );
  }

  Map<String, DeptOccupancy> _occupancy(HospitalSnapshot s) => {
    for (final d in s.departments) d.code: occupancyOf(s, d),
  };

  Widget _mapBody(
    BuildContext context,
    HospitalSnapshot s,
    ConnectivityStatus conn,
  ) {
    final t = WlTokens.of(context);
    final occ = _occupancy(s);
    final occupied = occ.values.fold<int>(0, (a, o) => a + o.occupied);
    final beds = occ.values.fold<int>(0, (a, o) => a + o.beds);
    final bottlenecks = occ.values.where((o) => o.bottleneck).length;
    final floors = _floor == null
        ? [for (var i = 0; i < kFloorCount; i++) i]
        : [_floor!];
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final floorSeg = MapSegmented<int?>(
      semanticsLabel: 'Floor',
      value: _floor,
      onChanged: (v) => setState(() => _floor = v),
      options: [
        (null, 'All'),
        for (var i = 0; i < kFloorCount; i++) (i, floorName(i)),
      ],
    );
    final modeSeg = MapSegmented<MapMode>(
      semanticsLabel: 'View',
      expand: false,
      value: _mode,
      onChanged: (v) => setState(() => _mode = v),
      options: const [(MapMode.flat, '2D'), (MapMode.iso, '3D')],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WlLargeTitle(
          title: 'Hospital map',
          subtitle:
              '$occupied/$beds beds · $bottlenecks '
              '${bottlenecks == 1 ? 'bottleneck' : 'bottlenecks'}',
          trailing: [WlConnectionIndicator(state: conn.state)],
        ),
        if (!conn.online) WlOfflineBanner(syncedAt: hm(conn.syncedAt)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: t.space.xs,
                  children: [floorSeg, modeSeg],
                )
              : Row(
                  spacing: t.space.xs,
                  children: [
                    Expanded(child: floorSeg),
                    modeSeg,
                  ],
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.gutter,
            t.space.sm - 2,
            t.space.gutter,
            0,
          ),
          child: const _Legend(),
        ),
        Expanded(
          child: _list
              ? _MapListView(
                  snapshot: s,
                  floors: floors,
                  onOpen: _openDepartment,
                )
              : _mapArea(context, s, occ, floors),
        ),
        _BottomActions(
          list: _list,
          onFind: _findPatient,
          onToggleList: () => setState(() => _list = !_list),
        ),
      ],
    );
  }

  Widget _mapArea(
    BuildContext context,
    HospitalSnapshot s,
    Map<String, DeptOccupancy> occ,
    List<int> floors,
  ) {
    final t = WlTokens.of(context);
    final reduced = WlMotion.reduced(context);
    bool visible(String code) =>
        floors.contains(s.department(code)?.floor ?? -1);
    final movements = <(String, String, double)>[];
    final arrivals = <String, double>{};
    final total = MapMotion.dotTravel + MapMotion.arrivalRing;
    for (final m in _moves) {
      final elapsed =
          m.controller.value * m.controller.duration!.inMilliseconds;
      final travel = MapMotion.dotTravel.inMilliseconds;
      final ring = MapMotion.arrivalRing.inMilliseconds;
      if (m.reduced || !visible(m.from)) {
        // Reduced motion (or A not on screen): the patient appears on B
        // with a 2s highlight.
        if (visible(m.to)) {
          arrivals[m.to] = m.reduced ? 0 : elapsed / total.inMilliseconds;
        }
      } else if (elapsed < travel) {
        movements.add((
          m.from,
          m.to,
          t.motion.inOut.transform(elapsed / travel),
        ));
      } else if (visible(m.to)) {
        arrivals[m.to] = ((elapsed - travel) / ring).clamp(0.0, 1.0);
      }
    }
    final key = ValueKey('map-${_floor ?? 'all'}-${_mode.name}');
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: reduced ? Duration.zero : t.motion.base,
          switchInCurve: t.motion.out,
          switchOutCurve: t.motion.out,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .96, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: key,
            child: HospitalMapView(
              departments: s.departments,
              occupancy: occ,
              floors: floors,
              mode: _mode,
              selected: _selected,
              onDepartmentTap: _openDepartment,
              movements: movements,
              arrivals: arrivals,
            ),
          ),
        ),
        if (_moves.isNotEmpty)
          Positioned(
            right: t.space.gutter,
            top: 0,
            child: _LivePill(label: _moves.last.label),
          ),
      ],
    );
  }

  Widget _routeBody(
    BuildContext context,
    HospitalSnapshot s,
    ConnectivityStatus conn,
  ) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final p = s.patient(_routePatient!)!;
    final stops = routeToday(s, p.id);
    final floors = [for (var i = 0; i < kFloorCount; i++) i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WlLargeTitle(
          title: 'Route today',
          subtitle: p.fullName,
          showBack: true,
          onBack: _exitRoute,
          trailing: [WlConnectionIndicator(state: conn.state)],
        ),
        if (!conn.online) WlOfflineBanner(syncedAt: hm(conn.syncedAt)),
        Expanded(
          child: HospitalMapView(
            departments: s.departments,
            occupancy: _occupancy(s),
            floors: floors,
            mode: _mode,
            labels: false,
            stops: stops,
            routeProgress: _route.value,
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .42,
          ),
          child: Container(
            margin: EdgeInsets.fromLTRB(
              t.space.gutter,
              t.space.xs,
              t.space.gutter,
              MediaQuery.paddingOf(context).bottom + t.space.md,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: t.radius.cardBr,
              border: Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: t.space.xxs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, stop) in stops.indexed)
                    _StopRow(
                      key: ValueKey('route-stop-$i'),
                      index: i,
                      stop: stop,
                      first: i == 0,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- pieces

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final style = t.typography.overline.copyWith(
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
      color: c.textSecondary,
    );
    Widget swatch(int pct, String text) {
      final o = c.occupancy(pct);
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: t.space.xxs + 1,
        children: [
          Container(
            width: t.space.sm - 2,
            height: t.space.sm - 2,
            decoration: BoxDecoration(
              color: o.tint,
              borderRadius: BorderRadius.circular(t.space.xxs - 1),
              border: Border.all(color: o.fill, width: 1.5),
            ),
          ),
          Text(text, style: t.typography.tabular(style)),
        ],
      );
    }

    return Wrap(
      spacing: t.space.sm,
      runSpacing: t.space.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        swatch(30, '<60%'),
        swatch(70, '60–85%'),
        swatch(90, '>85%'),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: t.space.xxs,
          children: [
            Icon(WlIcons.alert, size: 12, color: c.occupancy(100).fill),
            Text(
              'Bottleneck',
              style: style.copyWith(
                color: c.dangerPressed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: t.space.xl - t.space.xxs),
        padding: EdgeInsets.symmetric(horizontal: t.space.sm - 2),
        decoration: BoxDecoration(
          color: c.glassFill,
          borderRadius: BorderRadius.circular(t.radius.full),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: t.space.xs - 2,
          children: [
            Container(
              width: t.space.xs,
              height: t.space.xs,
              decoration: BoxDecoration(
                color: c.primaryInk,
                shape: BoxShape.circle,
              ),
            ),
            Text(label, style: t.typography.caption.copyWith(color: c.text)),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.list,
    required this.onFind,
    required this.onToggleList,
  });

  final bool list;
  final VoidCallback onFind;
  final VoidCallback onToggleList;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final find = WlButton(
      label: 'Find patient',
      icon: WlIcons.search,
      variant: WlButtonVariant.secondary,
      dense: true,
      onPressed: onFind,
    );
    final toggle = WlButton(
      label: list ? 'Map view' : 'List view',
      icon: list ? WlIcons.map : WlIcons.list,
      variant: WlButtonVariant.secondary,
      dense: true,
      onPressed: onToggleList,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.gutter,
        t.space.xs,
        t.space.gutter,
        MediaQuery.paddingOf(context).bottom + t.space.sm,
      ),
      child: large
          ? Column(spacing: t.space.xs, children: [find, toggle])
          : Row(
              spacing: t.space.xs,
              children: [
                Expanded(child: find),
                Expanded(child: toggle),
              ],
            ),
    );
  }
}

/// Accessible "List view": the same data as the map, as department cards
/// grouped by floor.
class _MapListView extends StatelessWidget {
  const _MapListView({
    required this.snapshot,
    required this.floors,
    required this.onOpen,
  });

  final HospitalSnapshot snapshot;
  final List<int> floors;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return ListView(
      key: const ValueKey('map-list-view'),
      padding: EdgeInsets.fromLTRB(
        t.space.gutter,
        t.space.sm,
        t.space.gutter,
        t.space.md,
      ),
      children: [
        for (final f in floors) ...[
          Padding(
            padding: EdgeInsets.only(
              top: f == floors.first ? 0 : t.space.md,
              bottom: t.space.xs,
              left: t.space.xxs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                floorTitle(f).toUpperCase(),
                style: t.typography.overline.copyWith(color: c.textSecondary),
              ),
            ),
          ),
          for (final d in snapshot.departments.where((d) => d.floor == f))
            Padding(
              padding: EdgeInsets.only(bottom: t.space.xs),
              child: Builder(
                builder: (context) {
                  final o = occupancyOf(snapshot, d);
                  return WlDepartmentCard(
                    code: d.code,
                    name: d.name,
                    floor: d.floor,
                    occupied: o.occupied,
                    beds: o.beds,
                    breakdown: breakdownFor(snapshot, d.code),
                    flag: o.bottleneck && !o.full ? 'Bottleneck' : null,
                    onTap: () => onOpen(d.code),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.index,
    required this.stop,
    required this.first,
    super.key,
  });

  final int index;
  final RouteStop stop;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final time = stop.current ? '${hm(stop.at)} · now' : hm(stop.at);
    return Semantics(
      container: true,
      sortKey: OrdinalSortKey(index.toDouble()),
      label:
          'Stop ${index + 1}, ${stop.department.name}'
          '${stop.liftNote == null ? '' : ', ${stop.liftNote}'}, $time',
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: t.space.touchMin - 8),
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md - 2,
          vertical: t.space.xs,
        ),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          spacing: t.space.sm - 2,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: stop.current ? c.primaryInk : c.text,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                textScaler: TextScaler.noScaling,
                style: t.typography.overline.copyWith(
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                  color: c.onPrimary,
                  height: 1,
                ),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: stop.department.shortName,
                  children: [
                    if (stop.liftNote != null)
                      TextSpan(
                        text: ' · ${stop.liftNote}',
                        style: t.typography.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
                style: t.typography.subhead.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              time,
              style: t.typography
                  .tabular(t.typography.subhead)
                  .copyWith(
                    fontSize: 13,
                    color: stop.current ? c.primaryInk : c.textSecondary,
                    fontWeight: stop.current
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
