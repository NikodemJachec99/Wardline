import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'ndef_text.dart';

/// Whether this device can read NFC right now (checked at runtime, every time
/// the scan screen opens: the user can switch NFC off in system settings).
enum NfcSupport { ready, disabled, unsupported }

/// Outcome of one NFC read. Reading never writes anything (product rule 1).
sealed class NfcReadResult {
  const NfcReadResult();
}

/// The tag had an NDEF Text record. [text] is the raw payload; validate it
/// with `PatientCode.tryParse`.
final class NfcReadText extends NfcReadResult {
  const NfcReadText(this.text);
  final String text;
}

/// A tag was read but has no NDEF Text record (not a Wardline wristband).
final class NfcReadNoText extends NfcReadResult {
  const NfcReadNoText();
}

/// The user closed the iOS system sheet. The UI returns quietly, no error.
final class NfcReadCancelled extends NfcReadResult {
  const NfcReadCancelled();
}

/// The session failed (timeout, system busy, tag moved away too early).
final class NfcReadFailed extends NfcReadResult {
  const NfcReadFailed(this.message);
  final String message;
}

/// NFC wristband reader. iOS: user-initiated system sheet. Android: reader
/// mode while the scan screen is visible (call [stop] when leaving it).
abstract interface class NfcReader {
  Future<NfcSupport> availability();

  /// Waits for one tag and returns its NDEF Text payload.
  ///
  /// [iosAlertMessage] is shown on the iOS "Ready to Scan" sheet
  /// (`scan.iosAlert` in design/handoff/copy.md).
  Future<NfcReadResult> readOnce({required String iosAlertMessage});

  /// Ends a running session. Safe to call when nothing is running.
  Future<void> stop();
}

final nfcReaderProvider = Provider<NfcReader>((ref) => NfcManagerReader());

/// [NfcReader] on top of `nfc_manager`.
class NfcManagerReader implements NfcReader {
  NfcManagerReader([this._manager]);

  final NfcManager? _manager;
  NfcManager get _nfc => _manager ?? NfcManager.instance;

  Completer<NfcReadResult>? _pending;

  static bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<NfcSupport> availability() async {
    if (!_platformSupported) return NfcSupport.unsupported;
    return switch (await _nfc.checkAvailability()) {
      NfcAvailability.enabled => NfcSupport.ready,
      NfcAvailability.disabled => NfcSupport.disabled,
      NfcAvailability.unsupported => NfcSupport.unsupported,
    };
  }

  @override
  Future<NfcReadResult> readOnce({required String iosAlertMessage}) async {
    await stop();
    final completer = Completer<NfcReadResult>();
    _pending = completer;

    void finish(NfcReadResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    await _nfc.startSession(
      // NTAG213 wristbands are ISO 14443-A; 15693 covers other NDEF tags.
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      alertMessageIos: iosAlertMessage,
      onSessionErrorIos: (error) => finish(
        error.code ==
                NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled
            ? const NfcReadCancelled()
            : NfcReadFailed(error.message),
      ),
      onDiscovered: (tag) async {
        // Only the NDEF content counts. The chip UID is ignored on purpose.
        final ndef = Ndef.from(tag);
        String? text;
        try {
          text = firstNdefText(ndef?.cachedMessage ?? await ndef?.read());
        } on Object catch (e) {
          finish(NfcReadFailed(e.toString()));
          await _stopSession(error: true);
          return;
        }
        finish(text == null ? const NfcReadNoText() : NfcReadText(text));
        await _stopSession(error: text == null);
      },
    );
    return completer.future;
  }

  @override
  Future<void> stop() async {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const NfcReadCancelled());
      await _stopSession(error: false);
    }
  }

  Future<void> _stopSession({required bool error}) async {
    _pending = null;
    try {
      await _nfc.stopSession(
        // iOS shows its own tick on success; on failure a short reason.
        errorMessageIos: error ? 'Not a Wardline wristband' : null,
      );
    } on Object {
      // The session may already be closed by the system.
    }
  }
}
