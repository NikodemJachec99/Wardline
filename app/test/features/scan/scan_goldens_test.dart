import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/features/scan/data/nfc_reader.dart';
import 'package:wardline/features/scan/data/qr_source.dart';
import 'package:wardline/features/scan/presentation/scan_copy.dart';

import 'scan_fakes.dart';

/// Key scan states next to their artboards: ScanNfc, ScanSuccess,
/// ScanEdge (invalid tag, camera denied). 390 × 844 like the canvas.
void main() {
  testWidgets('NFC ready (ScanNfc, iOS)', (tester) async {
    final rig = ScanRig();
    await rig.open(tester);
    await tester.pump(const Duration(milliseconds: 1200));
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('goldens/scan_nfc_ready.png'),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('quick summary, nurse (ScanSuccess)', (tester) async {
    final rig = ScanRig();
    await rig.open(tester);
    rig.reader.emit(const NfcReadText('HPT-7K3M9QX2'));
    await ScanRig.settle(tester);
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('goldens/scan_summary_nurse.png'),
    );
  });

  testWidgets('invalid tag (ScanEdge)', (tester) async {
    final rig = ScanRig();
    await rig.open(tester);
    rig.reader.emit(const NfcReadText('not-a-wardline-tag'));
    await ScanRig.settle(tester);
    expect(find.text(ScanCopy.invalidTitle), findsOneWidget);
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('goldens/scan_invalid_tag.png'),
    );
  });

  testWidgets('camera denied (ScanEdge)', (tester) async {
    final rig = ScanRig();
    await rig.open(tester);
    await tester.tap(find.text(ScanCopy.methodQr));
    await ScanRig.settle(tester);
    rig.qr.emit(const QrCameraDenied());
    await ScanRig.settle(tester);
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('goldens/scan_camera_denied.png'),
    );
  });
}
