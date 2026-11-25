import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/theme.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/patients/presentation/patient_profile_sections.dart';

import '../../helpers/harness.dart';
import 'patients_test_utils.dart';

// Patient timeline (#40): order by server time, transfer rows, and the
// animated expand of the details.

const _transfer = WlTimelineItem(
  kind: WlTimelineKind.transfer,
  title: 'Transferred',
  time: '10:31',
  line: 'Internal Medicine → Laboratory',
  staffName: 'Ewa Lis',
  staffRole: UserRole.nurse,
  details: [
    ('From', 'Internal Medicine · Floor 1'),
    ('To', 'Laboratory · Ground'),
    ('Server confirmed', '10:31:07'),
  ],
);

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: buildTheme(),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

/// Height factor of the details (null = details not in the tree).
double? _detailsOpen(WidgetTester tester) {
  final f = find.descendant(
    of: find.byType(WlTimelineItem),
    matching: find.byType(SizeTransition),
  );
  if (f.evaluate().isEmpty) return null;
  return tester.widget<SizeTransition>(f).sizeFactor.value;
}

void main() {
  group('buildTimeline order', () {
    final snap = demoRepository().current;
    final jan = snap.patient(janId)!;
    final history = snap.historyFor(janId);

    List<WlTimelineItem> build(List<HistoryEvent> h) => buildTimeline(
      snapshot: snap,
      patient: jan,
      history: h,
      highlight: const {},
    );

    test('newest first by server time, whatever the input order', () {
      final expected = build(history).map((i) => i.time).toList();
      expect(expected, ['10:31', '09:52', '09:35', '08:47', '08:12']);
      expect(
        build(history.reversed.toList()).map((i) => i.time).toList(),
        expected,
      );
      final shuffled = [...history]..shuffle();
      expect(build(shuffled).map((i) => i.time).toList(), expected);
    });

    test('"Time in previous dept" still uses the right earlier transfer', () {
      final first = build(history.reversed.toList()).first;
      final details = {for (final (k, v) in first.details) k: v};
      expect(details['Time in previous dept'], '56 min');
    });

    test('equal times: transfer before status change, then by id', () {
      final at = DateTime(2026, 11, 13, 10);
      LocationEvent move(String id) => LocationEvent(
        id: id,
        patientId: janId,
        at: at,
        byName: 'Ewa Lis',
        byRole: UserRole.nurse,
        from: 'INT',
        to: 'LAB',
      );
      final status = StatusEvent(
        id: 'a-status',
        patientId: janId,
        at: at,
        byName: 'Dr Piotr Zając',
        byRole: UserRole.doctor,
        from: PatientStatus.admitted,
        to: PatientStatus.inTreatment,
      );
      final rows = build([status, move('t-2'), move('t-1')]);
      expect(rows.map((r) => (r.key! as ValueKey<String>).value), [
        't-1',
        't-2',
        'a-status',
      ]);
    });

    test('the input list is not modified', () {
      final input = history.reversed.toList();
      final before = input.map((e) => e.id).toList();
      build(input);
      expect(input.map((e) => e.id), before);
    });
  });

  group('transfer row', () {
    testWidgets('shows from → to, time and the actor initials and role', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_transfer));
      expect(find.text('Internal Medicine → Laboratory'), findsOneWidget);
      expect(find.text('10:31'), findsOneWidget);
      final avatar = tester.widget<WlInitialsAvatar>(
        find.byType(WlInitialsAvatar),
      );
      expect(avatar.name, 'Ewa Lis');
      expect(avatar.role, UserRole.nurse);
      expect(find.text('EL'), findsOneWidget);
      expect(find.textContaining('Nurse', findRichText: true), findsOneWidget);
    });
  });

  group('expand', () {
    testWidgets('details open and close with an animation', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(_transfer));
      expect(_detailsOpen(tester), isNull);
      expect(find.text('Server confirmed'), findsNothing);

      await tester.tap(find.text('Transferred'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_detailsOpen(tester), inExclusiveRange(0, 1));
      expect(find.text('Server confirmed'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Transferred')),
        isSemantics(isExpanded: true, hasExpandedState: true),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(_detailsOpen(tester), 1);

      await tester.tap(find.text('Transferred'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_detailsOpen(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 200));
      expect(_detailsOpen(tester), isNull, reason: 'closed = not in the tree');
      expect(find.text('Server confirmed'), findsNothing);
      handle.dispose();
    });

    testWidgets('reduced motion: opens and closes at once', (tester) async {
      await tester.pumpWidget(_host(_transfer, reduceMotion: true));
      await tester.tap(find.text('Transferred'));
      await tester.pump();
      expect(_detailsOpen(tester), 1);
      expect(find.text('Server confirmed'), findsOneWidget);

      await tester.tap(find.text('Transferred'));
      await tester.pump();
      expect(_detailsOpen(tester), isNull);
    });

    testWidgets('an entry without details does not expand', (tester) async {
      await tester.pumpWidget(
        _host(
          const WlTimelineItem(
            kind: WlTimelineKind.admission,
            title: 'Admitted',
            time: '08:12',
            staffName: 'Marek Kowal',
            staffRole: UserRole.nurse,
          ),
        ),
      );
      await tester.tap(find.text('Admitted'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_detailsOpen(tester), isNull);
    });
  });
}
