import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/wl_tokens.dart';

/// White section card from the Analytics artboard (radius 16, border,
/// padding 20): title, caption on the right, body.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    required this.title,
    required this.child,
    this.caption,
    this.trailing,
    super.key,
  });

  final String title;
  final String? caption;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      padding: EdgeInsets.all(t.space.lg - t.space.xxs),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: t.radius.cardBr,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.md - 2,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: t.space.sm,
            runSpacing: t.space.xxs,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: t.typography.title3.copyWith(
                    fontSize: 17,
                    color: c.text,
                  ),
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: t.typography
                      .tabular(t.typography.caption)
                      .copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                ),
              ?trailing,
            ],
          ),
          child,
        ],
      ),
    );
  }
}

/// A chart with a one-sentence summary for screen readers and a
/// "Show as table" option (platform-and-a11y.md › Charts).
class ChartCard extends StatefulWidget {
  const ChartCard({
    required this.title,
    required this.summary,
    required this.chart,
    required this.columns,
    required this.rows,
    this.caption,
    this.footnote,
    super.key,
  });

  final String title;
  final String? caption;

  /// "Peak 09:00–10:00 with 11 transfers".
  final String summary;
  final Widget chart;
  final List<String> columns;
  final List<List<String>> rows;
  final String? footnote;

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return AnalyticsCard(
      title: widget.title,
      caption: widget.caption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.sm,
        children: [
          if (_table)
            _DataTable(columns: widget.columns, rows: widget.rows)
          else
            Semantics(
              container: true,
              label: widget.summary,
              image: true,
              excludeSemantics: true,
              child: widget.chart,
            ),
          if (widget.footnote != null && !_table)
            ExcludeSemantics(
              child: Text(
                widget.footnote!,
                style: t.typography.caption.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size(t.space.touchMin, t.space.touchMin),
                foregroundColor: c.primaryInk,
                textStyle: t.typography.subhead.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => setState(() => _table = !_table),
              child: Text(_table ? 'Show as chart' : 'Show as table'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataTable extends StatelessWidget {
  const _DataTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final head = t.typography.overline.copyWith(color: c.textSecondary);
    final cell = t.typography
        .tabular(t.typography.subhead)
        .copyWith(color: c.text);
    Widget pad(Widget w) => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xs,
        vertical: t.space.xs - 2,
      ),
      child: w,
    );
    return Table(
      border: TableBorder(horizontalInside: BorderSide(color: c.border)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            for (final h in columns)
              pad(
                Semantics(
                  header: true,
                  child: Text(h.toUpperCase(), style: head),
                ),
              ),
          ],
        ),
        for (final r in rows)
          TableRow(children: [for (final v in r) pad(Text(v, style: cell))]),
      ],
    );
  }
}

/// Draw-in progress for charts: 0 → 1 over `slow` the first time; static
/// final chart with reduced motion (motion.md › chart draw-in).
class ChartDrawIn extends StatelessWidget {
  const ChartDrawIn({required this.builder, super.key});

  final Widget Function(BuildContext context, double progress) builder;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    if (WlMotion.reduced(context)) return builder(context, 1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: t.motion.slow,
      curve: t.motion.out,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

/// Transfers per hour (Peak hours card): 24 bars, the peak in `primaryInk`,
/// hours still to come as a hairline.
class PeakHoursBars extends StatelessWidget {
  const PeakHoursBars({
    required this.perHour,
    required this.currentHour,
    required this.peak,
    super.key,
  });

  final List<int> perHour;
  final int currentHour;
  final int? peak;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final max = math.max(1, perHour.reduce(math.max));
    const barArea = 128.0;
    final axis = t.typography
        .tabular(t.typography.overline)
        .copyWith(fontWeight: FontWeight.w400, color: c.textSecondary);
    return ChartDrawIn(
      builder: (context, p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.xxs,
        children: [
          if (peak != null)
            LayoutBuilder(
              builder: (context, box) => Padding(
                padding: EdgeInsets.only(
                  left: (box.maxWidth * (peak! + 0.5) / 24 - t.space.lg).clamp(
                    0,
                    math.max(0, box.maxWidth - t.space.xxl - t.space.md),
                  ),
                ),
                child: Text(
                  '${perHour[peak!]} · peak',
                  style: axis.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Container(
            height: barArea + t.space.xs,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 2,
              children: [
                for (var h = 0; h < 24; h++)
                  Expanded(
                    child: Container(
                      height: h > currentHour
                          ? 2
                          : math.max(2, perHour[h] / max * barArea * p),
                      decoration: BoxDecoration(
                        color: h > currentHour
                            ? c.border
                            : h == peak
                            ? c.primaryInk
                            : c.primary.withValues(alpha: .4),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(t.radius.chip / 2 - 1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in ['00', '06', '12', '18', '23'])
                Text(l, style: axis),
            ],
          ),
        ],
      ),
    );
  }
}

/// Patient flow (from → to) as a two-column band diagram.
class FlowDiagram extends StatelessWidget {
  const FlowDiagram({
    required this.sources,
    required this.targets,
    required this.links,
    super.key,
  });

  /// (label, value), top to bottom.
  final List<(String, int)> sources;
  final List<(String, int)> targets;

  /// (source index, target index, value).
  final List<(int, int, int)> links;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return ChartDrawIn(
      builder: (context, p) => SizedBox(
        height: 270,
        child: CustomPaint(
          size: Size.infinite,
          painter: _FlowPainter(
            sources: sources,
            targets: targets,
            links: links,
            progress: p,
            colors: t.colors,
            label: t.typography
                .tabular(t.typography.caption)
                .copyWith(color: t.colors.text, fontWeight: FontWeight.w600),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.sources,
    required this.targets,
    required this.links,
    required this.progress,
    required this.colors,
    required this.label,
    required this.textScaler,
  });

  final List<(String, int)> sources;
  final List<(String, int)> targets;
  final List<(int, int, int)> links;
  final double progress;
  final WlColors colors;
  final TextStyle label;
  final TextScaler textScaler;

  TextPainter _text(String s, double maxWidth) => TextPainter(
    text: TextSpan(text: s, style: label),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: math.max(0, maxWidth));

  @override
  void paint(Canvas canvas, Size size) {
    final total = math.max(1, sources.fold<int>(0, (a, s) => a + s.$2));
    const top = 10.0, gap = 10.0, nodeW = 10.0;
    final gaps = gap * (math.max(sources.length, targets.length) - 1);
    final k = (size.height - top * 2 - gaps) / total;
    final labelW = size.width * .26;
    final lx = labelW + 8;
    final rx = size.width - labelW - 8 - nodeW;

    // Node tops.
    List<double> tops(List<(String, int)> nodes) {
      final out = <double>[];
      var y = top;
      for (final n in nodes) {
        out.add(y);
        y += n.$2 * k + gap;
      }
      return out;
    }

    final ly = tops(sources), ry = tops(targets);
    final lOff = [...ly], rOff = [...ry];
    for (final (a, b, v) in links) {
      final h = v * k;
      final y0 = lOff[a], y1 = rOff[b];
      lOff[a] += h;
      rOff[b] += h;
      final x0 = lx + nodeW;
      final x1 = x0 + (rx - x0) * progress;
      final mx = (x0 + x1) / 2;
      final path = Path()
        ..moveTo(x0, y0)
        ..cubicTo(mx, y0, mx, y1, x1, y1)
        ..lineTo(x1, y1 + h)
        ..cubicTo(mx, y1 + h, mx, y0 + h, x0, y0 + h)
        ..close();
      canvas
        ..drawPath(
          path,
          Paint()..color = colors.primary.withValues(alpha: a == 0 ? .3 : .16),
        )
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = colors.surface,
        );
    }
    final node = Paint()..color = colors.textSecondary;
    for (final (i, n) in sources.indexed) {
      final h = n.$2 * k;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(lx, ly[i], nodeW, h),
          const Radius.circular(3),
        ),
        node,
      );
      final tp = _text('${n.$1} · ${n.$2}', labelW);
      tp.paint(
        canvas,
        Offset(lx - 8 - tp.width, ly[i] + h / 2 - tp.height / 2),
      );
    }
    for (final (i, n) in targets.indexed) {
      final h = n.$2 * k;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rx, ry[i], nodeW, h),
          const Radius.circular(3),
        ),
        node,
      );
      final tp = _text('${n.$1} · ${n.$2}', labelW);
      tp.paint(canvas, Offset(rx + nodeW + 8, ry[i] + h / 2 - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.progress != progress ||
      old.sources != sources ||
      old.targets != targets ||
      old.links != links;
}

/// Diverging bars: patients now vs 07:00 per department.
class DeltaBars extends StatelessWidget {
  const DeltaBars({required this.values, super.key});

  /// (code, delta) in display order.
  final List<(String, int)> values;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final max = math.max(1, values.map((v) => v.$2.abs()).fold(0, math.max));
    final code = t.typography.overline.copyWith(
      letterSpacing: 0,
      color: c.textSecondary,
    );
    final val = t.typography
        .tabular(t.typography.caption)
        .copyWith(color: c.text, fontWeight: FontWeight.w600);
    return ChartDrawIn(
      builder: (context, p) => Column(
        spacing: t.space.xs - 2,
        children: [
          for (final (k, v) in values)
            Row(
              children: [
                SizedBox(
                  width: t.space.xl + 2,
                  child: Text(k, style: code),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: c.borderStrong),
                            ),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: v < 0 ? v.abs() / max * p : 0,
                            child: Container(
                              height: t.space.sm,
                              decoration: BoxDecoration(
                                color: c.status(PatientStatus.discharged).base,
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(t.radius.chip / 2 - 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: v > 0 ? v / max * p : 0,
                            child: Container(
                              height: t.space.sm,
                              decoration: BoxDecoration(
                                color: c.status(PatientStatus.discharged).fg,
                                borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(t.radius.chip / 2 - 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: t.space.xl,
                  child: Text(
                    v > 0
                        ? '+$v'
                        : v < 0
                        ? '−${v.abs()}'
                        : '0',
                    textAlign: TextAlign.right,
                    style: val,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
