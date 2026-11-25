import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../map/presentation/map_data.dart';
import 'analytics_data.dart';
import 'analytics_widgets.dart';

/// Analytics (tablet ≥ 900dp; Analytics artboard). Phones stack the same
/// blocks. Read-only.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  /// Tablet layout from this width (platform-and-a11y.md).
  static const double tabletWidth = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = ref.watch(hospitalProvider);
    final conn = ref.watch(connectivityProvider);
    final day = AnalyticsDay.of(s);
    final names = {for (final d in s.departments) d.code: d.shortName};

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= tabletWidth;
            final gap = t.space.md;
            final pad = wide ? t.space.xl : t.space.gutter;

            Widget pair(Widget a, Widget b, {int fa = 8, int fb = 4}) => wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: gap,
                    children: [
                      Expanded(flex: fa, child: a),
                      Expanded(flex: fb, child: b),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: gap,
                    children: [a, b],
                  );

            final emptyDay = day.transfers.isEmpty;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                0,
                0,
                0,
                MediaQuery.paddingOf(context).bottom + t.space.xl,
              ),
              children: [
                WlLargeTitle(
                  title: 'Analytics',
                  subtitle: '${longDate(day.now)} · ${hm(day.now)}',
                  trailing: [WlConnectionIndicator(state: conn.state)],
                ),
                if (!conn.online) WlOfflineBanner(syncedAt: hm(conn.syncedAt)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: gap,
                    children: [
                      _Grid(
                        columns: wide ? 4 : 2,
                        gap: gap,
                        children: _kpis(day),
                      ),
                      pair(
                        _OccupancyCard(day: day, names: names, wide: wide),
                        _BottlenecksCard(day: day),
                      ),
                      if (emptyDay)
                        const AnalyticsCard(
                          title: 'Patient flow today',
                          child: _EmptyDay(),
                        )
                      else
                        pair(_flowCard(day, names), _NfcQrCard(day: day)),
                      if (!emptyDay)
                        pair(
                          _peakCard(day),
                          _deltaCard(day, s.departments.map((d) => d.code)),
                          fa: 7,
                          fb: 5,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _kpis(AnalyticsDay day) {
    final peak = day.peakHour;
    final ch = day.changeSince7;
    return [
      _KpiTile(
        label: 'Patients in house',
        value: '${day.patientsInHouse}',
        sub: '${ch >= 0 ? '+' : '−'}${ch.abs()} since 07:00',
      ),
      _KpiTile(
        label: 'Bed occupancy',
        value: '${day.occupancyPercent}%',
        sub: '${day.occupied} of ${day.beds} beds',
      ),
      _KpiTile(
        label: 'Transfers today',
        value: '${day.transfers.length}',
        sub: peak == null
            ? 'No transfers yet'
            : 'peak ${hourRange(peak)} · ${day.perHour[peak]}',
      ),
      _KpiTile(
        label: 'Avg. stay · wards',
        value: day.wardStay == null ? '–' : stayLabel(day.wardStay!),
        sub: '${day.wardCount} inpatient wards',
      ),
    ];
  }

  Widget _flowCard(AnalyticsDay day, Map<String, String> names) {
    String n(String code) => names[code] ?? code;
    final bySource = <String, int>{};
    final byTarget = <String, int>{};
    day.flows.forEach((k, v) {
      bySource[k.$1] = (bySource[k.$1] ?? 0) + v;
      byTarget[k.$2] = (byTarget[k.$2] ?? 0) + v;
    });
    List<String> top(Map<String, int> m, int count) {
      final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return [for (final x in e.take(count)) x.key];
    }

    final srcKeys = top(bySource, 3);
    final dstKeys = top(byTarget, 4);
    const other = 'Other wards';
    int si(String code) {
      final i = srcKeys.indexOf(code);
      return i < 0 ? srcKeys.length : i;
    }

    int di(String code) {
      final i = dstKeys.indexOf(code);
      return i < 0 ? dstKeys.length : i;
    }

    final srcVals = List<int>.filled(srcKeys.length + 1, 0);
    final dstVals = List<int>.filled(dstKeys.length + 1, 0);
    final linkMap = <(int, int), int>{};
    day.flows.forEach((k, v) {
      final a = si(k.$1), b = di(k.$2);
      srcVals[a] += v;
      dstVals[b] += v;
      linkMap[(a, b)] = (linkMap[(a, b)] ?? 0) + v;
    });
    final sources = [
      for (final (i, k) in srcKeys.indexed) (n(k), srcVals[i]),
      if (srcVals.last > 0) (other, srcVals.last),
    ];
    final targets = [
      for (final (i, k) in dstKeys.indexed) (n(k), dstVals[i]),
      if (dstVals.last > 0) (other, dstVals.last),
    ];
    final links =
        [for (final e in linkMap.entries) (e.key.$1, e.key.$2, e.value)]
          ..sort((a, b) {
            final c = a.$1.compareTo(b.$1);
            return c != 0 ? c : a.$2.compareTo(b.$2);
          });
    final rows = day.flows.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFlow = rows.first;
    return ChartCard(
      title: 'Patient flow today',
      caption: '${day.transfers.length} transfers · from → to',
      summary:
          '${day.transfers.length} transfers today. Most patients came from '
          '${sources.first.$1}; the busiest move was ${n(topFlow.key.$1)} to '
          '${n(topFlow.key.$2)} with ${topFlow.value}.',
      chart: FlowDiagram(sources: sources, targets: targets, links: links),
      footnote: 'Left: where patients came from · Right: where they went',
      columns: const ['From', 'To', 'Transfers'],
      rows: [
        for (final r in rows) [n(r.key.$1), n(r.key.$2), '${r.value}'],
      ],
    );
  }

  Widget _peakCard(AnalyticsDay day) {
    final peak = day.peakHour!;
    final hour = day.now.hour;
    return ChartCard(
      title: 'Peak hours',
      caption: 'Transfers per hour',
      summary: 'Peak ${hourRange(peak)} with ${day.perHour[peak]} transfers',
      chart: PeakHoursBars(perHour: day.perHour, currentHour: hour, peak: peak),
      footnote: '${hourRange(peak)} had the most moves.',
      columns: const ['Hour', 'Transfers'],
      rows: [
        for (var h = 0; h <= hour; h++)
          [
            hourRange(h),
            h == hour ? '${day.perHour[h]} (so far)' : '${day.perHour[h]}',
          ],
      ],
    );
  }

  Widget _deltaCard(AnalyticsDay day, Iterable<String> codes) {
    final values = [for (final c in codes) (c, day.deltaSince7[c] ?? 0)];
    final total = values.fold<int>(0, (a, v) => a + v.$2);
    final rise = values.reduce((a, b) => b.$2 > a.$2 ? b : a);
    final sign = total >= 0 ? '+' : '−';
    return ChartCard(
      title: 'Now vs 07:00',
      caption: 'Patients, by department',
      summary:
          'Since 07:00, $sign${total.abs()} patients overall'
          '${rise.$2 > 0 ? '. Biggest rise: ${rise.$1} +${rise.$2}' : ''}.',
      chart: DeltaBars(values: values),
      footnote: '$sign${total.abs()} patients since 07:00',
      columns: const ['Department', 'Change'],
      rows: [
        for (final (k, v) in values) [k, v > 0 ? '+$v' : '$v'],
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.gap,
    required this.children,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final cols = large ? math.max(1, columns ~/ 2) : columns;
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.sub});

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      container: true,
      label: '$label, $value, $sub',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(t.space.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: t.radius.cardBr,
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: t.space.xxs,
          children: [
            Text(
              label,
              style: t.typography.subhead.copyWith(
                fontSize: 13,
                color: c.textSecondary,
              ),
            ),
            Text(value, style: t.typography.kpi.copyWith(color: c.text)),
            Text(
              sub,
              style: t.typography
                  .tabular(t.typography.caption)
                  .copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({
    required this.day,
    required this.names,
    required this.wide,
  });

  final AnalyticsDay day;
  final Map<String, String> names;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final hourAgo = day.now.subtract(const Duration(hours: 1));
    final recent = day.transfers.where((e) => e.at.isAfter(hourAgo));
    final latest = day.latest;
    return AnalyticsCard(
      title: 'Occupancy & live movement',
      caption: 'Arrows = in / out in the last hour',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.md - 2,
        children: [
          _Grid(
            columns: wide ? 4 : 2,
            gap: t.space.sm - 2,
            children: [
              for (final o in day.departments)
                _OccTile(
                  occupancy: o,
                  inHour: recent.where((e) => e.to == o.department.code).length,
                  outHour: recent
                      .where((e) => e.from == o.department.code)
                      .length,
                  live: latest?.to == o.department.code,
                ),
            ],
          ),
          if (latest != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: t.space.xs,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: t.space.xs - 2),
                  child: Container(
                    width: t.space.xs,
                    height: t.space.xs,
                    decoration: BoxDecoration(
                      color: c.primaryInk,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final p = ref.watch(patientProvider(latest.patientId));
                      return Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Now: ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text:
                                  '${p?.fullName ?? 'A patient'} arrived in '
                                  '${names[latest.to] ?? latest.to} from '
                                  '${names[latest.from] ?? latest.from} · '
                                  '${hm(latest.at)}',
                            ),
                          ],
                        ),
                        style: t.typography
                            .tabular(t.typography.subhead)
                            .copyWith(fontSize: 13, color: c.text),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OccTile extends StatelessWidget {
  const _OccTile({
    required this.occupancy,
    required this.inHour,
    required this.outHour,
    required this.live,
  });

  final DeptOccupancy occupancy;
  final int inHour;
  final int outHour;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final o = occupancy;
    final st = c.occupancy(o.percent);
    final low = st.level == OccupancyLevel.low;
    final small = t.typography
        .tabular(t.typography.overline)
        .copyWith(letterSpacing: 0, fontWeight: FontWeight.w400);
    return Semantics(
      container: true,
      label:
          '${o.spoken}. Last hour: $inHour in, $outHour out'
          '${live ? '. Latest arrival' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.sm,
          vertical: t.space.sm - 2,
        ),
        decoration: BoxDecoration(
          color: low ? c.surface : st.tint,
          borderRadius: t.radius.inputBr,
          border: Border.all(
            color: live
                ? c.primaryInk
                : low
                ? c.border
                : st.fill,
          ),
          boxShadow: live
              ? [BoxShadow(color: c.primarySoft, spreadRadius: 2)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: t.space.xs - 2,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.department.code,
                    style: t.typography.caption.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${o.percent}%',
                  style: t.typography
                      .tabular(t.typography.caption)
                      .copyWith(color: c.text, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              o.department.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.typography.subhead.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.text,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(t.radius.full),
              child: SizedBox(
                height: t.space.xs - 2,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: c.subtle)),
                    FractionallySizedBox(
                      widthFactor: (o.percent / 100).clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: ColoredBox(color: st.fill),
                    ),
                  ],
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: t.space.xs,
              children: [
                Text(
                  '${o.occupied}/${o.beds}',
                  style: small.copyWith(color: c.textSecondary),
                ),
                Text(
                  '↓$outHour ↑$inHour',
                  style: small.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottlenecksCard extends StatelessWidget {
  const _BottlenecksCard({required this.day});

  final AnalyticsDay day;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final list = day.bottlenecks;
    return AnalyticsCard(
      title: 'Bottlenecks',
      caption: 'Over 85%',
      child: list.isEmpty
          ? Text(
              'No department is over 85%.',
              style: t.typography.subhead.copyWith(color: c.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, o) in list.indexed)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: t.space.sm),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(top: BorderSide(color: c.border)),
                    ),
                    child: Semantics(
                      container: true,
                      label: o.spoken,
                      excludeSemantics: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: t.space.sm,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: t.space.xxs / 2),
                            child: Icon(
                              WlIcons.alert,
                              size: t.space.md,
                              color: c.dangerPressed,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text: o.department.name,
                                    children: [
                                      TextSpan(
                                        text:
                                            ' · ${o.occupied}/${o.beds} · ${o.percent}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: t.typography
                                      .tabular(t.typography.callout)
                                      .copyWith(
                                        color: c.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Text(
                                  o.full
                                      ? 'Full · no free beds.'
                                      : '${o.free} free ${o.free == 1 ? 'bed' : 'beds'} left.',
                                  style: t.typography.subhead.copyWith(
                                    fontSize: 13,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _NfcQrCard extends StatelessWidget {
  const _NfcQrCard({required this.day});

  final AnalyticsDay day;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final total = day.nfc + day.qr;
    final nfcPct = total == 0 ? 0 : (day.nfc * 100 / total).round();
    final qrPct = total == 0 ? 0 : 100 - nfcPct;
    final qrColor = c.status(PatientStatus.admitted).base;
    Widget legend(String label, Color color, int n, int pct, bool end) =>
        Column(
          crossAxisAlignment: end
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: t.space.xs - 2,
              children: [
                Container(
                  width: t.space.sm - 2,
                  height: t.space.sm - 2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(t.space.xxs - 1),
                  ),
                ),
                Text(
                  label,
                  style: t.typography.subhead.copyWith(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
            Text.rich(
              TextSpan(
                text: '$n ',
                children: [
                  TextSpan(
                    text: '· $pct%',
                    style: t.typography.subhead.copyWith(
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
              style: t.typography
                  .tabular(t.typography.title2)
                  .copyWith(color: c.text),
            ),
          ],
        );
    return AnalyticsCard(
      title: 'NFC vs QR',
      caption: '$total identifications today',
      child: Semantics(
        container: true,
        label:
            'NFC wristband $nfcPct percent, ${day.nfc}; QR code $qrPct percent, ${day.qr}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: t.space.sm,
          children: [
            SizedBox(
              height: t.space.xl - t.space.xxs,
              child: Row(
                spacing: 2,
                children: [
                  if (day.nfc > 0)
                    Expanded(
                      flex: math.max(1, day.nfc),
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(t.radius.chip - 2),
                            right: day.qr == 0
                                ? Radius.circular(t.radius.chip - 2)
                                : Radius.zero,
                          ),
                        ),
                      ),
                    ),
                  if (day.qr > 0)
                    Expanded(
                      flex: math.max(1, day.qr),
                      child: Container(
                        decoration: BoxDecoration(
                          color: qrColor,
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(t.radius.chip - 2),
                            left: day.nfc == 0
                                ? Radius.circular(t.radius.chip - 2)
                                : Radius.zero,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: t.space.md,
              runSpacing: t.space.xs,
              children: [
                legend('NFC wristband', c.primary, day.nfc, nfcPct, false),
                legend('QR code', qrColor, day.qr, qrPct, true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Text(
      'No transfers yet today',
      style: t.typography.subhead.copyWith(color: t.colors.textSecondary),
    );
  }
}
