import 'package:flutter/material.dart';

import '../../../core/theme/wl_tokens.dart';

/// App mark from the Login artboard: teal rounded square, white cross, and
/// the transfer line (A → B) cut through the cross. Drawn, so it needs no
/// asset and works offline.
class WardlineLogo extends StatelessWidget {
  const WardlineLogo({this.size = 72, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = WlTokens.of(context).colors;
    return Semantics(
      image: true,
      label: 'Wardline',
      child: CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(fill: c.primary, mark: c.onPrimary),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.fill, required this.mark});

  final Color fill;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    // Artboard viewBox is 120 × 120.
    canvas.scale(size.width / 120, size.height / 120);
    const full = Rect.fromLTWH(0, 0, 120, 120);
    canvas.drawRRect(
      RRect.fromRectAndRadius(full, const Radius.circular(27)),
      Paint()..color = fill,
    );
    final cross = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(48, 26, 24, 68),
          const Radius.circular(6),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(26, 48, 68, 24),
          const Radius.circular(6),
        ),
      );
    final line = Path()
      ..moveTo(20, 84)
      ..lineTo(40, 84)
      ..lineTo(80, 36)
      ..lineTo(100, 36);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(cross, Paint()..color = mark);
    // Inside the cross the line is cut out (brand colour) ...
    canvas
      ..save()
      ..clipPath(cross)
      ..drawPath(line, stroke..color = fill)
      ..restore();
    // ... outside it, the line is white.
    canvas
      ..save()
      ..clipPath(
        Path.combine(PathOperation.difference, Path()..addRect(full), cross),
      )
      ..drawPath(line, stroke..color = mark)
      ..restore();
    final dot = Paint()..color = mark;
    canvas
      ..drawCircle(const Offset(20, 84), 6, dot)
      ..drawCircle(const Offset(100, 36), 6, dot);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.fill != fill || old.mark != mark;
}
