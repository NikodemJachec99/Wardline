// Hospital map geometry: floor plates, departments, lift core and the
// isometric / flat projections. Pure Dart (no widgets) so the full map, the
// route layer and WlMiniMap share exactly the same shapes.
//
// Source: design/handoff/sample-data.json ("each floor plate is 10 × 6
// units; x to the right, y towards the viewer; isometric projection
// screenX = (x − y)·cos30, screenY = (x + y)·sin30 − z") and the MapLive /
// MapStates artboards (plate margin, gaps, heights, entrance, lift).

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../domain/models.dart';

/// Floor names as on the artboards (segmented control, sheets, labels).
const List<String> kFloorNames = <String>['Ground', 'Floor 1', 'Floor 2'];

/// Number of floors in the demo hospital.
const int kFloorCount = 3;

String floorName(int floor) => floor >= 0 && floor < kFloorNames.length
    ? kFloorNames[floor]
    : 'Floor $floor';

/// "Ground floor" / "Floor 1" (titles, mini map chip).
String floorTitle(int floor) => floor == 0 ? 'Ground floor' : floorName(floor);

enum MapMode { iso, flat }

/// Floor plate outline around the 10 × 6 usable area.
const MapRect kPlate = MapRect(-0.3, -0.3, 10.6, 6.6);

/// Lift core, the same on every floor (sample-data.json → liftCore).
const MapRect kLiftCore = MapRect(8.5, 3.4, 1.5, 2.6);

/// Ground-floor entrance hall (MapLive artboard).
const MapRect kEntrance = MapRect(4.3, 3.4, 3.9, 2.6);

const double _cos30 = 0.8660254037844386;
const double _isoFloorGap = 8.6;
const double _flatRowGap = 1.4;
const double _flatLabelSpace = 1.2;
const double _deptHeight = 0.55;
const double _extraHeight = 0.18;
const double _plateDepth = 0.35;
const double _deptInset = 0.12;

/// A projected polygon.
typedef Poly = List<Offset>;

enum FaceKind { top, left, right }

class MapFace {
  const MapFace(this.kind, this.points);

  final FaceKind kind;
  final Poly points;

  Path get path => Path()..addPolygon(points, true);
}

/// Something drawn on a floor: the plate, a department or an extra block.
sealed class MapShape {
  const MapShape(this.floor, this.faces);

  final int floor;

  /// Paint order: left, right, top.
  final List<MapFace> faces;

  MapFace get top => faces.firstWhere((f) => f.kind == FaceKind.top);
}

final class PlateShape extends MapShape {
  const PlateShape(super.floor, super.faces);
}

final class DeptShape extends MapShape {
  const DeptShape(super.floor, super.faces, this.department, this.center);

  final Department department;

  /// Label anchor: centre of the top face.
  final Offset center;
}

final class ExtraShape extends MapShape {
  const ExtraShape(super.floor, super.faces, this.label, this.center);

  /// "Lift" or "Entrance".
  final String label;
  final Offset center;

  bool get isLift => label == 'Lift';
}

/// Floor caption ("GROUND", "FLOOR 1") position.
class FloorCaption {
  const FloorCaption(this.floor, this.anchor);

  final int floor;
  final Offset anchor;
}

/// Projects map units to screen pixels for one layout.
class MapProjection {
  MapProjection._(this.mode, this.floors, this.scale, this.origin);

  /// Fits [floors] (stacked when more than one) into [size] with [padding].
  factory MapProjection.fit({
    required MapMode mode,
    required List<int> floors,
    required Size size,
    EdgeInsets padding = EdgeInsets.zero,
    double alignY = 0.5,
  }) {
    final probe = MapProjection._(mode, floors, 1, Offset.zero);
    final bounds = probe._unitBounds();
    final w = math.max(1.0, size.width - padding.horizontal);
    final h = math.max(1.0, size.height - padding.vertical);
    final s = math.min(w / bounds.width, h / bounds.height);
    final contentW = bounds.width * s;
    final contentH = bounds.height * s;
    final origin = Offset(
      padding.left + (w - contentW) / 2 - bounds.left * s,
      padding.top + (h - contentH) * alignY - bounds.top * s,
    );
    return MapProjection._(mode, floors, s, origin);
  }

  final MapMode mode;

  /// Shown floors, ascending.
  final List<int> floors;

  /// Pixels per map unit.
  final double scale;
  final Offset origin;

  bool get stacked => floors.length > 1;

  /// Map point (x, y, height z) on [floor] → screen.
  Offset point(int floor, double x, double y, [double z = 0]) {
    final u = _unit(floor, x, y, z);
    return origin + u * scale;
  }

  Offset _unit(int floor, double x, double y, [double z = 0]) {
    switch (mode) {
      case MapMode.iso:
        final zz = z + (stacked ? floors.indexOf(floor) * _isoFloorGap : 0);
        return Offset((x - y) * _cos30, (x + y) * 0.5 - zz);
      case MapMode.flat:
        // Highest floor on top, like a building section.
        final row = stacked ? floors.length - 1 - floors.indexOf(floor) : 0;
        final rowH = kPlate.d + _flatRowGap + _flatLabelSpace;
        return Offset(x, y + row * rowH + _flatLabelSpace);
    }
  }

  Rect _unitBounds() {
    final pts = <Offset>[];
    for (final f in floors) {
      for (final (x, y) in _corners(kPlate)) {
        if (mode == MapMode.iso) {
          pts
            ..add(_unit(f, x, y, -_plateDepth))
            ..add(_unit(f, x, y, _deptHeight));
        } else {
          pts.add(_unit(f, x, y));
        }
      }
      if (mode == MapMode.flat) {
        pts.add(_unit(f, kPlate.x, kPlate.y - _flatLabelSpace));
      }
    }
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final p in pts) {
      l = math.min(l, p.dx);
      t = math.min(t, p.dy);
      r = math.max(r, p.dx);
      b = math.max(b, p.dy);
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  static List<(double, double)> _corners(MapRect r) => [
    (r.x, r.y),
    (r.x + r.w, r.y),
    (r.x + r.w, r.y + r.d),
    (r.x, r.y + r.d),
  ];

  /// A block (box in iso, rectangle in flat) for [r] on [floor].
  List<MapFace> block(int floor, MapRect r, double z0, double height) {
    if (mode == MapMode.flat) {
      return [
        MapFace(FaceKind.top, [
          for (final (x, y) in _corners(r)) point(floor, x, y),
        ]),
      ];
    }
    final z1 = z0 + height;
    final x = r.x, y = r.y, w = r.w, d = r.d;
    return [
      MapFace(FaceKind.left, [
        point(floor, x, y + d, z1),
        point(floor, x + w, y + d, z1),
        point(floor, x + w, y + d, z0),
        point(floor, x, y + d, z0),
      ]),
      MapFace(FaceKind.right, [
        point(floor, x + w, y, z1),
        point(floor, x + w, y + d, z1),
        point(floor, x + w, y + d, z0),
        point(floor, x + w, y, z0),
      ]),
      MapFace(FaceKind.top, [
        point(floor, x, y, z1),
        point(floor, x + w, y, z1),
        point(floor, x + w, y + d, z1),
        point(floor, x, y + d, z1),
      ]),
    ];
  }

  /// Centre of a department's top face.
  Offset deptCenter(Department d) => point(
    d.floor,
    d.map.x + d.map.w / 2,
    d.map.y + d.map.d / 2,
    mode == MapMode.iso ? _deptHeight : 0,
  );

  /// Centre of the lift core top on [floor].
  Offset liftPoint(int floor) => point(
    floor,
    kLiftCore.x + kLiftCore.w / 2,
    kLiftCore.y + kLiftCore.d / 2,
    mode == MapMode.iso ? _extraHeight : 0,
  );

  /// Where the floor caption goes: under the plate's front-left corner in
  /// iso, above the plate in flat.
  Offset floorCaption(int floor) => mode == MapMode.iso
      ? point(floor, kPlate.x, kPlate.y + kPlate.d)
      : point(floor, kPlate.x, kPlate.y - _flatLabelSpace);
}

/// Everything drawn for one layout, in paint order.
class MapScene {
  MapScene._(this.projection, this.shapes, this.captions);

  factory MapScene.build({
    required MapProjection projection,
    required List<Department> departments,
  }) {
    final p = projection;
    final shapes = <MapShape>[];
    final captions = <FloorCaption>[];
    final iso = p.mode == MapMode.iso;
    MapRect inset(MapRect r, double g) =>
        MapRect(r.x + g, r.y + g, r.w - 2 * g, r.d - 2 * g);

    for (final f in p.floors) {
      shapes.add(PlateShape(f, p.block(f, kPlate, -_plateDepth, _plateDepth)));
      captions.add(FloorCaption(f, p.floorCaption(f)));
      final items = <(MapRect, Object)>[
        if (f == 0) (kEntrance, 'Entrance'),
        (kLiftCore, 'Lift'),
        for (final d in departments.where((d) => d.floor == f)) (d.map, d),
      ]..sort((a, b) => (a.$1.x + a.$1.y).compareTo(b.$1.x + b.$1.y));
      for (final (rect, item) in items) {
        final g = iso ? _deptInset : 0.1;
        if (item is Department) {
          shapes.add(
            DeptShape(
              f,
              p.block(f, inset(rect, g), 0, _deptHeight),
              item,
              p.deptCenter(item),
            ),
          );
        } else {
          final c = p.point(
            f,
            rect.x + rect.w / 2,
            rect.y + rect.d / 2,
            iso ? _extraHeight : 0,
          );
          shapes.add(
            ExtraShape(
              f,
              p.block(f, inset(rect, g), 0, _extraHeight),
              item as String,
              c,
            ),
          );
        }
      }
    }
    return MapScene._(p, shapes, captions);
  }

  final MapProjection projection;
  final List<MapShape> shapes;
  final List<FloorCaption> captions;

  Iterable<DeptShape> get departments => shapes.whereType<DeptShape>();

  DeptShape? department(String code) {
    for (final d in departments) {
      if (d.department.code == code) return d;
    }
    return null;
  }

  /// Department under [point], top-most first. Null on empty floor.
  String? hitTest(Offset point) {
    for (final s in shapes.reversed) {
      if (s is! DeptShape) continue;
      for (final f in s.faces) {
        if (_contains(f.points, point)) return s.department.code;
      }
    }
    return null;
  }

  /// Screen polyline from [codes] in order, through the lift core whenever
  /// the floor changes. Codes on floors that are not shown are skipped.
  List<Offset> pathThrough(List<String> codes) {
    final out = <Offset>[];
    DeptShape? prev;
    for (final code in codes) {
      final s = department(code);
      if (s == null) continue;
      if (prev != null && prev.floor != s.floor) {
        out
          ..add(projection.liftPoint(prev.floor))
          ..add(projection.liftPoint(s.floor));
      }
      out.add(s.center);
      prev = s;
    }
    return out;
  }

  static bool _contains(Poly poly, Offset p) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }
}
