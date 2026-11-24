import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

/// From → To. [WlTransferPath.big] on the confirm screen (moving dot while
/// [moving]), [WlTransferPath.inline] in rows. `to == null` = pending
/// ("Choose department").
class WlTransferPath extends StatefulWidget {
  const WlTransferPath.big({
    required this.from,
    this.to,
    this.fromDetail,
    this.toDetail,
    this.moving = true,
    this.saving = false,
    super.key,
  }) : inline = false;

  const WlTransferPath.inline({required this.from, required this.to, super.key})
    : inline = true,
      fromDetail = null,
      toDetail = null,
      moving = false,
      saving = false;

  final String from;
  final String? to;
  final String? fromDetail;
  final String? toDetail;
  final bool moving;

  /// Faster dot (900ms) while the request is in flight.
  final bool saving;
  final bool inline;

  @override
  State<WlTransferPath> createState() => _WlTransferPathState();
}

class _WlTransferPathState extends State<WlTransferPath>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dot = AnimationController(vsync: this);

  void _sync() {
    final run = widget.moving && !widget.inline && widget.to != null;
    if (!mounted) return;
    if (run && !WlMotion.reduced(context)) {
      _dot.duration = Duration(milliseconds: widget.saving ? 900 : 1600);
      if (!_dot.isAnimating) _dot.repeat();
    } else {
      _dot.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WlTransferPath old) {
    super.didUpdateWidget(old);
    if (old.saving != widget.saving) _dot.stop();
    _sync();
  }

  @override
  void dispose() {
    _dot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final spoken = widget.to == null
        ? 'From ${widget.from}, destination not chosen'
        : 'From ${widget.from} to ${widget.to}';

    if (widget.inline) {
      return Semantics(
        label: spoken,
        excludeSemantics: true,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: t.space.xxs + 2,
          children: [
            Text(
              widget.from,
              style: t.typography.subhead.copyWith(color: c.text),
            ),
            Icon(WlIcons.arrowRight, size: 16, color: c.primary),
            Text(
              widget.to!,
              style: t.typography.subhead.copyWith(
                color: c.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Widget card(String label, String name, String? detail, {required bool to}) {
      final pending = to && widget.to == null;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(t.space.md),
        decoration: BoxDecoration(
          color: to && !pending ? c.primarySoft : c.subtle,
          borderRadius: t.radius.cardBr,
          border: to && !pending
              ? Border.all(color: c.primary, width: 1.5)
              : pending
              ? Border.all(color: c.borderStrong)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: t.typography.overline.copyWith(color: c.textSecondary),
            ),
            SizedBox(height: t.space.xxs),
            Text(
              name,
              style: t.typography.title3.copyWith(
                color: pending ? c.textSecondary : c.text,
              ),
            ),
            if (detail != null)
              Text(
                detail,
                style: t.typography.subhead.copyWith(color: c.textSecondary),
              ),
          ],
        ),
      );
    }

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Column(
        children: [
          card('From', widget.from, widget.fromDetail, to: false),
          SizedBox(
            height: 48,
            child: AnimatedBuilder(
              animation: _dot,
              builder: (context, _) => CustomPaint(
                size: const Size(24, 48),
                painter: _ConnectorPainter(
                  line: c.borderStrong,
                  dot: c.primary,
                  progress: _dot.isAnimating ? _dot.value : null,
                  arrow: widget.to != null,
                ),
              ),
            ),
          ),
          card(
            'To',
            widget.to ?? 'Choose department',
            widget.toDetail,
            to: true,
          ),
        ],
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.line,
    required this.dot,
    required this.progress,
    required this.arrow,
  });

  final Color line;
  final Color dot;
  final double? progress;
  final bool arrow;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final p = Paint()
      ..color = line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var y = 4.0; y < size.height - 8; y += 8) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 3), p);
    }
    if (progress != null) {
      final v = progress!;
      final alpha = v < 0.15 ? v / 0.15 : (v > 0.85 ? (1 - v) / 0.15 : 1.0);
      canvas.drawCircle(
        Offset(x, 4 + (size.height - 12) * Curves.easeInOutCubic.transform(v)),
        5,
        Paint()..color = dot.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    } else if (arrow) {
      final path = Path()
        ..moveTo(x - 6, size.height - 12)
        ..lineTo(x, size.height - 5)
        ..lineTo(x + 6, size.height - 12);
      canvas.drawPath(
        path,
        Paint()
          ..color = dot
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.progress != progress || old.arrow != arrow;
}
