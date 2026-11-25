import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:wardline/app/app.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';
import 'package:wardline/domain/models.dart';

/// Fixed "now" matching the design canvas (10:46).
final DateTime demoNow = DateTime(2026, 11, 13, 10, 46);

String sampleJson() => File('assets/demo/sample-data.json').readAsStringSync();

DemoHospitalRepository demoRepository({DateTime? now}) {
  final repo = buildDemoRepository(sampleJson(), now: now ?? demoNow);
  repo.knobs.latency = const Duration(milliseconds: 50);
  return repo;
}

StaffMember staff(DemoHospitalRepository repo, String name) =>
    repo.current.staff.firstWhere((s) => s.name == name);

/// The app with demo data, signed in as [as] (or signed out when null).
Widget appHarness({
  required DemoHospitalRepository repo,
  String? as = 'Anna Nowak',
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      hospitalRepositoryProvider.overrideWithValue(repo),
      if (as != null)
        sessionProvider.overrideWith(() => _SignedIn(staff(repo, as))),
      ...overrides,
    ],
    child: const WardlineApp(),
  );
}

class _SignedIn extends SessionController {
  _SignedIn(this.member);

  final StaffMember member;

  @override
  StaffMember? build() => member;
}
