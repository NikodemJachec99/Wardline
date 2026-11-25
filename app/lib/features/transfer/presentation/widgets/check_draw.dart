import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/theme/wl_tokens.dart';

/// "Loading → checkmark" from design/handoff/motion.md: circle stroke 0→1
/// (slow 380ms), then the tick stroke (260ms, starting at 300ms), easing
/// out. Built only after the server answered (never on the tap).
/// Reduced motion: static check with a 120ms fade.
class TransferCheckDraw extends StatefulWidget {
  const TransferCheckDraw({this.size = 88, super.key});

  final double size;

  @override
  State<TransferCheckDraw> createState() => _TransferCheckDrawState();
}

// Spec timings, as fractions of the whole draw (380 + 260 @300 = 560ms).
const double _total = 560;
const double _circleEnd = 380 / _total;
const double _tickStart = 300 / _total;

class _TransferCheckDrawState extends State<TransferCheckDraw>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final t = WlTokens.of(context);
    if (WlMotion.reduced(context)) {
      _c.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      _visible = true;
      _c
        ..duration = t.motion.slow * (_total / 380)
        ..forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final ok = t.colors.status(PatientStatus.readyForDischarge);
    final curve = t.motion.out;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: t.motion.fast,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final circle = curve.transform((v / _circleEnd).clamp(0.0, 1.0));
          final tick = curve.transform(
            ((v - _tickStart) / (1 - _tickStart)).clamp(0.0, 1.0),
          );
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _CheckPainter(
              stroke: ok.base,
              fill: ok.bg,
              circle: circle,
              tick: tick,
            ),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.stroke,
    required this.fill,
    required this.circle,
    required this.tick,
  });

  final Color stroke;
  final Color fill;
  final double circle;
  final double tick;

  @override
  void paint(Canvas canvas, Size size) {
    // Artboard geometry: 56-unit viewBox, circle r 26, tick M17 29 l7 7 15-15.
    final k = size.width / 56;
    final center = Offset(28 * k, 28 * k);
    final r = 26 * k;
    final line = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(
      center,
      r,
      Paint()..color = fill.withValues(alpha: circle),
    );
    if (circle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        2 * math.pi * circle,
        false,
        line,
      );
    }
    if (tick > 0) {
      final path = Path()
        ..moveTo(17 * k, 29 * k)
        ..lineTo(24 * k, 36 * k)
        ..lineTo(39 * k, 21 * k);
      for (final PathMetric m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * tick), line);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.circle != circle || old.tick != tick;
}
