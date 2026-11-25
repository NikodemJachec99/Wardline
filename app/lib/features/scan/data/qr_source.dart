import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// What the camera reports while the QR scanner is open. Reading never writes
/// anything (product rule 1).
sealed class QrScanEvent {
  const QrScanEvent();
}

/// A QR code was decoded. Validate [raw] with `PatientCode.tryParse`.
final class QrCodeRead extends QrScanEvent {
  const QrCodeRead(this.raw);
  final String raw;
}

/// The user denied camera access (ScanEdge "Camera permission denied").
final class QrCameraDenied extends QrScanEvent {
  const QrCameraDenied();
}

/// The camera couldn't start (no camera, in use by another app, ...).
final class QrCameraFailed extends QrScanEvent {
  const QrCameraFailed(this.message);
  final String message;
}

/// Camera QR reader behind an interface, so tests inject codes without a
/// camera. One instance per QR session: the scan screen creates it when QR
/// mode opens and disposes it when QR mode closes.
abstract interface class QrSource {
  Stream<QrScanEvent> get events;

  /// Torch state for the toggle in the top bar.
  ValueListenable<bool> get torchOn;

  /// The live camera image, filling its box.
  Widget buildPreview(BuildContext context);

  /// Stops delivering codes (sheet open, app in background).
  Future<void> pause();

  /// Starts (again) after [pause].
  Future<void> resume();

  Future<void> toggleTorch();

  Future<void> dispose();
}

/// Creates the QR source for one QR session. Tests override it with a fake.
final qrSourceFactoryProvider = Provider<QrSource Function()>(
  (ref) => MobileScannerQrSource.new,
);

/// [QrSource] on top of `mobile_scanner` (QR only, back camera).
class MobileScannerQrSource implements QrSource {
  MobileScannerQrSource()
    : _controller = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
      ) {
    _barcodes = _controller.barcodes.listen(_onBarcodes);
    _controller.addListener(_onState);
  }

  final MobileScannerController _controller;
  final StreamController<QrScanEvent> _events =
      StreamController<QrScanEvent>.broadcast();
  final ValueNotifier<bool> _torch = ValueNotifier<bool>(false);
  late final StreamSubscription<BarcodeCapture> _barcodes;
  MobileScannerException? _lastError;
  bool _paused = false;

  @override
  Stream<QrScanEvent> get events => _events.stream;

  @override
  ValueListenable<bool> get torchOn => _torch;

  void _onBarcodes(BarcodeCapture capture) {
    if (_paused) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null) {
        _add(QrCodeRead(raw));
        return;
      }
    }
  }

  void _onState() {
    final value = _controller.value;
    _torch.value = value.torchState == TorchState.on;
    final error = value.error;
    if (error != null && !identical(error, _lastError)) {
      _lastError = error;
      _report(error);
    }
  }

  void _report(MobileScannerException error) {
    _add(
      error.errorCode == MobileScannerErrorCode.permissionDenied
          ? const QrCameraDenied()
          : QrCameraFailed(error.errorDetails?.message ?? error.errorCode.name),
    );
  }

  void _add(QrScanEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  @override
  Widget buildPreview(BuildContext context) => MobileScanner(
    controller: _controller,
    // Errors become events; the screen draws the camera-denied state itself.
    errorBuilder: (context, error) => const SizedBox.expand(),
    placeholderBuilder: (context) => const SizedBox.expand(),
  );

  @override
  Future<void> pause() async {
    _paused = true;
    try {
      await _controller.stop();
    } on Object {
      // Already stopped.
    }
  }

  @override
  Future<void> resume() async {
    _paused = false;
    try {
      await _controller.start();
    } on MobileScannerException catch (e) {
      _report(e);
    } on Object catch (e) {
      _add(QrCameraFailed(e.toString()));
    }
  }

  @override
  Future<void> toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } on Object {
      // No torch on this camera.
    }
  }

  @override
  Future<void> dispose() async {
    _controller.removeListener(_onState);
    await _barcodes.cancel();
    await _events.close();
    _torch.dispose();
    await _controller.dispose();
  }
}
