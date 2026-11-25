import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';
import 'package:wardline/data/hospital_repository.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/dashboard/application/clock.dart';

import '../../helpers/harness.dart';

export 'package:wardline/core/format.dart' show hm;

/// The app on the design clock (10:46), signed in as [as].
Widget dashboardApp({
  required HospitalRepository repo,
  String? as = 'Anna Nowak',
  StaffMember? member,
  List<Override> overrides = const [],
}) {
  final who =
      member ??
      (as == null || repo is! DemoHospitalRepository ? null : staff(repo, as));
  return ProviderScope(
    overrides: [
      hospitalRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => demoNow),
      if (who != null) sessionProvider.overrideWith(() => SignedInAs(who)),
      ...overrides,
    ],
    child: const WardlineApp(),
  );
}

class SignedInAs extends SessionController {
  SignedInAs(this.member);

  final StaffMember member;

  @override
  StaffMember? build() => member;
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(WardlineApp)));

/// Phone-sized surface; tall enough to build the whole dashboard.
void usePhone(WidgetTester tester, {Size size = const Size(390, 2100)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps the dashboard past the stagger and the 760ms count-up. Never
/// `pumpAndSettle`: the live pulse loops.
Future<void> pumpDashboard(
  WidgetTester tester, {
  required HospitalRepository repo,
  String? as = 'Anna Nowak',
  double textScale = 1,
  Size size = const Size(390, 2100),
}) async {
  usePhone(tester, size: size);
  final member = repo is EmptyHospitalRepository
      ? const StaffMember(
          id: 'staff-0',
          name: 'Anna Nowak',
          role: UserRole.nurse,
          homeDepartment: 'INT',
          shiftLabel: 'Day shift 07:00–19:00',
        )
      : null;
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(dashboardApp(repo: repo, as: as, member: member));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
}

/// System "reduce motion" on for this test.
void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// No data yet (first load): the dashboard shows skeleton KPIs.
class EmptyHospitalRepository implements HospitalRepository {
  @override
  HospitalSnapshot get current => HospitalSnapshot(
    departments: const [],
    staff: const [],
    patients: const [],
    events: const [],
    syncedAt: demoNow,
  );

  @override
  Stream<HospitalSnapshot> watch() => Stream.value(current);

  @override
  Future<Patient?> findByCode(String code) async => null;

  @override
  Future<void> refresh() async {}

  @override
  Future<LocationEvent> transferPatient({
    required String patientId,
    required String to,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? identifiedBy,
  }) => Completer<LocationEvent>().future;

  @override
  Future<StatusEvent> setPatientStatus({
    required String patientId,
    required PatientStatus status,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? reason,
  }) => Completer<StatusEvent>().future;

  @override
  void dispose() {}
}
