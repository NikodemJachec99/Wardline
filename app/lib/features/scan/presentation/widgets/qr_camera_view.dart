import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/wl_tokens.dart';
import '../../../../core/widgets/wl/wl.dart';
import '../scan_copy.dart';

/// ScanQr artboard: line sweep each way. No loop token in WlMotionTokens yet
/// (artboard: 2.2 s alternate, rounded to whole seconds).
const Duration qrScanLineSweep = Duration(seconds: 2);

/// Live QR scanner (`ScanQr`): camera image, dimmed outside a 248 viewfinder
/// with white corners and a moving teal scan line, hint, "Switch to NFC".
/// Reduced motion: the scan line stays in the middle.
class QrCameraView extends StatelessWidget {
  const QrCameraView({
    required this.preview,
    required this.torchOn,
    required this.onClose,
    required this.onToggleTorch,
    this.onSwitchToNfc,
    super.key,
  });

  final Widget preview;
  final bool torchOn;
  final VoidCallback onClose;
  final VoidCallback onToggleTorch;

  /// Null when NFC isn't available on this device (nothing to switch to).
  final VoidCallback? onSwitchToNfc;

  static const double viewfinder = 248;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final dim = c.text.withValues(alpha: 0.5);
    final onDark = c.onPrimary;
    final pad = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: c.text,
      child: Stack(
        children: [
          Positioned.fill(child: preview),
          Column(
            children: [
              ColoredBox(
                color: dim,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space.xs,
                    pad.top + t.space.xs,
                    t.space.xs,
                    t.space.xs,
                  ),
                  child: Row(
                    children: [
                      _RoundButton(
                        icon: WlIcons.close,
                        label: ScanCopy.close,
                        onTap: onClose,
                      ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            ScanCopy.titleQr,
                            textAlign: TextAlign.center,
                            style: t.typography.title3.copyWith(color: onDark),
                          ),
                        ),
                      ),
                      _RoundButton(
                        icon: torchOn
                            ? LucideIcons.flashlight
                            : LucideIcons.flashlightOff,
                        label: ScanCopy.torch,
                        selected: torchOn,
                        onTap: onToggleTorch,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final size = (box.biggest.shortestSide - t.space.lg).clamp(
                      0.0,
                      viewfinder,
                    );
                    return CustomPaint(
                      painter: _CutoutPainter(
                        color: dim,
                        size: size,
                        radius: _viewfinderRadius(t),
                      ),
                      child: Center(
                        child: Semantics(
                          image: true,
                          label: ScanCopy.viewfinder,
                          child: SizedBox.square(
                            dimension: size,
                            child: _Viewfinder(color: onDark),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              ColoredBox(
                color: dim,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space.md,
                    t.space.lg,
                    t.space.md,
                    pad.bottom + t.space.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          ScanCopy.qrHint,
                          textAlign: TextAlign.center,
                          style: t.typography.title3.copyWith(color: onDark),
                        ),
                      ),
                      SizedBox(height: t.space.xxs + 2),
                      Text(
                        ScanCopy.qrSubHint,
                        textAlign: TextAlign.center,
                        style: t.typography.subhead.copyWith(
                          color: onDark.withValues(alpha: 0.82),
                        ),
                      ),
                      if (onSwitchToNfc != null) ...[
                        SizedBox(height: t.space.lg),
                        _GlassButton(
                          label: ScanCopy.switchToNfc,
                          icon: WlIcons.nfc,
                          onTap: onSwitchToNfc!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Viewfinder corner radius: 20 on the ScanQr artboard (card 16 + 4).
double _viewfinderRadius(WlTokens t) => t.radius.card + t.space.xxs;

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Toggle state (torch); null for a plain button.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final on = selected ?? false;
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: t.space.touchMin,
          height: t.space.touchMin,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? c.surface : c.text.withValues(alpha: 0.35),
          ),
          child: Icon(icon, size: 22, color: on ? c.primaryInk : c.onPrimary),
        ),
      ),
    );
  }
}

/// White 14% fill + 35% hairline over the camera (no BackdropFilter).
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: t.space.action),
          padding: EdgeInsets.symmetric(
            horizontal: t.space.md,
            vertical: t.space.xs,
          ),
          decoration: BoxDecoration(
            color: c.onPrimary.withValues(alpha: 0.14),
            borderRadius: t.radius.inputBr,
            border: Border.all(color: c.onPrimary.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: c.onPrimary),
              SizedBox(width: t.space.xs),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: t.typography.label.copyWith(color: c.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.color});

  final Color color;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: qrScanLineSweep,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WlMotion.reduced(context)) {
      _line
        ..stop()
        ..value = 0.5;
    } else if (!_line.isAnimating) {
      _line.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final curved = CurvedAnimation(parent: _line, curve: t.motion.inOut);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) => CustomPaint(
        painter: _ViewfinderPainter(
          corner: widget.color,
          line: t.colors.primary,
          radius: _viewfinderRadius(t),
          progress: curved.value,
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({
    required this.corner,
    required this.line,
    required this.radius,
    required this.progress,
  });

  final Color corner;
  final Color line;
  final double radius;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Corner brackets: 40 long, 4 wide, outer radius 22.
    final arm = size.shortestSide < 120 ? size.shortestSide / 4 : 40.0;
    final r = radius;
    final p = Paint()
      ..color = corner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    void drawCorner(Offset start, Offset end, Offset armStart, Offset armEnd) {
      canvas.drawPath(
        Path()
          ..moveTo(armStart.dx, armStart.dy)
          ..lineTo(start.dx, start.dy)
          ..arcToPoint(end, radius: Radius.circular(r))
          ..lineTo(armEnd.dx, armEnd.dy),
        p,
      );
    }

    drawCorner(Offset(0, r), Offset(r, 0), Offset(0, arm), Offset(arm, 0));
    drawCorner(
      Offset(w - r, 0),
      Offset(w, r),
      Offset(w - arm, 0),
      Offset(w, arm),
    );
    drawCorner(
      Offset(w, h - r),
      Offset(w - r, h),
      Offset(w, h - arm),
      Offset(w - arm, h),
    );
    drawCorner(
      Offset(r, h),
      Offset(0, h - r),
      Offset(arm, h),
      Offset(0, h - arm),
    );

    // Scan line: 2 high, 12 in from the sides, fades out at both ends.
    final top = 14 + (h - 30) * progress;
    final rect = Rect.fromLTWH(12, top, w - 24, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1)),
      Paint()
        ..shader = LinearGradient(
          colors: [line.withValues(alpha: 0), line, line.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      old.progress != progress || old.corner != corner;
}

/// Dims everything except a centred rounded square.
class _CutoutPainter extends CustomPainter {
  _CutoutPainter({
    required this.color,
    required this.size,
    required this.radius,
  });

  final Color color;
  final double size;
  final double radius;

  @override
  void paint(Canvas canvas, Size box) {
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: box.center(Offset.zero),
        width: size,
        height: size,
      ),
      Radius.circular(radius),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & box)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CutoutPainter old) =>
      old.size != size || old.color != color || old.radius != radius;
}
