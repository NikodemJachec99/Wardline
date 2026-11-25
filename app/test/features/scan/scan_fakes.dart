import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';
import 'package:wardline/features/scan/data/nfc_reader.dart';
import 'package:wardline/features/scan/data/qr_source.dart';
import 'package:wardline/features/scan/data/resolve_patient.dart';

import '../../helpers/harness.dart';

/// NFC reader the test drives: [emit] completes the pending read.
class FakeNfcReader implements NfcReader {
  FakeNfcReader({this.support = NfcSupport.ready});

  NfcSupport support;
  int reads = 0;
  int stops = 0;
  String? lastAlert;
  Completer<NfcReadResult>? _pending;

  bool get reading => _pending != null;

  @override
  Future<NfcSupport> availability() async => support;

  @override
  Future<NfcReadResult> readOnce({required String iosAlertMessage}) {
    reads++;
    lastAlert = iosAlertMessage;
    final c = Completer<NfcReadResult>();
    _pending = c;
    return c.future;
  }

  void emit(NfcReadResult result) {
    final c = _pending;
    _pending = null;
    c?.complete(result);
  }

  @override
  Future<void> stop() async {
    stops++;
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete(const NfcReadCancelled());
  }
}

/// Camera stand-in: grey box, codes pushed with [emit].
class FakeQrSource implements QrSource {
  final StreamController<QrScanEvent> _events =
      StreamController<QrScanEvent>.broadcast();
  final ValueNotifier<bool> _torch = ValueNotifier<bool>(false);
  int pauses = 0;
  int resumes = 0;
  bool disposed = false;

  void emit(QrScanEvent e) => _events.add(e);

  @override
  Stream<QrScanEvent> get events => _events.stream;

  @override
  ValueListenable<bool> get torchOn => _torch;

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Color(0xFF4A525C), child: SizedBox.expand());

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<void> toggleTorch() async => _torch.value = !_torch.value;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }
}

/// Scan test rig: the real app (demo data), the scanner opened over the
/// dashboard, fake NFC and camera, clock pinned to 10:46.
class ScanRig {
  ScanRig({
    DemoHospitalRepository? repo,
    FakeNfcReader? reader,
    this.as = 'Anna Nowak',
  }) : repo = repo ?? demoRepository(),
       reader = reader ?? FakeNfcReader();

  final DemoHospitalRepository repo;
  final FakeNfcReader reader;
  final String? as;
  final List<FakeQrSource> qrSources = [];

  FakeQrSource get qr => qrSources.last;

  late ProviderContainer container;

  Future<void> open(
    WidgetTester tester, {
    double textScale = 1,
    bool reduceMotion = false,
    bool online = true,
    String route = Routes.scan,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      appHarness(
        repo: repo,
        as: as,
        overrides: [
          nfcReaderProvider.overrideWithValue(reader),
          qrSourceFactoryProvider.overrideWithValue(() {
            final q = FakeQrSource();
            qrSources.add(q);
            return q;
          }),
          scanClockProvider.overrideWithValue(() => demoNow),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    container = ProviderScope.containerOf(
      tester.element(find.byType(WardlineApp)),
    );
    if (reduceMotion) {
      container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(reduceMotion: true));
    }
    if (!online) {
      await container.read(connectivityProvider.notifier).setOnline(false);
    }
    unawaited(container.read(routerProvider).push(route));
    await settle(tester);
  }

  /// Pumps through route / sheet transitions without waiting for the
  /// infinite ring animation to end.
  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}
