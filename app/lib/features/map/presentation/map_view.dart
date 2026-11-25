import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';
import 'map_data.dart';
import 'map_geometry.dart';
import 'map_painter.dart';

/// The hospital map for one layout: painted plates and departments, with
/// real buttons on top for every department label (accessibility), floor
/// captions, lift tags, and optionally a route with numbered stops.
class HospitalMapView extends StatelessWidget {
  const HospitalMapView({
    required this.departments,
    required this.occupancy,
    required this.floors,
    required this.mode,
    this.selected,
    this.onDepartmentTap,
    this.labels = true,
    this.stops = const [],
    this.routeProgress = 1,
    this.movements = const [],
    this.arrivals = const {},
    this.padding,
    this.alignY = 0,
    super.key,
  });

  final List<Department> departments;
  final Map<String, DeptOccupancy> occupancy;
  final List<int> floors;
  final MapMode mode;
  final String? selected;
  final ValueChanged<String>? onDepartmentTap;

  /// Department label buttons.
  final bool labels;

  /// Route stops in order; draws the path and numbered markers.
  final List<RouteStop> stops;
  final double routeProgress;

  /// Live transfers as (from, to, t).
  final List<(String, String, double)> movements;
  final Map<String, double> arrivals;
  final EdgeInsets? padding;

  /// 0 = top, 0.5 = centred vertically.
  final double alignY;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final pad =
            padding ??
            EdgeInsets.fromLTRB(
              t.space.lg,
              t.space.md,
              t.space.lg,
              mode == MapMode.iso ? t.space.lg : t.space.xs,
            );
        final projection = MapProjection.fit(
          mode: mode,
          floors: floors,
          size: size,
          padding: pad,
          alignY: alignY,
        );
        final scene = MapScene.build(
          projection: projection,
          departments: departments,
        );
        final compact = floors.length > 1;
        final route = scene.pathThrough([
          for (final s in stops) s.department.code,
        ]);
        final liftStops = <Offset>[];
        for (var i = 1; i < stops.length; i++) {
          final a = stops[i - 1].department.floor;
          final b = stops[i].department.floor;
          if (a != b) {
            for (final f in [a, b]) {
              final p = projection.liftPoint(f);
              if (!liftStops.contains(p)) liftStops.add(p);
            }
          }
        }
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: onDepartmentTap == null
                      ? null
                      : (d) {
                          final code = scene.hitTest(d.localPosition);
                          if (code != null) onDepartmentTap!(code);
                        },
                  child: CustomPaint(
                    key: const ValueKey('hospital-map-paint'),
                    painter: HospitalMapPainter(
                      scene: scene,
                      colors: t.colors,
                      occupancy: occupancy,
                      selected: selected,
                      route: route,
                      routeProgress: routeProgress,
                      movements: [
                        for (final (from, to, p) in movements)
                          MapMovement(
                            path: scene.pathThrough([from, to]),
                            t: p,
                          ),
                      ],
                      arrivals: arrivals,
                    ),
                  ),
                ),
              ),
              for (final cap in scene.captions)
                if (compact || mode == MapMode.flat)
                  Positioned(
                    left: cap.anchor.dx.clamp(t.space.xxs, size.width),
                    top: mode == MapMode.iso
                        ? cap.anchor.dy + t.space.xxs
                        : cap.anchor.dy,
                    child: Text(
                      floorName(cap.floor).toUpperCase(),
                      style: t.typography.overline.copyWith(
                        color: t.colors.textSecondary,
                      ),
                    ),
                  ),
              for (final s in scene.shapes.whereType<ExtraShape>())
                if (stops.isEmpty && (s.isLift || !compact))
                  _centered(
                    s.center,
                    _ExtraTag(label: s.label, lift: s.isLift),
                  ),
              if (labels)
                for (final s in scene.departments)
                  _centered(
                    s.center,
                    _DeptLabel(
                      occupancy:
                          occupancy[s.department.code] ??
                          DeptOccupancy(s.department, 0),
                      compact: compact,
                      selected: selected == s.department.code,
                      onTap: onDepartmentTap == null
                          ? null
                          : () => onDepartmentTap!(s.department.code),
                    ),
                  ),
              if (stops.isNotEmpty)
                for (final p in liftStops)
                  Positioned(
                    left: p.dx + t.space.lg - t.space.xxs,
                    top: p.dy + 2,
                    child: const FractionalTranslation(
                      translation: Offset(-.5, -.5),
                      child: ExcludeSemantics(child: _RouteLiftTag()),
                    ),
                  ),
              for (final (i, stop) in stops.indexed)
                if (scene.department(stop.department.code) case final shape?)
                  _centered(
                    shape.center,
                    _StopMarker(
                      index: i,
                      stop: stop,
                      appear: stops.length < 2
                          ? routeProgress
                          : ((routeProgress - i / stops.length) * 4).clamp(
                              0.0,
                              1.0,
                            ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  static Widget _centered(Offset at, Widget child) => Positioned(
    left: at.dx,
    top: at.dy,
    child: FractionalTranslation(
      translation: const Offset(-.5, -.5),
      child: child,
    ),
  );
}

/// Department label: a real button ("Internal Medicine, 29 of 32 beds,
/// 91 percent, bottleneck"), 48dp hit area around the visual tag.
class _DeptLabel extends StatelessWidget {
  const _DeptLabel({
    required this.occupancy,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final DeptOccupancy occupancy;
  final bool compact;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final o = occupancy;
    final warn = o.bottleneck;
    final fg = selected ? c.onPrimary : c.text;
    final base = t.typography.overline.copyWith(letterSpacing: 0, color: fg);
    return Semantics(
      button: true,
      selected: selected,
      label: o.spoken,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: t.space.touchMin,
            minHeight: t.space.touchMin,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: 30),
              padding: EdgeInsets.symmetric(
                horizontal: t.space.xs - 1,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: selected ? c.text : c.surface,
                borderRadius: t.radius.chipBr,
                border: Border.all(
                  color: selected
                      ? c.text
                      : warn
                      ? c.occupancy(100).fill
                      : c.border,
                ),
                boxShadow: t.elevation.e1,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (warn) ...[
                        Icon(
                          WlIcons.alert,
                          size: 11,
                          color: selected ? fg : c.occupancy(100).fill,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        o.department.code,
                        style: base.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Text(
                    compact
                        ? '${o.percent}%'
                        : '${o.occupied}/${o.beds} · ${o.percent}%',
                    style: t.typography
                        .tabular(base)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtraTag extends StatelessWidget {
  const _ExtraTag({required this.label, required this.lift});

  final String label;
  final bool lift;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final style = t.typography.overline.copyWith(
      letterSpacing: 0,
      fontWeight: FontWeight.w500,
      color: t.colors.textSecondary,
    );
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lift)
              Icon(
                WlIcons.arrowUpDown,
                size: 11,
                color: t.colors.textSecondary,
              ),
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}

class _RouteLiftTag extends StatelessWidget {
  const _RouteLiftTag();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      height: 22,
      padding: EdgeInsets.symmetric(horizontal: t.space.xxs + 2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(t.radius.chip - 2),
        border: Border.all(color: c.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(WlIcons.arrowUpDown, size: 11, color: c.textSecondary),
          const SizedBox(width: 3),
          Text(
            'Lift',
            style: t.typography.overline.copyWith(
              letterSpacing: 0,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered route stop. Focusable in order for screen readers.
class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.index,
    required this.stop,
    required this.appear,
  });

  final int index;
  final RouteStop stop;
  final double appear;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      container: true,
      sortKey: OrdinalSortKey(index.toDouble()),
      label:
          'Stop ${index + 1}, ${stop.department.name}, ${hm(stop.at)}'
          '${stop.current ? ', now' : ''}',
      excludeSemantics: true,
      child: Transform.scale(
        scale: appear,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: stop.current ? c.primaryInk : c.text,
            shape: BoxShape.circle,
            border: Border.all(color: c.surface, width: 2),
          ),
          child: Text(
            '${index + 1}',
            style: t.typography.caption.copyWith(
              color: c.onPrimary,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
