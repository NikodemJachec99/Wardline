import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/theme.dart';
import 'package:wardline/core/theme/wl_tokens.dart';
import 'package:wardline/core/widgets/wl/wl.dart';

Widget _host(Widget child, {double textScale = 1, bool reduceMotion = false}) {
  return MaterialApp(
    theme: buildTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('WlButton', () {
    testWidgets('calls onPressed once per tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(WlButton(label: 'Confirm transfer', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Confirm transfer'));
      expect(taps, 1);
    });

    testWidgets('loading shows spinner, label and ignores taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          WlButton(
            label: 'Confirm transfer',
            loadingLabel: 'Saving…',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.text('Saving…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Saving…'));
      await tester.tap(find.text('Saving…'));
      expect(taps, 0);
    });

    testWidgets('primary action is at least 56 high', (tester) async {
      await tester.pumpWidget(_host(WlButton(label: 'Go', onPressed: () {})));
      expect(
        tester.getSize(find.byType(WlButton)).height,
        greaterThanOrEqualTo(56),
      );
    });
  });

  group('WlStatusChip', () {
    testWidgets('shows icon + text and reads the full label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const WlStatusChip(
            PatientStatus.readyForDischarge,
            size: WlChipSize.sm,
            short: true,
          ),
        ),
      );
      expect(find.text('Ready'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
      expect(
        find.bySemanticsLabel('Status: Ready for Discharge'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('WlPatientCard', () {
    testWidgets('compact card is one merged button with swipe actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var opened = 0;
      await tester.pumpWidget(
        _host(
          WlPatientCard.compact(
            name: 'Jan Kowalczyk',
            age: 54,
            status: PatientStatus.inTreatment,
            subtitle: 'Laboratory',
            onTap: () => opened++,
            onShowOnMap: () {},
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(WlPatientCard));
      expect(node.label, 'Jan Kowalczyk, 54, Laboratory, In Treatment');
      expect(node.getSemanticsData().customSemanticsActionIds, hasLength(2));
      await tester.tap(find.byType(WlPatientCard));
      expect(opened, 1);
      handle.dispose();
    });

    testWidgets('swipe reveals actions that react to taps', (tester) async {
      var map = 0;
      var opened = 0;
      await tester.pumpWidget(
        _host(
          WlPatientCard.compact(
            name: 'Jan Kowalczyk',
            age: 54,
            status: PatientStatus.inTreatment,
            subtitle: 'Laboratory',
            onTap: () => opened++,
            onShowOnMap: () => map++,
          ),
        ),
      );
      await tester.drag(find.byType(WlPatientCard), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show on map'));
      await tester.pumpAndSettle();
      expect(map, 1);
      expect(opened, 0);
    });

    testWidgets('expanded header keeps status and location separate', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const WlPatientCard.expanded(
            name: 'Jan Kowalczyk',
            age: 54,
            status: PatientStatus.inTreatment,
            patientCode: 'HPT-7K3M9QXA',
            locationName: 'Laboratory',
            locationDetail: 'Floor 0 · since 10:12 · by Anna Nowak',
          ),
        ),
      );
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Last location'), findsOneWidget);
      expect(find.byType(WlStatusChip), findsOneWidget);
    });
  });

  group('WlDeptOccupancyBar', () {
    testWidgets('says the % and level in words', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const WlDeptOccupancyBar(
            code: 'INT',
            name: 'Internal Medicine',
            occupied: 29,
            capacity: 32,
            flag: 'Bottleneck',
          ),
        ),
      );
      expect(find.text('91% · Bottleneck'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Internal Medicine, 29 of 32 beds, 91 percent, bottleneck',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('WlKpiCard', () {
    testWidgets('announces the final value, not count-up frames', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const WlKpiCard(
            label: 'Transfers today',
            value: 42,
            trend: [3, 5, 4, 7, 6, 9],
            delta: '+5 vs last hour',
            deltaSpoken: 'up 5 versus last hour',
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Transfers today, 42, up 5 versus last hour'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reduced motion shows the final value at once', (tester) async {
      await tester.pumpWidget(
        _host(
          const WlKpiCard(label: 'Patients', value: 128),
          reduceMotion: true,
        ),
      );
      expect(find.text('128'), findsOneWidget);
    });
  });

  group('connectivity', () {
    testWidgets('offline banner copy', (tester) async {
      await tester.pumpWidget(_host(const WlOfflineBanner(syncedAt: '10:42')));
      expect(find.text("You're offline"), findsOneWidget);
      expect(
        find.text('Showing data from 10:42. It may be out of date.'),
        findsOneWidget,
      );
    });

    testWidgets('cache badge turns into a warning when stale', (tester) async {
      await tester.pumpWidget(
        _host(const WlCacheBadge(syncedAt: '10:42', stale: true)),
      );
      expect(
        find.text('Cached · synced 10:42 · may be outdated'),
        findsOneWidget,
      );
    });

    testWidgets('connection indicator states', (tester) async {
      for (final (state, label) in [
        (WlConnectionState.live, 'Live'),
        (WlConnectionState.reconnecting, 'Reconnecting…'),
        (WlConnectionState.offline, 'Offline'),
      ]) {
        await tester.pumpWidget(_host(WlConnectionIndicator(state: state)));
        expect(find.text(label), findsOneWidget);
      }
    });
  });

  group('WlTransferPath', () {
    testWidgets('reads From X to Y', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const WlTransferPath.big(
            from: 'Laboratory',
            to: 'Radiology',
            moving: false,
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('From Laboratory to Radiology'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('WlErrorState', () {
    testWidgets('conflict shows who / when / where and one action', (
      tester,
    ) async {
      var refreshed = 0;
      await tester.pumpWidget(
        _host(
          WlErrorState(
            tone: WlErrorTone.warning,
            title: 'Someone moved this patient first',
            body: "Your change wasn't saved.",
            rows: const [
              ('Who', 'Marek Kowal · Nurse'),
              ('When', '10:41'),
              ('Where', 'Laboratory → Cardiology'),
            ],
            primary: WlStateAction(
              'Refresh and choose again',
              () => refreshed++,
            ),
          ),
        ),
      );
      expect(find.text('Marek Kowal · Nurse'), findsOneWidget);
      await tester.tap(find.text('Refresh and choose again'));
      expect(refreshed, 1);
    });
  });

  group('WlFilterChips', () {
    testWidgets('selected chip has a check and count', (tester) async {
      await tester.pumpWidget(
        _host(
          WlFilterChips(
            chips: [
              WlFilterChipData(
                label: 'All',
                count: 128,
                selected: true,
                onTap: () {},
              ),
              WlFilterChipData(
                label: 'Department',
                dropdown: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(WlIcons.check), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(
        tester.getSize(find.byType(InkWell).first).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  testWidgets('text scale 2.0 renders the core widgets without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            WlButton(label: 'Transfer patient', onPressed: () {}),
            const WlStatusChip(PatientStatus.readyForDischarge),
            WlPatientCard.compact(
              name: 'Jan Kowalczyk',
              age: 54,
              status: PatientStatus.inTreatment,
              subtitle: 'Laboratory',
              onTap: () {},
            ),
            const WlPatientCard.expanded(
              name: 'Jan Kowalczyk',
              age: 54,
              status: PatientStatus.inTreatment,
              patientCode: 'HPT-7K3M9QXA',
              locationName: 'Laboratory',
              locationDetail: 'Floor 0 · since 10:12 · by Anna Nowak',
            ),
            const WlDeptOccupancyBar(
              code: 'INT',
              name: 'Internal Medicine',
              occupied: 29,
              capacity: 32,
            ),
            const WlOfflineBanner(syncedAt: '10:42'),
            const WlCacheBadge(syncedAt: '10:42'),
            const WlTimelineItem(
              kind: WlTimelineKind.transfer,
              title: 'Moved to Radiology',
              time: '10:46',
              line: 'Laboratory → Radiology',
              staffName: 'Anna Nowak',
              staffRole: UserRole.nurse,
            ),
            const WlActivityFeedItem(
              actorName: 'Anna Nowak',
              actorRole: UserRole.nurse,
              action: 'moved',
              patientName: 'Jan Kowalczyk',
              subline: 'Laboratory → Radiology',
              timeAgo: 'now',
            ),
          ],
        ),
        textScale: 2,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
