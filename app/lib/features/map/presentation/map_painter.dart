import 'package:flutter/material.dart';

import '../../../core/theme/wl_tokens.dart';
import 'map_data.dart';
import 'map_geometry.dart';

/// A live transfer dot travelling along [path] (0 → 1).
class MapMovement {
  const MapMovement({required this.path, required this.t});

  final List<Offset> path;
  final double t;
}

/// Paints a [MapScene]: plates, departments tinted by occupancy, lift and
/// entrance blocks, the optional route, live dots and arrival rings.
/// Labels are widgets on top (real buttons), not painted text.
class HospitalMapPainter extends CustomPainter {
  HospitalMapPainter({
    required this.scene,
    required this.colors,
    required this.occupancy,
    this.selected,
    this.focus,
    this.ring,
    this.ringWidth = 3,
    this.route = const [],
    this.routeProgress = 1,
    this.movements = const [],
    this.arrivals = const {},
  });

  final MapScene scene;
  final WlColors colors;

  /// Department code → occupancy (for the tint).
  final Map<String, DeptOccupancy> occupancy;

  /// Selected department (dark outline as on MapLive).
  final String? selected;

  /// When set, every other department is dimmed (MapStates "focus").
  final String? focus;

  /// Department with a `primary` ring (mini map highlight).
  final String? ring;
  final double ringWidth;

  /// Route polyline in screen space, drawn up to [routeProgress].
  final List<Offset> route;
  final double routeProgress;

  final List<MapMovement> movements;

  /// Department code → arrival ring progress (0 → 1, fades out).
  final Map<String, double> arrivals;

  @override
  void paint(Canvas canvas, Size size) {
    final c = colors;
    final plateSide = Color.lerp(c.border, c.borderStrong, 0.45)!;
    final extraSide = Color.lerp(c.border, c.borderStrong, 0.25)!;
    for (final shape in scene.shapes) {
      switch (shape) {
        case PlateShape():
          _faces(
            canvas,
            shape,
            top: c.surface,
            left: c.border,
            right: plateSide,
            stroke: c.borderStrong,
            topStroke: 1,
          );
        case ExtraShape():
          _faces(
            canvas,
            shape,
            top: c.subtle,
            left: c.border,
            right: extraSide,
            stroke: c.borderStrong,
            topStroke: 0.75,
          );
        case DeptShape(:final department):
          final occ = occupancy[department.code];
          final style = c.occupancy(occ?.percent ?? 0);
          final dim = focus != null && focus != department.code;
          if (dim) {
            canvas.saveLayer(
              null,
              Paint()..color = c.text.withValues(alpha: .45),
            );
          }
          final on = selected == department.code;
          _faces(
            canvas,
            shape,
            top: style.tint,
            left: Color.alphaBlend(
              style.fill.withValues(alpha: .22),
              Color.alphaBlend(c.text.withValues(alpha: .06), c.surface),
            ),
            right: Color.alphaBlend(
              style.fill.withValues(alpha: .36),
              Color.alphaBlend(c.text.withValues(alpha: .11), c.surface),
            ),
            stroke: on ? c.primaryInk : style.fill,
            topStroke: on ? 2.5 : 1.25,
            sideStroke: 0,
          );
          if (dim) canvas.restore();
          if (ring == department.code) {
            canvas.drawPath(
              shape.top.path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeJoin = StrokeJoin.round
                ..strokeWidth = ringWidth
                ..color = c.primary,
            );
          }
          final a = arrivals[department.code];
          if (a != null) {
            canvas.drawPath(
              shape.top.path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeJoin = StrokeJoin.round
                ..strokeWidth = 3
                ..color = c.primary.withValues(alpha: (1 - a).clamp(0.0, 1.0)),
            );
          }
      }
    }
    _route(canvas);
    for (final m in movements) {
      _movement(canvas, m);
    }
  }

  void _faces(
    Canvas canvas,
    MapShape shape, {
    required Color top,
    required Color left,
    required Color right,
    required Color stroke,
    required double topStroke,
    double sideStroke = 0.75,
  }) {
    for (final f in shape.faces) {
      final path = f.path;
      final fill = switch (f.kind) {
        FaceKind.top => top,
        FaceKind.left => left,
        FaceKind.right => right,
      };
      canvas.drawPath(path, Paint()..color = fill);
      final w = f.kind == FaceKind.top ? topStroke : sideStroke;
      if (w > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = w
            ..color = stroke,
        );
      }
    }
  }

  Path _polyline(List<Offset> pts) {
    final p = Path();
    if (pts.isEmpty) return p;
    p.moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p;
  }

  void _route(Canvas canvas) {
    if (route.length < 2 || routeProgress <= 0) return;
    final full = _polyline(route);
    final drawn = routeProgress >= 1 ? full : _trim(full, routeProgress);
    canvas
      ..drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = colors.surface,
      )
      ..drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = colors.primaryInk,
      );
  }

  static Path _trim(Path path, double t) {
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var left = total * t;
    final out = Path();
    for (final m in metrics) {
      if (left <= 0) break;
      out.addPath(m.extractPath(0, left.clamp(0, m.length)), Offset.zero);
      left -= m.length;
    }
    return out;
  }

  void _movement(Canvas canvas, MapMovement m) {
    if (m.path.length < 2) return;
    final path = _polyline(m.path);
    // Dashed connector.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colors.primaryInk.withValues(alpha: .7);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 3), dash);
      }
    }
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, x) => s + x.length);
    var at = total * m.t.clamp(0.0, 1.0);
    Offset? pos;
    for (final metric in metrics) {
      if (at <= metric.length) {
        pos = metric.getTangentForOffset(at)?.position;
        break;
      }
      at -= metric.length;
    }
    pos ??= m.path.last;
    canvas
      ..drawCircle(pos, 5.5, Paint()..color = colors.primaryInk)
      ..drawCircle(
        pos,
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.surface,
      );
  }

  @override
  bool shouldRepaint(HospitalMapPainter old) => true;
}
