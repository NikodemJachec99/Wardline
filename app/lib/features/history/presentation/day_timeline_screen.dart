import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import 'history_data.dart';
import 'history_widgets.dart';

/// `/history/timeline`: today's transfers on a 00–24 axis, one row per
/// destination department (HistoryFlow artboard, "Day timeline").
class DayTimelineScreen extends ConsumerStatefulWidget {
  const DayTimelineScreen({super.key});

  @override
  ConsumerState<DayTimelineScreen> createState() => _DayTimelineScreenState();
}

class _DayTimelineScreenState extends ConsumerState<DayTimelineScreen> {
  bool _showList = false;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = ref.watch(hospitalProvider);
    final now = ref.watch(historyNowProvider)();
    final transfers = transfersOn(s, now);
    final summary = timelineSummary(transfers);
    final count = transfers.length;

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: WlLargeTitle(
                title: "Today's transfers",
                subtitle:
                    '$count ${count == 1 ? 'transfer' : 'transfers'} · '
                    '00:00–24:00',
              ),
            ),
            const SliverToBoxAdapter(child: HistoryConnectionBanner()),
            if (transfers.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: WlEmptyState(
                    icon: WlIcons.timeline,
                    title: 'No transfers today',
                    body:
                        "Transfers show up here as soon as they're confirmed.",
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
                  child: DayTimelineChart(
                    snapshot: s,
                    transfers: transfers,
                    now: now,
                    summary: summary,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space.gutter,
                    t.space.sm - 2,
                    t.space.gutter,
                    0,
                  ),
                  child: Wrap(
                    spacing: t.space.md,
                    runSpacing: t.space.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: t.space.xs - 2),
                          Text('Arrival in department', style: _legend(t)),
                        ],
                      ),
                      Text('Tap a dot for details', style: _legend(t)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: WlButton(
                      label: _showList ? 'Hide list' : 'Show as list',
                      icon: WlIcons.list,
                      variant: WlButtonVariant.text,
                      dense: true,
                      fullWidth: false,
                      onPressed: () => setState(() => _showList = !_showList),
                    ),
                  ),
                ),
              ),
              if (_showList)
                HistoryBox(
                  sliver: SliverList.separated(
                    itemCount: count,
                    separatorBuilder: (context, _) => const HistoryDivider(),
                    itemBuilder: (context, i) {
                      final e = transfers[count - 1 - i];
                      final p = s.patient(e.patientId);
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: t.space.sm - t.space.xxs,
                        ),
                        child: WlActivityFeedItem(
                          actorName: e.byName,
                          actorRole: e.byRole,
                          action: 'moved',
                          patientName: p?.fullName ?? 'Unknown patient',
                          subline:
                              '${deptName(s, e.from)} → ${deptName(s, e.to)}'
                              ' · ${roleLabel(e.byRole)}',
                          timeAgo: hm(e.at),
                          onTap: p == null
                              ? null
                              : () => context.push(Routes.patient(p.id)),
                        ),
                      );
                    },
                  ),
                ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(
                height: t.space.lg + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _legend(WlTokens t) => t.typography.caption.copyWith(
    color: t.colors.textSecondary,
    fontWeight: FontWeight.w400,
  );
}

/// The 00–24 chart: fixed department codes on the left, a horizontally
/// scrolling plot with an hour grid, a "now" marker and one dot per
/// arrival. Tap a dot for the details card.
class DayTimelineChart extends StatefulWidget {
  const DayTimelineChart({
    required this.snapshot,
    required this.transfers,
    required this.now,
    required this.summary,
    super.key,
  });

  final HospitalSnapshot snapshot;
  final List<LocationEvent> transfers;
  final DateTime now;

  /// "Peak 09:00–10:00 with 11 transfers".
  final String summary;

  /// Width of one hour on the plot.
  static const double hourWidth = 40;

  @override
  State<DayTimelineChart> createState() => _DayTimelineChartState();
}

class _DayTimelineChartState extends State<DayTimelineChart> {
  final ScrollController _scroll = ScrollController();
  LocationEvent? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToNow() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final x = _layout.xFor(widget.now);
    _scroll.jumpTo(
      (x - pos.viewportDimension * 0.7).clamp(0.0, pos.maxScrollExtent),
    );
  }

  late DayTimelineLayout _layout;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final scaler = MediaQuery.textScalerOf(context);
    final codes = [for (final d in widget.snapshot.departments) d.code];
    _layout = DayTimelineLayout(
      codes: codes,
      headerHeight: scaler.scale(30).clamp(30.0, 60.0),
      rowHeight: scaler.scale(36).clamp(36.0, 64.0),
      codeWidth: scaler.scale(48).clamp(48.0, 88.0),
    );
    final l = _layout;
    final marks = [
      for (final e in widget.transfers)
        if (codes.contains(e.to)) _Mark(e, l.xFor(e.at), l.yFor(e.to)),
    ];
    final labelStyle = t.typography.overline.copyWith(
      color: c.textSecondary,
      fontWeight: FontWeight.w700,
    );

    return Semantics(
      container: true,
      label: 'Day timeline. ${widget.summary}',
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: t.radius.cardBr,
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.only(bottom: t.space.xxs + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: l.codeWidth,
                child: Column(
                  children: [
                    SizedBox(height: l.headerHeight),
                    for (final code in codes)
                      Container(
                        height: l.rowHeight,
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.only(left: t.space.sm),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: c.subtle)),
                        ),
                        child: Text(code, style: labelStyle),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: l.plotWidth,
                  height: l.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => _onTap(d.localPosition, marks),
                          child: ExcludeSemantics(
                            child: CustomPaint(
                              painter: DayTimelinePainter(
                                layout: l,
                                marks: [for (final m in marks) m.offset],
                                selected: _selected == null
                                    ? null
                                    : marks
                                          .where((m) => m.e == _selected)
                                          .firstOrNull
                                          ?.offset,
                                now: widget.now,
                                grid: c.subtle,
                                gridStrong: c.border,
                                dot: c.primary,
                                dotSelected: c.text,
                                ring: c.surface,
                                nowColor: c.primaryInk,
                                onNow: c.onPrimary,
                                labelStyle: labelStyle,
                                textScaler: scaler,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_selected != null) _tooltip(context, marks, l),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(Offset p, List<_Mark> marks) {
    _Mark? best;
    var bestD = 20.0;
    for (final m in marks) {
      final d = (m.offset - p).distance;
      if (d <= bestD) {
        best = m;
        bestD = d;
      }
    }
    setState(() => _selected = best?.e);
  }

  Widget _tooltip(
    BuildContext context,
    List<_Mark> marks,
    DayTimelineLayout l,
  ) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = widget.snapshot;
    final m = marks.firstWhere((m) => m.e == _selected);
    final e = m.e;
    final p = s.patient(e.patientId);
    const width = 220.0;
    final left = (m.offset.dx - width / 2).clamp(0.0, l.plotWidth - width);
    final below = m.offset.dy < l.height / 2;
    final text = t.typography.caption.copyWith(
      color: c.onPrimary,
      fontWeight: FontWeight.w400,
    );
    final card = Semantics(
      liveRegion: true,
      button: p != null,
      label:
          '${hm(e.at)}, ${p?.fullName ?? 'Unknown patient'}, '
          '${deptName(s, e.from)} to ${deptName(s, e.to)}, '
          'by ${shortStaffName(e.byName)}, ${roleLabel(e.byRole)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: p == null ? null : () => context.push(Routes.patient(p.id)),
        child: Container(
          width: width,
          padding: EdgeInsets.symmetric(
            horizontal: t.space.sm - 2,
            vertical: t.space.xs,
          ),
          decoration: BoxDecoration(
            color: c.text,
            borderRadius: t.radius.inputBr,
            boxShadow: t.elevation.e2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${hm(e.at)} · ${p?.fullName ?? 'Unknown patient'}',
                style: t.typography
                    .tabular(text)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${deptName(s, e.from)} → ${deptName(s, e.to)}',
                style: text,
              ),
              Text(
                '${shortStaffName(e.byName)} · ${roleLabel(e.byRole)}',
                style: text.copyWith(color: c.borderStrong),
              ),
            ],
          ),
        ),
      ),
    );
    return below
        ? Positioned(left: left, top: m.offset.dy + 12, child: card)
        : Positioned(
            left: left,
            bottom: l.height - m.offset.dy + 12,
            child: card,
          );
  }
}

class _Mark {
  _Mark(this.e, double x, double y) : offset = Offset(x, y);

  final LocationEvent e;
  final Offset offset;
}

/// Geometry shared by the painter, the code column and hit testing.
class DayTimelineLayout {
  const DayTimelineLayout({
    required this.codes,
    required this.headerHeight,
    required this.rowHeight,
    required this.codeWidth,
  });

  final List<String> codes;
  final double headerHeight;
  final double rowHeight;
  final double codeWidth;

  static const double padStart = 14;
  static const double padEnd = 18;

  double get plotWidth => padStart + 24 * DayTimelineChart.hourWidth + padEnd;
  double get height => headerHeight + codes.length * rowHeight;

  double xForHour(double h) => padStart + h * DayTimelineChart.hourWidth;

  double xFor(DateTime t) => xForHour(t.hour + t.minute / 60 + t.second / 3600);

  double yFor(String code) =>
      headerHeight + codes.indexOf(code) * rowHeight + rowHeight / 2;
}

/// Hour grid, row lines, arrival dots and the "now" marker.
class DayTimelinePainter extends CustomPainter {
  DayTimelinePainter({
    required DayTimelineLayout layout,
    required this.marks,
    required this.selected,
    required this.now,
    required this.grid,
    required this.gridStrong,
    required this.dot,
    required this.dotSelected,
    required this.ring,
    required this.nowColor,
    required this.onNow,
    required this.labelStyle,
    required this.textScaler,
  }) : _l = layout;

  final DayTimelineLayout _l;
  final List<Offset> marks;
  final Offset? selected;
  final DateTime now;
  final Color grid;
  final Color gridStrong;
  final Color dot;
  final Color dotSelected;
  final Color ring;
  final Color nowColor;
  final Color onNow;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final l = _l;
    final line = Paint()..strokeWidth = 1;

    // Row separators.
    for (var i = 0; i < l.codes.length; i++) {
      final y = l.headerHeight + i * l.rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line..color = grid);
    }

    // Hour grid; labels every 2 hours.
    for (var h = 0; h <= 24; h++) {
      final x = l.xForHour(h.toDouble());
      canvas.drawLine(
        Offset(x, l.headerHeight),
        Offset(x, size.height),
        line..color = h.isEven ? gridStrong : grid,
      );
      if (h.isEven) {
        final tp = TextPainter(
          text: TextSpan(text: h.toString().padLeft(2, '0'), style: labelStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        tp.paint(
          canvas,
          Offset(x - tp.width / 2, (l.headerHeight - tp.height) / 2),
        );
        tp.dispose();
      }
    }

    // Now marker.
    final nx = l.xFor(now);
    canvas.drawRect(
      Rect.fromLTWH(nx - 1, l.headerHeight, 2, size.height - l.headerHeight),
      Paint()..color = nowColor,
    );

    // Dots: 10dp, 2dp surface ring, 1dp outer ring in the dot colour.
    for (final m in marks) {
      final sel = m == selected;
      final color = sel ? dotSelected : dot;
      canvas
        ..drawCircle(m, 6, Paint()..color = color)
        ..drawCircle(m, 5, Paint()..color = ring)
        ..drawCircle(m, 3, Paint()..color = color);
    }

    // Now tag on top of everything in the header.
    final tag = TextPainter(
      text: TextSpan(
        text: hm(now),
        style: labelStyle.copyWith(color: onNow),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final tagRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(nx, l.headerHeight / 2),
        width: tag.width + 12,
        height: tag.height + 6,
      ),
      Radius.circular((tag.height + 6) / 2),
    );
    canvas.drawRRect(tagRect, Paint()..color = nowColor);
    tag.paint(
      canvas,
      Offset(nx - tag.width / 2, (l.headerHeight - tag.height) / 2),
    );
    tag.dispose();
  }

  @override
  bool shouldRepaint(DayTimelinePainter old) =>
      old.marks != marks ||
      old.selected != selected ||
      old.now != now ||
      old.textScaler != textScaler;
}
