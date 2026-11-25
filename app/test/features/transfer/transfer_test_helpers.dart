import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';
import 'package:wardline/data/demo/demo_seed.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/patients/presentation/patient_profile_screen.dart';

import '../../helpers/harness.dart';

/// Jan Kowalczyk (sample data): Laboratory, In Treatment.
const String janId = 'p-HPT-7K3M9QX2';

/// Demo repository with a fixed clock (10:46, like the canvas) that records
/// every write RPC and its client_request_id.
class RecordingRepository extends DemoHospitalRepository {
  factory RecordingRepository() => RecordingRepository._(_Clock());

  RecordingRepository._(this._clock)
    : super(
        DemoSeed.fromJson(sampleJson(), now: demoNow),
        clock: () => _clock.now,
      ) {
    knobs.latency = const Duration(milliseconds: 50);
  }

  final _Clock _clock;
  bool _designConflictNext = false;

  /// The canvas conflict (prototypeScenarios.conflict): right before our
  /// write lands, Marek Kowal moves Jan from Laboratory to Cardiology at
  /// 10:41.
  void designConflictNext() => _designConflictNext = true;

  final List<String> transferRequestIds = [];
  final List<String> statusRequestIds = [];

  @override
  Future<LocationEvent> transferPatient({
    required String patientId,
    required String to,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? identifiedBy,
  }) {
    transferRequestIds.add(requestId);
    if (_designConflictNext) {
      _designConflictNext = false;
      _clock.now = demoNow.subtract(const Duration(minutes: 5));
      simulateRemoteTransfer(patientId: patientId, to: 'CAR');
      _clock.now = demoNow;
    }
    return super.transferPatient(
      patientId: patientId,
      to: to,
      expectedVersion: expectedVersion,
      requestId: requestId,
      by: by,
      identifiedBy: identifiedBy,
    );
  }

  @override
  Future<StatusEvent> setPatientStatus({
    required String patientId,
    required PatientStatus status,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? reason,
  }) {
    statusRequestIds.add(requestId);
    return super.setPatientStatus(
      patientId: patientId,
      status: status,
      expectedVersion: expectedVersion,
      requestId: requestId,
      by: by,
      reason: reason,
    );
  }

  int eventsFor(String patientId) =>
      current.events.where((e) => e.patientId == patientId).length;

  Patient get jan => current.patient(janId)!;
}

class _Clock {
  DateTime now = demoNow;
}

/// Phone-sized app signed in as [as].
Future<void> pumpApp(
  WidgetTester tester,
  RecordingRepository repo, {
  String as = 'Anna Nowak',
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(appHarness(repo: repo, as: as));
  await settle(tester);
}

/// pumpAndSettle without hanging on looping animations (moving dot,
/// spinner, live pulse).
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(WardlineApp)));

GoRouter routerOf(WidgetTester tester) =>
    containerOf(tester).read(routerProvider);

String locationOf(WidgetTester tester) =>
    routerOf(tester).routerDelegate.currentConfiguration.uri.toString();

/// Opens Jan's profile route (the screen the actions start from).
Future<BuildContext> openJanProfile(WidgetTester tester) async {
  unawaited(routerOf(tester).push(Routes.patient(janId)));
  await settle(tester);
  return tester.element(find.byType(PatientProfileScreen));
}

/// Goes straight to the confirm screen for Jan → [to].
Future<void> openConfirm(WidgetTester tester, {String to = 'RAD'}) async {
  unawaited(routerOf(tester).push(Routes.transferConfirm(janId, to)));
  await settle(tester);
}

Finder get confirmButton => find.byKey(const ValueKey('transfer-confirm'));
