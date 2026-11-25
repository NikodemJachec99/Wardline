import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/features/patients/presentation/patient_profile_screen.dart';
import 'package:wardline/features/scan/data/nfc_reader.dart';
import 'package:wardline/features/scan/data/qr_source.dart';
import 'package:wardline/features/scan/presentation/scan_copy.dart';
import 'package:wardline/features/scan/presentation/scan_screen.dart';
import 'package:wardline/features/scan/presentation/widgets/scan_sheets.dart';

import 'scan_fakes.dart';

const String janCode = 'HPT-7K3M9QX2';

void main() {
  group('NFC (Android: listens at once)', () {
    testWidgets('read OK shows the quick summary and writes nothing', (
      tester,
    ) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final rig = ScanRig();
      final eventsBefore = rig.repo.current.events.length;
      final versionBefore = rig.repo.current.patients
          .firstWhere((p) => p.code == janCode)
          .version;
      await rig.open(tester);

      expect(find.byType(ScanScreen), findsOneWidget);
      expect(find.text(ScanCopy.title), findsOneWidget);
      expect(find.text(ScanCopy.rule), findsOneWidget);
      expect(find.text(ScanCopy.holdHintAndroid), findsOneWidget);
      expect(find.text(ScanCopy.start), findsNothing);
      expect(rig.reader.reads, 1, reason: 'Android listens immediately');

      rig.reader.emit(const NfcReadText('$janCode\n'));
      await ScanRig.settle(tester);

      expect(find.byType(ScanSummarySheet), findsOneWidget);
      expect(find.text(ScanCopy.identified), findsOneWidget);
      expect(find.text('Jan Kowalczyk'), findsOneWidget);
      expect(find.textContaining(janCode, findRichText: true), findsOneWidget);
      expect(find.text('NFC · 10:46'), findsOneWidget);
      expect(find.text('Laboratory'), findsOneWidget);
      expect(find.byType(WlStatusChip), findsOneWidget);
      expect(find.text(ScanCopy.viewProfile), findsOneWidget);
      expect(find.text(ScanCopy.transfer), findsOneWidget);
      expect(find.text(ScanCopy.changeStatus), findsNothing);
      expect(haptics, contains('HapticFeedbackType.mediumImpact'));

      // Flow 1 step 3: no write has happened.
      expect(rig.repo.current.events.length, eventsBefore);
      expect(
        rig.repo.current.patients.firstWhere((p) => p.code == janCode).version,
        versionBefore,
      );
    });

    testWidgets('doctor gets "Change status →" and no transfer', (
      tester,
    ) async {
      final rig = ScanRig(as: 'Dr Piotr Zając');
      await rig.open(tester);
      rig.reader.emit(const NfcReadText(janCode));
      await ScanRig.settle(tester);

      expect(find.text(ScanCopy.changeStatus), findsOneWidget);
      expect(find.text(ScanCopy.transfer), findsNothing);
      expect(
        find.text('${ScanCopy.nothingChanged} ${ScanCopy.doctorHint}'),
        findsOneWidget,
      );
    });

    testWidgets('admin gets neither role action, only the profile', (
      tester,
    ) async {
      final rig = ScanRig(as: 'Katarzyna Wilk');
      await rig.open(tester);
      rig.reader.emit(const NfcReadText(janCode));
      await ScanRig.settle(tester);

      expect(find.text(ScanCopy.viewProfile), findsOneWidget);
      expect(find.text(ScanCopy.transfer), findsNothing);
      expect(find.text(ScanCopy.changeStatus), findsNothing);
      expect(find.text(ScanCopy.nothingChanged), findsOneWidget);
    });

    testWidgets('offline: the role action is replaced, not disabled', (
      tester,
    ) async {
      final rig = ScanRig();
      await rig.open(tester, online: false);
      rig.reader.emit(const NfcReadText(janCode));
      await ScanRig.settle(tester);

      expect(find.text('Jan Kowalczyk'), findsOneWidget);
      expect(find.text(ScanCopy.transfer), findsNothing);
      expect(find.byType(WlOfflineActionNote), findsOneWidget);
      expect(find.text(ScanCopy.viewProfile), findsOneWidget);
    });

    testWidgets('View profile opens the patient record', (tester) async {
      final rig = ScanRig();
      await rig.open(tester);
      rig.reader.emit(const NfcReadText(janCode));
      await ScanRig.settle(tester);

      await tester.tap(find.text(ScanCopy.viewProfile));
      await ScanRig.settle(tester);
      expect(find.byType(PatientProfileScreen), findsOneWidget);
    });

    testWidgets('dismissing the summary listens again', (tester) async {
      final rig = ScanRig();
      await rig.open(tester);
      rig.reader.emit(const NfcReadText(janCode));
      await ScanRig.settle(tester);
      expect(find.byType(ScanSummarySheet), findsOneWidget);

      await tester.tapAt(const Offset(195, 80)); // scrim
      await ScanRig.settle(tester);
      expect(find.byType(ScanSummarySheet), findsNothing);
      expect(rig.reader.reads, 2);
    });

    testWidgets('invalid tag: text without a Wardline ID', (tester) async {
      final rig = ScanRig();
      await rig.open(tester);
      rig.reader.emit(const NfcReadText('https://example.com/menu'));
      await ScanRig.settle(tester);

      expect(find.text(ScanCopy.invalidTitle), findsOneWidget);
      expect(find.text(ScanCopy.invalidBody), findsOneWidget);
      expect(find.text(ScanCopy.scanAgain), findsOneWidget);
      expect(find.text(ScanCopy.useQrInstead), findsOneWidget);
      expect(find.byType(ScanSummarySheet), findsNothing);
    });

    testWidgets('invalid tag: no NDEF text at all', (tester) async {
      final rig = ScanRig();
      await rig.open(tester);
      rig.reader.emit(const NfcReadNoText());
      await ScanRig.settle(tester);
      expect(find.text(ScanCopy.invalidTitle), findsOneWidget);

      await tester.tap(find.text(ScanCopy.useQrInstead));
      await ScanRig.settle(tester);
      expect(find.text(ScanCopy.qrHint), findsOneWidget);
    });

    testWidgets('unknown ID shows the code', (tester) async {
      final rig = ScanRig();
      await rig.open(tester);
      rig.reader.emit(const NfcReadText('HPT-ZZZZZZZZ'));
      await ScanRig.settle(tester);

      expect(
        find.text("HPT-ZZZZZZZZ isn't registered", findRichText: true),
        findsOneWidget,
      );
      expect(find.text(ScanCopy.unknownBody), findsOneWidget);
      expect(find.text(ScanCopy.searchPatient), findsOneWidget);
      expect(find.text(ScanCopy.scanAgain), findsOneWidget);
    });

    testWidgets('NFC unsupported → message, then QR after 2 s', (tester) async {
      final rig = ScanRig(
        reader: FakeNfcReader(support: NfcSupport.unsupported),
      );
      await rig.open(tester);

      expect(find.text(ScanCopy.noNfcTitle), findsOneWidget);
      expect(find.text(ScanCopy.noNfcBody), findsOneWidget);
      expect(find.text(ScanCopy.switchingToQr), findsOneWidget);
      expect(rig.qrSources, isEmpty);

      await tester.pump(nfcAutoSwitchDelay);
      await ScanRig.settle(tester);
      expect(rig.qrSources, hasLength(1));
      expect(find.text(ScanCopy.qrHint), findsOneWidget);
      expect(
        find.text(ScanCopy.switchToNfc),
        findsNothing,
        reason: 'nothing to switch back to',
      );
    });

    testWidgets('NFC switched off on Android offers the NFC settings', (
      tester,
    ) async {
      final rig = ScanRig(reader: FakeNfcReader(support: NfcSupport.disabled));
      await rig.open(tester);
      expect(find.text(ScanCopy.openNfcSettings), findsOneWidget);
      await tester.tap(find.text(ScanCopy.useQrNow));
      await ScanRig.settle(tester);
      expect(find.text(ScanCopy.qrHint), findsOneWidget);
    });
  });

  group('NFC (iOS: user-initiated session)', () {
    testWidgets('Start scanning opens the system session with our alert', (
      tester,
    ) async {
      final rig = ScanRig();
      await rig.open(tester);

      expect(find.text(ScanCopy.holdHintIos), findsOneWidget);
      expect(rig.reader.reads, 0);
      await tester.tap(find.text(ScanCopy.start));
      await tester.pump();
      expect(rig.reader.reads, 1);
      expect(rig.reader.lastAlert, ScanCopy.iosAlert);

      rig.reader.emit(const NfcReadText(janCode));
      await ScanRig.settle(tester);
      expect(find.text('Jan Kowalczyk'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('cancelled → quiet return, nothing shown', (tester) async {
      final rig = ScanRig();
      await rig.open(tester);
      await tester.tap(find.text(ScanCopy.start));
      await tester.pump();

      rig.reader.emit(const NfcReadCancelled());
      await ScanRig.settle(tester);

      expect(find.byType(ScanSummarySheet), findsNothing);
      expect(find.byType(ScanIssueSheet), findsNothing);
      expect(find.byType(WlToast), findsNothing);
      expect(find.text(ScanCopy.start), findsOneWidget);
      expect(find.text(ScanCopy.title), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('QR', () {
    testWidgets('a QR code opens the same summary', (tester) async {
      final rig = ScanRig();
      final eventsBefore = rig.repo.current.events.length;
      await rig.open(tester);

      await tester.tap(find.text(ScanCopy.methodQr));
      await ScanRig.settle(tester);
      expect(find.text(ScanCopy.qrHint), findsOneWidget);
      expect(find.text(ScanCopy.switchToNfc), findsOneWidget);
      expect(rig.reader.stops, greaterThan(0), reason: 'NFC off in QR mode');

      rig.qr.emit(const QrCodeRead(' hpt-7k3m9qx2\n'));
      await ScanRig.settle(tester);

      expect(find.text('Jan Kowalczyk'), findsOneWidget);
      expect(find.text('QR · 10:46'), findsOneWidget);
      expect(rig.qr.pauses, 1);
      expect(rig.repo.current.events.length, eventsBefore);
    });

    testWidgets('camera denied → Open Settings and Use NFC instead', (
      tester,
    ) async {
      final rig = ScanRig();
      await rig.open(tester);
      await tester.tap(find.text(ScanCopy.methodQr));
      await ScanRig.settle(tester);

      rig.qr.emit(const QrCameraDenied());
      await ScanRig.settle(tester);
      expect(find.text(ScanCopy.cameraTitle), findsOneWidget);
      expect(find.text(ScanCopy.cameraBody), findsOneWidget);
      expect(find.text(ScanCopy.openSettings), findsOneWidget);

      await tester.tap(find.text(ScanCopy.useNfcInstead));
      await ScanRig.settle(tester);
      expect(find.text(ScanCopy.hold), findsOneWidget);
      expect(rig.qr.disposed, isTrue);
    });

    testWidgets('close returns to the previous screen', (tester) async {
      final rig = ScanRig();
      await rig.open(tester);
      await tester.tap(find.bySemanticsLabel(ScanCopy.close));
      await ScanRig.settle(tester);
      expect(find.byType(ScanScreen), findsNothing);
      expect(rig.reader.stops, greaterThan(0));
    });
  });

  group('accessibility and motion', () {
    testWidgets('text scale 2.0: scan screen and summary, no overflow', (
      tester,
    ) async {
      final rig = ScanRig();
      await rig.open(tester, textScale: 2);
      expect(tester.takeException(), isNull);

      rig.reader.emit(const NfcReadText(janCode));
      await ScanRig.settle(tester);
      expect(find.text('Jan Kowalczyk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 2.0: edge states, no overflow', (tester) async {
      final rig = ScanRig(
        reader: FakeNfcReader(support: NfcSupport.unsupported),
      );
      await rig.open(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.pump(nfcAutoSwitchDelay);
      await ScanRig.settle(tester);
      expect(tester.takeException(), isNull);
      rig.qr.emit(const QrCameraDenied());
      await ScanRig.settle(tester);
      expect(find.text(ScanCopy.cameraTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rings animate normally', (tester) async {
      final rig = ScanRig();
      await rig.open(tester);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('reduced motion: static rings, nothing keeps animating', (
      tester,
    ) async {
      final rig = ScanRig();
      await rig.open(tester, reduceMotion: true);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(ScanCopy.hold), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('close button and method tabs have labels and 48dp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final rig = ScanRig();
      await rig.open(tester);
      for (final label in [
        ScanCopy.close,
        ScanCopy.methodNfc,
        ScanCopy.methodQr,
      ]) {
        final f = find.bySemanticsLabel(label);
        expect(f, findsOneWidget);
        final size = tester.getSize(f);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
      handle.dispose();
    });
  });
}
