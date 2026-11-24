import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_skeleton.dart';

/// Dashboard KPI on the glass surface (no BackdropFilter).
class WlKpiCard extends StatelessWidget {
  const WlKpiCard({
    required this.label,
    required this.value,
    this.trend = const [],
    this.delta,
    this.deltaSpoken,
    this.loading = false,
    this.cachedSyncedAt,
    super.key,
  });

  final String label;
  final int value;
  final List<double> trend;

  /// Visible delta, e.g. "+5 vs last hour". Neutral colour.
  final String? delta;

  /// Spoken delta, e.g. "up 5 versus last hour".
  final String? deltaSpoken;
  final bool loading;

  /// Offline: value in secondary + "Synced 10:42".
  final String? cachedSyncedAt;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final cached = cachedSyncedAt != null;
    final reduced = WlMotion.reduced(context);

    final body = loading
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WlSkeleton(width: 72, height: 12),
              SizedBox(height: t.space.sm),
              const WlSkeleton(width: 56, height: 28),
              SizedBox(height: t.space.sm),
              const WlSkeleton(width: 96, height: 12),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                style: t.typography.caption.copyWith(color: c.textSecondary),
              ),
              SizedBox(height: t.space.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<int>(
                      tween: IntTween(begin: reduced ? value : 0, end: value),
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 760),
                      curve: t.motion.out,
                      builder: (context, v, _) => Text(
                        '$v',
                        style: t.typography.kpi.copyWith(
                          color: cached ? c.textSecondary : c.text,
                        ),
                      ),
                    ),
                  ),
                  if (trend.length > 1)
                    SizedBox(
                      width: 64,
                      height: 24,
                      child: CustomPaint(
                        painter: WlSparklinePainter(trend, color: c.primaryInk),
                      ),
                    ),
                ],
              ),
              SizedBox(height: t.space.xxs),
              if (cached)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.warningBg,
                    borderRadius: t.radius.chipBr,
                  ),
                  child: Text(
                    'Synced $cachedSyncedAt',
                    style: t.typography
                        .tabular(t.typography.caption)
                        .copyWith(color: c.warningFg),
                  ),
                )
              else if (delta != null)
                Text(
                  delta!,
                  style: t.typography
                      .tabular(t.typography.caption)
                      .copyWith(color: c.textSecondary),
                ),
            ],
          );

    return Semantics(
      label: loading
          ? '$label, loading'
          : [
              label,
              '$value',
              ?deltaSpoken,
              if (cached) 'cached, synced $cachedSyncedAt',
            ].join(', '),
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(t.space.md - 2),
        decoration: BoxDecoration(
          color: c.glassFill,
          borderRadius: t.radius.cardBr,
          border: Border.all(color: c.glassBorder),
        ),
        child: body,
      ),
    );
  }
}

/// 1.75 stroke line + 14% area. [progress] draws it in (0..1).
class WlSparklinePainter extends CustomPainter {
  WlSparklinePainter(this.values, {required this.color, this.progress = 1});

  final List<double> values;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1 : maxV - minV;
    final dx = size.width / (values.length - 1);
    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * dx,
          size.height - 2 - (values[i] - minV) / span * (size.height - 4),
        ),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final metric = line.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    if (progress >= 1) {
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.14));
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(WlSparklinePainter old) =>
      old.values != values || old.progress != progress || old.color != color;
}
