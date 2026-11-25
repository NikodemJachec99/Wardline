// Golden tests per widget state (design/handoff/components.md).
// Regenerate after an intended visual change:
//   flutter test --update-goldens test/core/widgets/wl_goldens_test.dart
// Text renders with the test font (blocks), so goldens check layout and
// colour, not glyphs.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/theme.dart';
import 'package:wardline/core/theme/wl_tokens.dart';
import 'package:wardline/core/widgets/wl/wl.dart';

Future<void> _golden(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(390, 600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  testWidgets('WlButton states', (tester) async {
    await _golden(
      tester,
      'wl_button',
      Column(
        spacing: 12,
        children: [
          WlButton(label: 'Primary', onPressed: () {}),
          WlButton(
            label: 'Secondary',
            variant: WlButtonVariant.secondary,
            onPressed: () {},
          ),
          WlButton(
            label: 'Discharge',
            variant: WlButtonVariant.destructive,
            onPressed: () {},
          ),
          WlButton(
            label: 'Text',
            variant: WlButtonVariant.text,
            onPressed: () {},
          ),
          const WlButton(label: 'Disabled (invalid form)'),
          WlButton(
            label: 'Confirm',
            loading: true,
            loadingLabel: 'Saving…',
            onPressed: () {},
          ),
        ],
      ),
    );
  });

  testWidgets('WlStatusChip 4 statuses x md/sm', (tester) async {
    await _golden(
      tester,
      'wl_status_chip',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in PatientStatus.values) ...[
            WlStatusChip(s),
            WlStatusChip(s, size: WlChipSize.sm, short: true),
          ],
        ],
      ),
      size: const Size(390, 240),
    );
  });

  testWidgets('WlPatientCard compact, cached and expanded', (tester) async {
    await _golden(
      tester,
      'wl_patient_card',
      Column(
        spacing: 12,
        children: [
          WlPatientCard.compact(
            name: 'Jan Kowalczyk',
            age: 54,
            status: PatientStatus.inTreatment,
            subtitle: 'Laboratory',
            onTap: () {},
          ),
          WlPatientCard.compact(
            name: 'Maria Wiśniewska',
            age: 71,
            status: PatientStatus.readyForDischarge,
            subtitle: 'Cardiology',
            cachedAsOf: '10:42',
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
        ],
      ),
      size: const Size(390, 800),
    );
  });

  testWidgets('WlKpiCard default, loading, cached', (tester) async {
    await _golden(
      tester,
      'wl_kpi_card',
      ColoredBox(
        color: WlTokens.light.colors.primaryInk,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            spacing: 12,
            children: [
              WlKpiCard(
                label: 'Transfers today',
                value: 42,
                trend: [3, 5, 4, 7, 6, 9],
                delta: '+5 vs last hour',
              ),
              WlKpiCard(label: 'Patients', value: 0, loading: true),
              WlKpiCard(
                label: 'In treatment',
                value: 57,
                cachedSyncedAt: '10:42',
              ),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('WlDeptOccupancyBar low / medium / high', (tester) async {
    await _golden(
      tester,
      'wl_dept_occupancy_bar',
      const Column(
        children: [
          WlDeptOccupancyBar(
            code: 'RAD',
            name: 'Radiology',
            occupied: 6,
            capacity: 12,
          ),
          WlDeptOccupancyBar(
            code: 'CAR',
            name: 'Cardiology',
            occupied: 19,
            capacity: 26,
            selected: true,
          ),
          WlDeptOccupancyBar(
            code: 'INT',
            name: 'Internal Medicine',
            occupied: 29,
            capacity: 32,
            flag: 'Bottleneck',
          ),
        ],
      ),
      size: const Size(390, 260),
    );
  });

  testWidgets('connectivity', (tester) async {
    await _golden(
      tester,
      'wl_connectivity',
      const Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WlOfflineBanner(syncedAt: '10:42'),
          WlOfflineBanner.backOnline(syncedAt: '10:47'),
          WlCacheBadge(syncedAt: '10:42'),
          WlCacheBadge(syncedAt: '10:42', stale: true),
          WlConnectionIndicator(state: WlConnectionState.live),
          WlConnectionIndicator(state: WlConnectionState.offline),
        ],
      ),
      size: const Size(390, 420),
    );
  });

  testWidgets('WlErrorState conflict and WlEmptyState', (tester) async {
    await _golden(
      tester,
      'wl_states',
      Column(
        children: [
          WlErrorState(
            tone: WlErrorTone.warning,
            title: 'Someone moved this patient first',
            body: "Your change wasn't saved.",
            rows: const [
              ('Who', 'Marek Kowal · Nurse'),
              ('When', '10:41'),
              ('Where', 'Laboratory → Cardiology'),
            ],
            primary: WlStateAction('Refresh and choose again', () {}),
          ),
          const WlEmptyState(
            icon: WlIcons.search,
            title: 'No patients match "xyz"',
          ),
        ],
      ),
      size: const Size(390, 760),
    );
  });

  testWidgets('WlBottomNav selected tab and scan button', (tester) async {
    await _golden(
      tester,
      'wl_bottom_nav',
      Align(
        alignment: Alignment.bottomCenter,
        child: WlBottomNav(currentIndex: 1, onTap: (_) {}),
      ),
      size: const Size(390, 200),
    );
  });

  testWidgets('WlTransferPath confirm and pending', (tester) async {
    await _golden(
      tester,
      'wl_transfer_path',
      const Column(
        spacing: 16,
        children: [
          WlTransferPath.big(
            from: 'Laboratory',
            to: 'Radiology',
            fromDetail: 'Floor 0',
            toDetail: 'Floor 0',
            moving: false,
          ),
          WlTransferPath.inline(from: 'Internal Medicine', to: 'Laboratory'),
        ],
      ),
      size: const Size(390, 380),
    );
  });
}
