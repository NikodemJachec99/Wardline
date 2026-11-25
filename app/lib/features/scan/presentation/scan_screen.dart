import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart' hide AppSettings;
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';
import '../../status/presentation/change_status_sheet.dart';
import '../../transfer/presentation/choose_destination_sheet.dart';
import '../data/nfc_reader.dart';
import '../data/qr_source.dart';
import '../data/resolve_patient.dart';
import 'scan_copy.dart';
import 'widgets/nfc_scan_area.dart';
import 'widgets/qr_camera_view.dart';
import 'widgets/scan_method_toggle.dart';
import 'widgets/scan_sheets.dart';

/// NFC unavailable → QR after 2 s (ScanEdge, platform-and-a11y.md).
const Duration nfcAutoSwitchDelay = Duration(seconds: 2);

/// Android only: wait before listening again after a failed read, so a
/// broken session can't spin.
const Duration _relistenDelay = Duration(seconds: 1);

enum _NfcPhase { checking, idle, reading, unavailable }

/// Scan (flow 1, steps 1–3): full-screen modal over the shell.
///
/// NFC by default. iOS: idle rings + **Start scanning** (user-initiated
/// system sheet). Android: listens at once (reader mode while visible).
/// QR mode: camera with viewfinder. A read goes through [resolvePatient]
/// (read only) and opens the quick summary. Scanning never writes.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  ScanMethod _method = ScanMethod.nfc;
  _NfcPhase _phase = _NfcPhase.checking;
  NfcSupport? _support;

  /// Scan area brightened (read OK, summary open).
  bool _identified = false;

  /// A read is being resolved or its sheet is open: ignore further reads.
  bool _handling = false;

  /// Auto-switch to QR is counting down.
  bool _autoSwitching = false;
  Timer? _autoSwitch;
  Timer? _relisten;

  QrSource? _qr;
  StreamSubscription<QrScanEvent>? _qrSub;
  bool _cameraDenied = false;

  late final NfcReader _reader = ref.read(nfcReaderProvider);

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkNfc(autoSwitch: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSwitch?.cancel();
    _relisten?.cancel();
    unawaited(_reader.stop().catchError((Object _) {}));
    _disposeQr();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` is ignored on purpose: the iOS NFC system sheet causes it.
    if (state == AppLifecycleState.paused) {
      if (_method == ScanMethod.qr) unawaited(_qr?.pause());
      if (!_isIos && _phase == _NfcPhase.reading) {
        unawaited(_reader.stop().catchError((Object _) {}));
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_method == ScanMethod.qr) {
        if (_cameraDenied) {
          _openQr();
        } else if (!_handling) {
          unawaited(_qr?.resume());
        }
      } else if (_phase == _NfcPhase.unavailable) {
        unawaited(_checkNfc(autoSwitch: false));
      } else if (!_isIos && _phase == _NfcPhase.reading && !_handling) {
        unawaited(_readNfc());
      }
    }
  }

  // ------------------------------------------------------------------ NFC

  Future<void> _checkNfc({required bool autoSwitch}) async {
    NfcSupport support;
    try {
      support = await _reader.availability();
    } on Object {
      support = NfcSupport.unsupported;
    }
    if (!mounted) return;
    setState(() => _support = support);
    if (_method != ScanMethod.nfc) return;
    if (support == NfcSupport.ready) {
      _autoSwitch?.cancel();
      setState(() {
        _autoSwitching = false;
        _phase = _isIos ? _NfcPhase.idle : _NfcPhase.reading;
      });
      if (!_isIos) unawaited(_readNfc());
    } else {
      setState(() => _phase = _NfcPhase.unavailable);
      if (autoSwitch) _startAutoSwitch();
    }
  }

  void _startAutoSwitch() {
    _autoSwitch?.cancel();
    setState(() => _autoSwitching = true);
    _autoSwitch = Timer(nfcAutoSwitchDelay, () {
      if (mounted && _method == ScanMethod.nfc) _setMethod(ScanMethod.qr);
    });
  }

  void _cancelAutoSwitch() {
    _autoSwitch?.cancel();
    if (_autoSwitching) setState(() => _autoSwitching = false);
  }

  Future<void> _readNfc() async {
    if (_method != ScanMethod.nfc || _handling) return;
    _relisten?.cancel();
    setState(() => _phase = _NfcPhase.reading);
    NfcReadResult result;
    try {
      result = await _reader.readOnce(iosAlertMessage: ScanCopy.iosAlert);
    } on Object catch (e) {
      result = NfcReadFailed(e.toString());
    }
    if (!mounted || _method != ScanMethod.nfc) return;
    switch (result) {
      case NfcReadText(:final text):
        await _handleRaw(text, 'NFC');
      case NfcReadNoText():
        await _handleRaw(null, 'NFC');
      case NfcReadCancelled():
        // Quiet return: no error, no toast (scan.cancelled). On Android a
        // cancel only comes from our own stop().
        if (_isIos) setState(() => _phase = _NfcPhase.idle);
      case NfcReadFailed():
        if (_isIos) {
          setState(() => _phase = _NfcPhase.idle);
        } else {
          _relisten = Timer(_relistenDelay, () {
            if (mounted) unawaited(_readNfc());
          });
        }
    }
  }

  // ------------------------------------------------------------------- QR

  void _openQr() {
    _disposeQr();
    final qr = ref.read(qrSourceFactoryProvider)();
    _qr = qr;
    _qrSub = qr.events.listen(_onQrEvent);
    setState(() => _cameraDenied = false);
  }

  void _disposeQr() {
    unawaited(_qrSub?.cancel());
    _qrSub = null;
    final qr = _qr;
    _qr = null;
    if (qr != null) unawaited(qr.dispose().catchError((Object _) {}));
  }

  void _onQrEvent(QrScanEvent event) {
    if (!mounted || _method != ScanMethod.qr) return;
    switch (event) {
      case QrCodeRead(:final raw):
        if (!_handling) unawaited(_handleRaw(raw, 'QR'));
      case QrCameraDenied():
        setState(() => _cameraDenied = true);
      case QrCameraFailed():
        // Camera busy or missing: the user can switch to NFC or close.
        break;
    }
  }

  // ------------------------------------------------------------ switching

  void _setMethod(ScanMethod method) {
    if (method == _method) return;
    _cancelAutoSwitch();
    _relisten?.cancel();
    if (method == ScanMethod.qr) {
      unawaited(_reader.stop().catchError((Object _) {}));
      setState(() => _method = ScanMethod.qr);
      _openQr();
    } else {
      _disposeQr();
      setState(() {
        _method = ScanMethod.nfc;
        _cameraDenied = false;
      });
      if (_support == NfcSupport.ready) {
        if (_isIos) {
          setState(() => _phase = _NfcPhase.idle);
        } else {
          unawaited(_readNfc());
        }
      } else if (_support != null) {
        // Chosen by the user: show why, but don't bounce back to QR.
        setState(() => _phase = _NfcPhase.unavailable);
      }
    }
  }

  // ----------------------------------------------------------- resolving

  Future<void> _handleRaw(String? raw, String method) async {
    _handling = true;
    if (method == 'QR') await _qr?.pause();
    final ScanResolution res;
    try {
      res = await resolvePatient(ref.read(hospitalRepositoryProvider), raw);
    } on Object {
      if (!mounted) return;
      showWlToast(
        context,
        title: ScanCopy.loadFailed,
        tone: WlToastTone.danger,
      );
      _resume();
      return;
    }
    if (!mounted) return;
    switch (res) {
      case ScanInvalid():
        await _showInvalid(method);
      case ScanUnknown(:final code):
        await _showUnknown(code.value);
      case ScanFound(:final patient):
        await _showSummary(patient, method);
    }
  }

  /// Back to listening after a sheet closed or a pushed page returned.
  void _resume({bool startIosSession = false}) {
    if (!mounted) return;
    setState(() {
      _identified = false;
      _handling = false;
    });
    if (_method == ScanMethod.qr) {
      unawaited(_qr?.resume());
      return;
    }
    if (_support != NfcSupport.ready) return;
    if (_isIos) {
      setState(() => _phase = _NfcPhase.idle);
      if (startIosSession) unawaited(_readNfc());
    } else {
      unawaited(_readNfc());
    }
  }

  Future<void> _showInvalid(String method) async {
    final nfcOk = _support == NfcSupport.ready;
    final choice = await showWlBottomSheet<ScanIssueChoice>(
      context: context,
      builder: (context) => ScanIssueSheet(
        icon: WlIcons.tag,
        tone: WlErrorTone.warning,
        title: const TextSpan(text: ScanCopy.invalidTitle),
        semanticTitle: ScanCopy.invalidTitle,
        body: ScanCopy.invalidBody,
        primaryLabel: ScanCopy.scanAgain,
        secondaryLabel: method == 'NFC'
            ? ScanCopy.useQrInstead
            : (nfcOk ? ScanCopy.useNfcInstead : null),
      ),
    );
    if (!mounted) return;
    if (choice == ScanIssueChoice.secondary) {
      setState(() => _handling = false);
      _setMethod(method == 'NFC' ? ScanMethod.qr : ScanMethod.nfc);
      return;
    }
    _resume(startIosSession: choice == ScanIssueChoice.primary);
  }

  Future<void> _showUnknown(String code) async {
    final t = WlTokens.of(context);
    final choice = await showWlBottomSheet<ScanIssueChoice>(
      context: context,
      builder: (context) => ScanIssueSheet(
        icon: LucideIcons.userX,
        tone: WlErrorTone.neutral,
        title: TextSpan(
          children: [
            TextSpan(
              text: code,
              style: t.typography.id.copyWith(
                fontSize: t.typography.title2.fontSize,
                height: t.typography.title2.height,
                fontWeight: t.typography.title2.fontWeight,
              ),
            ),
            const TextSpan(text: ScanCopy.unknownTitleSuffix),
          ],
        ),
        semanticTitle: ScanCopy.unknownTitle(code),
        body: ScanCopy.unknownBody,
        primaryLabel: ScanCopy.searchPatient,
        secondaryLabel: ScanCopy.scanAgain,
      ),
    );
    if (!mounted) return;
    if (choice == ScanIssueChoice.primary) {
      context.go(Routes.patients);
      return;
    }
    _resume(startIosSession: choice == ScanIssueChoice.secondary);
  }

  Future<void> _showSummary(Patient patient, String method) async {
    setState(() => _identified = true);
    // motion.md: haptic on the same frame as the brighten.
    if (ref.read(settingsProvider).haptics) {
      unawaited(HapticFeedback.mediumImpact());
    }
    final scannedAt = ref.read(scanClockProvider)();
    final action = await showWlBottomSheet<ScanSummaryAction>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final p = ref.watch(patientProvider(patient.id)) ?? patient;
          final dept = ref.watch(
            hospitalProvider.select((s) => s.department(p.location)),
          );
          return ScanSummarySheet(
            patient: p,
            locationName: dept?.name ?? p.location,
            method: method,
            scannedAt: scannedAt,
            now: ref.read(scanClockProvider)(),
            role: ref.watch(sessionProvider.select((s) => s?.role)),
            online: ref.watch(connectivityProvider.select((c) => c.online)),
          );
        },
      ),
    );
    if (!mounted) return;
    final current = ref.read(patientProvider(patient.id)) ?? patient;
    switch (action) {
      case null:
        _resume();
      case ScanSummaryAction.viewProfile || ScanSummaryAction.history:
        // Root-level record page: Back returns to the scanner.
        await context.push(Routes.patientRecord(current.id));
        _resume();
      case ScanSummaryAction.transfer:
        await showChooseDestinationSheet(
          context,
          patient: current,
          identifiedBy: method,
        );
        _resume();
      case ScanSummaryAction.changeStatus:
        await showChangeStatusSheet(context, patient: current);
        _resume();
    }
  }

  // ------------------------------------------------------------- actions

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.dashboard);
    }
  }

  Future<void> _openSettings(AppSettingsType type) async {
    try {
      await AppSettings.openAppSettings(type: type);
    } on Object {
      // No settings app (tests, desktop).
    }
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final Widget body;
    var dark = false;
    if (_method == ScanMethod.qr && !_cameraDenied && _qr != null) {
      dark = true;
      final qr = _qr!;
      body = ValueListenableBuilder<bool>(
        valueListenable: qr.torchOn,
        builder: (context, torch, _) => QrCameraView(
          preview: qr.buildPreview(context),
          torchOn: torch,
          onClose: _close,
          onToggleTorch: () => unawaited(qr.toggleTorch()),
          onSwitchToNfc: _support == NfcSupport.ready
              ? () => _setMethod(ScanMethod.nfc)
              : null,
        ),
      );
    } else if (_method == ScanMethod.qr) {
      body = _cameraDeniedBody(context);
    } else if (_phase == _NfcPhase.unavailable) {
      body = _nfcUnavailableBody(context);
    } else {
      body = _nfcBody(context);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: dark ? t.colors.text : t.colors.page,
        body: body,
      ),
    );
  }

  Widget _nfcBody(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final showStart = _isIos && _phase != _NfcPhase.checking;
    return _Page(
      title: ScanCopy.title,
      onClose: _close,
      toggle: ScanMethodToggle(value: _method, onChanged: _setMethod),
      content: [
        SizedBox(height: t.space.lg),
        NfcScanArea(identified: _identified),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space.xl),
          child: Column(
            children: [
              Semantics(
                header: true,
                child: Text(
                  ScanCopy.hold,
                  textAlign: TextAlign.center,
                  style: t.typography.title2.copyWith(color: c.text),
                ),
              ),
              SizedBox(height: t.space.xs),
              Text(
                _isIos ? ScanCopy.holdHintIos : ScanCopy.holdHintAndroid,
                textAlign: TextAlign.center,
                style: t.typography.callout.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.space.lg - t.space.xxs),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space.md),
          child: const _RuleNote(),
        ),
      ],
      actions: [
        if (showStart)
          WlButton(
            label: ScanCopy.start,
            onPressed: _phase == _NfcPhase.idle && !_handling
                ? () => unawaited(_readNfc())
                : null,
            loading: _phase == _NfcPhase.reading,
          ),
        WlButton(
          label: ScanCopy.cancel,
          variant: WlButtonVariant.text,
          dense: true,
          onPressed: _close,
        ),
      ],
    );
  }

  Widget _nfcUnavailableBody(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final reduced = WlMotion.reduced(context);
    final offerSettings = !_isIos && _support == NfcSupport.disabled;
    return _Page(
      title: ScanCopy.title,
      onClose: _close,
      centerContent: true,
      content: [
        Semantics(
          container: true,
          liveRegion: true,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.xl),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.status(PatientStatus.discharged).bg,
                    shape: BoxShape.circle,
                  ),
                  child: _NfcOffIcon(
                    color: c.status(PatientStatus.discharged).fg,
                  ),
                ),
                SizedBox(height: t.space.sm),
                Text(
                  ScanCopy.noNfcTitle,
                  textAlign: TextAlign.center,
                  style: t.typography.title2.copyWith(color: c.text),
                ),
                SizedBox(height: t.space.sm),
                Text(
                  ScanCopy.noNfcBody,
                  textAlign: TextAlign.center,
                  style: t.typography.callout.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (_autoSwitching) ...[
                  SizedBox(height: t.space.md + t.space.xxs),
                  SizedBox(
                    width: 200,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(t.radius.full),
                          child: SizedBox(
                            height: t.space.xxs,
                            child: reduced
                                ? ColoredBox(color: c.border)
                                : TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: nfcAutoSwitchDelay,
                                    builder: (context, v, _) =>
                                        LinearProgressIndicator(
                                          value: v,
                                          minHeight: t.space.xxs,
                                          color: c.primary,
                                          backgroundColor: c.border,
                                        ),
                                  ),
                          ),
                        ),
                        SizedBox(height: t.space.xxs + 2),
                        Text(
                          ScanCopy.switchingToQr,
                          style: t.typography.caption.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      actions: [
        WlButton(
          label: ScanCopy.useQrNow,
          onPressed: () => _setMethod(ScanMethod.qr),
        ),
        if (offerSettings)
          WlButton(
            label: ScanCopy.openNfcSettings,
            variant: WlButtonVariant.secondary,
            dense: true,
            onPressed: () {
              _cancelAutoSwitch();
              unawaited(_openSettings(AppSettingsType.nfc));
            },
          ),
        WlButton(
          label: ScanCopy.cancel,
          variant: WlButtonVariant.text,
          dense: true,
          onPressed: _close,
        ),
      ],
    );
  }

  Widget _cameraDeniedBody(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return _Page(
      title: ScanCopy.titleQr,
      onClose: _close,
      toggle: ScanMethodToggle(value: _method, onChanged: _setMethod),
      content: [
        Padding(
          padding: EdgeInsets.fromLTRB(t.space.md, t.space.lg, t.space.md, 0),
          child: ExcludeSemantics(
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: c.borderStrong,
                radius: t.radius.card + t.space.xxs,
              ),
              child: Container(
                height: 300,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.subtle,
                  borderRadius: BorderRadius.circular(
                    t.radius.card + t.space.xxs,
                  ),
                ),
                child: Icon(
                  LucideIcons.cameraOff,
                  size: 48,
                  color: c.textDisabled,
                ),
              ),
            ),
          ),
        ),
        Semantics(
          container: true,
          liveRegion: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(t.space.xl, t.space.lg, t.space.xl, 0),
            child: Column(
              children: [
                Text(
                  ScanCopy.cameraTitle,
                  textAlign: TextAlign.center,
                  style: t.typography.title2.copyWith(color: c.text),
                ),
                SizedBox(height: t.space.xs),
                Text(
                  ScanCopy.cameraBody,
                  textAlign: TextAlign.center,
                  style: t.typography.callout.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      actions: [
        WlButton(
          label: ScanCopy.openSettings,
          onPressed: () => unawaited(_openSettings(AppSettingsType.settings)),
        ),
        if (_support == NfcSupport.ready)
          WlButton(
            label: ScanCopy.useNfcInstead,
            variant: WlButtonVariant.secondary,
            dense: true,
            onPressed: () => _setMethod(ScanMethod.nfc),
          ),
      ],
    );
  }
}

/// Light scan page: header (close · title), optional method toggle, a
/// scrolling middle and actions pinned to the bottom (`margin-top: auto`).
class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.onClose,
    required this.content,
    required this.actions,
    this.toggle,
    this.centerContent = false,
  });

  final String title;
  final VoidCallback onClose;
  final Widget? toggle;
  final List<Widget> content;
  final List<Widget> actions;
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final pad = MediaQuery.paddingOf(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.xs,
            pad.top + t.space.xs,
            t.space.xs,
            0,
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: ScanCopy.close,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: SizedBox.square(
                    dimension: t.space.touchMin,
                    child: Icon(WlIcons.close, size: 22, color: c.text),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: t.typography.title3.copyWith(color: c.text),
                  ),
                ),
              ),
              SizedBox(width: t.space.touchMin),
            ],
          ),
        ),
        if (toggle != null)
          Padding(
            padding: EdgeInsets.fromLTRB(t.space.md, t.space.xs, t.space.md, 0),
            child: toggle,
          ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (centerContent) const Spacer(),
                    ...content,
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        t.space.md,
                        t.space.lg,
                        t.space.md,
                        pad.bottom + t.space.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) SizedBox(height: t.space.xs),
                            actions[i],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Scanning opens the record — it never moves the patient." (scan.rule)
class _RuleNote extends StatelessWidget {
  const _RuleNote();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.md - 2,
        vertical: t.space.xs + 2,
      ),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: t.radius.inputBr,
      ),
      child: Row(
        children: [
          Icon(WlIcons.info, size: 18, color: c.textSecondary),
          SizedBox(width: t.space.xs + 2),
          Expanded(
            child: Text(
              ScanCopy.rule,
              style: t.typography.subhead.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lucide `nfc` with a slash (ScanEdge "NFC not available"). Lucide has no
/// nfc-off glyph.
class _NfcOffIcon extends StatelessWidget {
  const _NfcOffIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: CustomPaint(
        foregroundPainter: _SlashPainter(color),
        child: Icon(WlIcons.nfc, size: 40, color: color),
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  _SlashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width / 12;
    canvas.drawLine(
      Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      Paint()
        ..color = color
        ..strokeWidth = size.width / 16
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SlashPainter old) => old.color != color;
}

/// 1.5px dashed rounded border (camera placeholder on ScanEdge).
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
