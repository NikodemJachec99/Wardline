import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/wl_tokens.dart';
import '../../../../core/widgets/wl/wl.dart';

/// motion.md "NFC rings": 3 rings, 3000 ms loop, offset 1 s. No loop token
/// exists in WlMotionTokens yet.
const Duration nfcRingCycle = Duration(seconds: 3);

/// Scan area from the `ScanNfc` / `ScanSuccess` artboards.
///
/// Idle / listening: two static guide circles, three expanding teal rings and
/// the NFC badge. [identified]: the area brightens (#F3F5F8 → primary 17%,
/// scale .92 → 1) and a check pops in (motion.md "Scan-area brighten").
/// Reduced motion: static rings at 18/12/7% and a colour swap only.
class NfcScanArea extends StatefulWidget {
  const NfcScanArea({required this.identified, super.key});

  final bool identified;

  /// Height from the artboard (340).
  static const double height = 340;

  @override
  State<NfcScanArea> createState() => _NfcScanAreaState();
}

class _NfcScanAreaState extends State<NfcScanArea>
    with TickerProviderStateMixin {
  late final AnimationController _rings = AnimationController(
    vsync: this,
    duration: nfcRingCycle,
  );
  late final AnimationController _bright = AnimationController(vsync: this);
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = WlMotion.reduced(context);
    _bright.duration = WlTokens.of(context).motion.slow;
    _sync(initial: true);
  }

  @override
  void didUpdateWidget(NfcScanArea old) {
    super.didUpdateWidget(old);
    if (old.identified != widget.identified) _sync();
  }

  void _sync({bool initial = false}) {
    if (widget.identified) {
      _rings.stop();
      if (_reduced || initial) {
        _bright.value = 1;
      } else {
        _bright.forward(from: 0);
      }
    } else {
      _bright.value = 0;
      if (_reduced) {
        _rings.stop();
      } else if (!_rings.isAnimating) {
        _rings.repeat();
      }
    }
  }

  @override
  void dispose() {
    _rings.dispose();
    _bright.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: NfcScanArea.height,
        child: Center(
          child: widget.identified ? _identified(context) : _listening(context),
        ),
      ),
    );
  }

  Widget _listening(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return SizedBox.square(
      dimension: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _circle(260, border: c.border),
          _circle(190, border: c.border),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _rings,
              builder: (context, _) => CustomPaint(
                painter: _RingsPainter(
                  color: c.primary,
                  progress: _reduced ? null : _rings.value,
                  curve: t.motion.out,
                ),
              ),
            ),
          ),
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
                boxShadow: t.elevation.e2,
              ),
              child: Icon(LucideIcons.nfc, size: 40, color: c.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identified(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final bright = scanBrightColor(c);
    // Check pops .6 → 1 over `motion.base`, starting 120 ms in.
    final slow = t.motion.slow.inMicroseconds;
    final pop = CurvedAnimation(
      parent: _bright,
      curve: Interval(
        t.motion.fast.inMicroseconds / slow,
        math.min(1, (t.motion.fast + t.motion.base).inMicroseconds / slow),
        curve: t.motion.out,
      ),
    );
    final glow = CurvedAnimation(parent: _bright, curve: t.motion.out);
    return SizedBox.square(
      dimension: 260,
      child: AnimatedBuilder(
        animation: _bright,
        builder: (context, _) {
          final g = _reduced ? 1.0 : glow.value;
          final p = _reduced ? 1.0 : pop.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.92 + 0.08 * g,
                child: _circle(240, fill: Color.lerp(c.subtle, bright, g)),
              ),
              _circle(160, fill: c.primarySoft),
              Opacity(
                opacity: p,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * p,
                  child: Container(
                    width: 92,
                    height: 92,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                      boxShadow: t.elevation.e2,
                    ),
                    child: Icon(WlIcons.check, size: 44, color: c.onPrimary),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _circle(double size, {Color? border, Color? fill}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: fill,
      border: border == null ? null : Border.all(color: border),
    ),
  );
}

/// #D5F0F1 from motion.md: brand teal at 17% over white. Derived from tokens
/// because WlColors has no named "scan read" colour.
Color scanBrightColor(WlColors c) =>
    Color.alphaBlend(c.primary.withValues(alpha: 0.17), c.surface);

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.color,
    required this.progress,
    required this.curve,
  });

  final Color color;

  /// Null = reduced motion (static rings).
  final double? progress;
  final Curve curve;

  static const List<(double, double)> _static = [
    (0.7, 0.18),
    (0.85, 0.12),
    (1, 0.07),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 3; i++) {
      final double scale;
      final double alpha;
      if (progress == null) {
        (scale, alpha) = _static[i];
      } else {
        final phase = curve.transform((progress! + i / 3) % 1);
        scale = 0.42 + 0.58 * phase;
        alpha = 0.55 * (1 - phase);
      }
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(center, maxR * scale, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.progress != progress || old.color != color;
}
