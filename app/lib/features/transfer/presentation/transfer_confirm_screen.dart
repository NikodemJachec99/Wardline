import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/failures.dart';
import '../../../domain/models.dart';
import '../application/client_request.dart';
import 'widgets/check_draw.dart';
import 'widgets/detail_card.dart';

enum _Phase { confirm, saving, success, conflict, timeout, failed }

/// Confirm transfer (TransferFlow steps 2–7, flows 1, 2 and 6).
///
/// The patient's `version` is captured when the screen opens and sent as
/// `p_expected_version`; one `client_request_id` is generated per screen
/// (one intent) and reused by "Check status" after a timeout. Success is
/// shown only after `transferPatient` returns. PT409 shows the conflict
/// sheet and never retries.
class TransferConfirmScreen extends ConsumerStatefulWidget {
  const TransferConfirmScreen({
    required this.patientId,
    required this.toCode,
    super.key,
  });

  final String patientId;
  final String toCode;

  @override
  ConsumerState<TransferConfirmScreen> createState() =>
      _TransferConfirmScreenState();
}

class _TransferConfirmScreenState extends ConsumerState<TransferConfirmScreen> {
  final String _requestId = newClientRequestId();
  late final Patient? _opened = ref.read(patientProvider(widget.patientId));
  String? _identifiedBy;
  bool _readExtra = false;

  _Phase _phase = _Phase.confirm;
  bool _inFlight = false;
  bool _offlineFailure = false;
  LocationEvent? _event;
  ConflictFailure? _conflict;
  WlFailure? _failure;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readExtra) return;
    _readExtra = true;
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is String) _identifiedBy = extra;
    } on Object {
      // Not under a go_router route (e.g. widget tests): no extra.
    }
  }

  Future<void> _submit() async {
    final me = ref.read(sessionProvider);
    final p = _opened;
    if (_inFlight || me == null || p == null) return;
    _inFlight = true;
    setState(() {
      _phase = _Phase.saving;
      _failure = null;
      _offlineFailure = false;
    });
    try {
      final evt = await ref
          .read(hospitalRepositoryProvider)
          .transferPatient(
            patientId: p.id,
            to: widget.toCode,
            expectedVersion: p.version,
            requestId: _requestId,
            by: me,
            identifiedBy: _identifiedBy,
          );
      if (!mounted) return;
      setState(() {
        _event = evt;
        _phase = _Phase.success;
      });
      if (!WlMotion.reduced(context) && ref.read(settingsProvider).haptics) {
        unawaited(HapticFeedback.lightImpact());
      }
    } on ConflictFailure catch (e) {
      if (mounted) {
        setState(() {
          _conflict = e;
          _phase = _Phase.conflict;
        });
      }
    } on TimeoutFailure {
      if (mounted) setState(() => _phase = _Phase.timeout);
    } on OfflineFailure {
      if (mounted) {
        setState(() {
          _offlineFailure = true;
          _phase = _Phase.confirm;
        });
      }
    } on WlFailure catch (e) {
      if (mounted) {
        setState(() {
          _failure = e;
          _phase = _Phase.failed;
        });
      }
    } finally {
      _inFlight = false;
    }
  }

  void _backToPatient() =>
      GoRouter.of(context).go(Routes.patient(widget.patientId));

  /// PT409: refetch, then back to the profile with fresh data. The user
  /// chooses again; nothing is resent.
  void _refreshAndChooseAgain() {
    unawaited(
      ref.read(hospitalRepositoryProvider).refresh().catchError((Object _) {}),
    );
    _backToPatient();
  }

  void _cancel() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      _backToPatient();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityProvider, (_, next) {
      if (next.online && _offlineFailure) {
        setState(() => _offlineFailure = false);
      }
    });
    final t = WlTokens.of(context);
    final c = t.colors;
    final me = ref.watch(sessionProvider);
    final snap = ref.watch(hospitalProvider);
    final conn = ref.watch(connectivityProvider);
    final patient = _opened;
    final from = patient == null ? null : snap.department(patient.location);
    final to = snap.department(widget.toCode);

    Widget scaffold(Widget body) => PopScope(
      canPop: _phase != _Phase.saving,
      child: Scaffold(backgroundColor: c.page, body: body),
    );

    // Nurse only (guard + RLS). Other roles never get here from the UI.
    if (me?.role != UserRole.nurse) {
      return scaffold(
        SafeArea(
          child: Column(
            children: [
              const WlLargeTitle(title: 'Confirm transfer'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: WlErrorState(
                      title: 'Only nurses can move patients.',
                      primary: WlStateAction('Back to patient', _backToPatient),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (patient == null || from == null || to == null) {
      return scaffold(
        SafeArea(
          child: Column(
            children: [
              const WlLargeTitle(title: 'Confirm transfer'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: WlErrorState(
                      title: patient == null
                          ? "This patient isn't available"
                          : "This department isn't available",
                      body: 'Go back and choose again.',
                      primary: WlStateAction('Back', _cancel),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_phase == _Phase.success) {
      return scaffold(_success(context, patient, from, to, me!));
    }

    final saving = _phase == _Phase.saving;
    final offline = !conn.online;
    final showNote = (offline || _offlineFailure) && !saving;
    final overlay = switch (_phase) {
      _Phase.conflict => _conflictSheet(patient, from, to),
      _Phase.timeout => _timeoutSheet(patient),
      _Phase.failed => _failedSheet(to),
      _ => null,
    };
    final calm = overlay == null;

    final main = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WlLargeTitle(
            title: 'Confirm transfer',
            showBack: _phase == _Phase.confirm,
            onBack: _cancel,
          ),
          if (offline)
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                0,
                t.space.gutter,
                t.space.sm,
              ),
              child: WlOfflineBanner(syncedAt: hm(conn.syncedAt)),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                t.space.xxs,
                t.space.gutter,
                t.space.md,
              ),
              child: AnimatedOpacity(
                opacity: saving ? 0.72 : 1,
                duration: WlMotion.duration(context, t.motion.fast),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PatientHeader(patient: patient),
                    SizedBox(height: t.space.md),
                    WlTransferPath.big(
                      from: from.name,
                      to: to.name,
                      fromDetail: offline
                          ? 'since ${hm(patient.locationSince)} · may have changed'
                          : '${floorName(from.floor)} · since '
                                '${hm(patient.locationSince)}',
                      toDetail: offline
                          ? '${floorName(to.floor)} · occupancy unknown offline'
                          : _occupancyLine(to, snap.occupancy(to.code)),
                      moving: calm && !offline,
                      saving: saving,
                    ),
                    SizedBox(height: t.space.md),
                    TransferDetailCard(
                      rows: [
                        (
                          'Performed by',
                          TransferDetailValue(
                            '${me!.name} · ${me.roleLabel}',
                            leading: WlInitialsAvatar.staff(
                              me.name,
                              role: me.role,
                              size: 26,
                            ),
                          ),
                        ),
                        (
                          'Recorded at',
                          const TransferDetailValue('When the server confirms'),
                        ),
                        (
                          'Status',
                          TransferDetailValue(
                            '${WlStatusLabels.of(patient.status)} · unchanged',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.gutter,
              t.space.sm,
              t.space.gutter,
              t.space.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: showNote
                  ? [
                      const WlOfflineActionNote(),
                      SizedBox(height: t.space.xs),
                      WlButton(
                        label: 'Back to patient',
                        variant: WlButtonVariant.secondary,
                        dense: true,
                        onPressed: _backToPatient,
                      ),
                    ]
                  : [
                      WlButton(
                        key: const ValueKey('transfer-confirm'),
                        label: 'Confirm transfer',
                        icon: WlIcons.check,
                        loading: saving,
                        loadingLabel: 'Confirming…',
                        onPressed: _submit,
                      ),
                      SizedBox(height: t.space.xxs),
                      if (saving)
                        Container(
                          constraints: BoxConstraints(
                            minHeight: t.space.touchMin,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Waiting for the server',
                            textAlign: TextAlign.center,
                            style: t.typography.subhead.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        )
                      else
                        WlButton(
                          label: 'Cancel',
                          variant: WlButtonVariant.text,
                          dense: true,
                          onPressed: _cancel,
                        ),
                    ],
            ),
          ),
        ],
      ),
    );

    return scaffold(
      overlay == null
          ? main
          : Stack(
              children: [
                ExcludeSemantics(child: main),
                Positioned.fill(child: TransferSheetOverlay(child: overlay)),
              ],
            ),
    );
  }

  String _occupancyLine(Department d, int occupied) {
    final pct = d.beds == 0 ? 0 : (occupied * 100 / d.beds).round();
    final full = occupied >= d.beds ? ' · Full' : '';
    return '${floorName(d.floor)} · $occupied/${d.beds} beds · $pct%$full';
  }

  Widget _conflictSheet(Patient p, Department from, Department to) {
    final e = _conflict!;
    final who = [?e.byName, ?e.byRoleLabel].join(' · ');
    final where = e.to == null ? null : '${e.from ?? from.name} → ${e.to}';
    return WlErrorState(
      key: const ValueKey('transfer-conflict'),
      tone: WlErrorTone.warning,
      title: 'Patient was already moved',
      body: "Your change wasn't saved.",
      rows: [
        if (who.isNotEmpty) ('Who', who),
        if (e.at != null) ('When', 'Today, ${hm(e.at!)}'),
        if (where != null) ('Where', where),
      ],
      primary: WlStateAction(
        'Refresh and choose again',
        _refreshAndChooseAgain,
        icon: WlIcons.refresh,
      ),
      secondary: WlStateAction('Back to patient', _backToPatient),
    );
  }

  Widget _timeoutSheet(Patient p) => WlErrorState(
    key: const ValueKey('transfer-timeout'),
    tone: WlErrorTone.neutral,
    title: "We couldn't confirm the transfer",
    body:
        "The server didn't answer within 10 seconds. It may already be "
        "saved. Checking won't move ${p.firstName} twice.",
    footnote: 'Request reference ${requestReference(_requestId)}',
    // Same request id: the server returns the saved transfer, never a
    // second one.
    primary: WlStateAction('Check status', _submit),
    secondary: WlStateAction('Back to patient', _backToPatient),
  );

  Widget _failedSheet(Department to) {
    final (String title, String body) = switch (_failure) {
      ForbiddenFailure() => (
        'Only nurses can move patients.',
        'Your change wasn\'t saved.',
      ),
      InvalidRequestFailure(reason: 'SAME_LOCATION') => (
        'Patient is already in ${to.name}',
        'Nothing was changed.',
      ),
      NotFoundFailure() => (
        "This patient isn't registered",
        'Your change wasn\'t saved.',
      ),
      UnauthenticatedFailure() => (
        'Your session has ended',
        'Sign in again to move the patient.',
      ),
      _ => ("We couldn't save the transfer", "Your change wasn't saved."),
    };
    return WlErrorState(
      key: const ValueKey('transfer-failed'),
      title: title,
      body: body,
      primary: WlStateAction('Back to patient', _backToPatient),
    );
  }

  Widget _success(
    BuildContext context,
    Patient opened,
    Department from,
    Department to,
    StaffMember me,
  ) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final evt = _event!;
    final now = ref.watch(patientProvider(widget.patientId)) ?? opened;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                t.space.xl,
                t.space.gutter,
                t.space.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: TransferCheckDraw()),
                  SizedBox(height: t.space.sm),
                  Semantics(
                    liveRegion: true,
                    header: true,
                    child: Text(
                      'Patient moved to ${to.name}',
                      textAlign: TextAlign.center,
                      style: t.typography.title2.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: t.space.xs),
                  Text(
                    'Confirmed by the server at ${hm(evt.at)}. '
                    'Every device sees it now.',
                    textAlign: TextAlign.center,
                    style: t.typography
                        .tabular(t.typography.subhead)
                        .copyWith(color: c.textSecondary),
                  ),
                  SizedBox(height: t.space.lg),
                  Text(
                    'UPDATED AUTOMATICALLY',
                    style: t.typography.overline.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  SizedBox(height: t.space.xs),
                  TransferDetailCard(
                    rows: [
                      (
                        'Location',
                        TransferDetailValue(
                          '${ref.watch(hospitalProvider).department(now.location)?.name ?? to.name} · just now',
                          leading: Container(
                            width: t.space.xs,
                            height: t.space.xs,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      ('Status', WlStatusChip(now.status, size: WlChipSize.sm)),
                    ],
                  ),
                  SizedBox(height: t.space.xs),
                  MergeSemantics(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: t.space.sm + 2,
                        vertical: t.space.sm,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: t.radius.cardBr,
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: t.space.xl,
                            height: t.space.xl,
                            decoration: BoxDecoration(
                              color: c.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              WlIcons.transfer,
                              size: 16,
                              color: c.primaryInk,
                            ),
                          ),
                          SizedBox(width: t.space.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${from.name} → ${to.name}',
                                  style: t.typography.subhead.copyWith(
                                    color: c.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'History · ${me.name} · ${me.roleLabel}',
                                  style: t.typography.caption.copyWith(
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: t.space.xs),
                          Text(
                            hm(evt.at),
                            style: t.typography
                                .tabular(t.typography.subhead)
                                .copyWith(
                                  color: c.primaryInk,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.gutter,
              t.space.sm,
              t.space.gutter,
              t.space.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WlButton(label: 'Back to patient', onPressed: _backToPatient),
                SizedBox(height: t.space.xs),
                WlButton(
                  label: 'Scan next patient',
                  variant: WlButtonVariant.secondary,
                  dense: true,
                  onPressed: () =>
                      GoRouter.of(context).pushReplacement(Routes.scan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar, name, ID and status chip (TransferFlow step 2 header).
class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Row(
      children: [
        WlInitialsAvatar.patient(patient.fullName, size: 44),
        SizedBox(width: t.space.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient.fullName,
                style: t.typography.label.copyWith(color: c.text),
              ),
              Text(
                patient.code,
                style: t.typography.id.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        SizedBox(width: t.space.xs),
        Flexible(child: WlStatusChip(patient.status, size: WlChipSize.sm)),
      ],
    );
  }
}
