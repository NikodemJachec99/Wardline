import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/failures.dart';
import '../../../domain/models.dart';
import '../../transfer/application/client_request.dart';

/// Doctor only (StatusFlow, flow 3). Four statuses, current marked,
/// "Location doesn't change", reason required for Discharged,
/// Save status → RPC `set_patient_status`. The sheet is locked while the
/// request is in flight; the toast appears only after the server answered.
///
/// Any other role: nothing opens.
Future<void> showChangeStatusSheet(
  BuildContext context, {
  required Patient patient,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(sessionProvider)?.role != UserRole.doctor) return;

  // Not disposed here: the sheet still listens while it animates out.
  // It has no other owner, so it is collected with the sheet.
  final busy = ValueNotifier<bool>(false);
  final saved = await showWlBottomSheet<StatusEvent>(
    context: context,
    busy: busy,
    builder: (context) => _StatusSheet(patient: patient, busy: busy),
  );
  if (saved == null || !context.mounted) return;
  if (!WlMotion.reduced(context) && container.read(settingsProvider).haptics) {
    unawaited(HapticFeedback.lightImpact());
  }
  showWlToast(
    context,
    title: 'Status updated',
    body: '${WlStatusLabels.of(saved.to)} · location unchanged',
  );
}

enum _Phase { choose, saving, conflict, timeout, failed }

class _StatusSheet extends ConsumerStatefulWidget {
  const _StatusSheet({required this.patient, required this.busy});

  final Patient patient;
  final ValueNotifier<bool> busy;

  @override
  ConsumerState<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends ConsumerState<_StatusSheet> {
  final TextEditingController _reason = TextEditingController();

  /// Version the doctor saw when the sheet opened (p_expected_version).
  late int _expectedVersion = widget.patient.version;

  /// One request id per intent; a new one only after "Refresh and choose
  /// again" (a new decision), the same one for "Check status".
  String _requestId = newClientRequestId();
  PatientStatus? _selected;
  _Phase _phase = _Phase.choose;
  bool _offlineFailure = false;
  ConflictFailure? _conflict;
  WlFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _setPhase(_Phase p) {
    _phase = p;
    widget.busy.value = p == _Phase.saving;
  }

  Future<void> _save() async {
    final me = ref.read(sessionProvider);
    final to = _selected;
    if (_phase == _Phase.saving || me == null || to == null) return;
    setState(() {
      _setPhase(_Phase.saving);
      _offlineFailure = false;
    });
    try {
      final reason = _reason.text.trim();
      final evt = await ref
          .read(hospitalRepositoryProvider)
          .setPatientStatus(
            patientId: widget.patient.id,
            status: to,
            expectedVersion: _expectedVersion,
            requestId: _requestId,
            by: me,
            reason: reason.isEmpty ? null : reason,
          );
      if (!mounted) return;
      widget.busy.value = false;
      Navigator.of(context).pop(evt);
    } on ConflictFailure catch (e) {
      if (mounted) {
        setState(() {
          _conflict = e;
          _setPhase(_Phase.conflict);
        });
      }
    } on TimeoutFailure {
      if (mounted) setState(() => _setPhase(_Phase.timeout));
    } on OfflineFailure {
      if (mounted) {
        setState(() {
          _offlineFailure = true;
          _setPhase(_Phase.choose);
        });
      }
    } on WlFailure catch (e) {
      if (mounted) {
        setState(() {
          _failure = e;
          _setPhase(_Phase.failed);
        });
      }
    }
  }

  /// PT409: take the fresh version and let the doctor choose again.
  /// Nothing is resent automatically.
  void _refreshAndChooseAgain() {
    final fresh = ref.read(patientProvider(widget.patient.id));
    setState(() {
      _expectedVersion = fresh?.version ?? _expectedVersion;
      _requestId = newClientRequestId();
      _selected = null;
      _conflict = null;
      _setPhase(_Phase.choose);
    });
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityProvider, (_, next) {
      if (next.online && _offlineFailure) {
        setState(() => _offlineFailure = false);
      }
    });
    final t = WlTokens.of(context);
    final snap = ref.watch(hospitalProvider);
    final online = ref.watch(connectivityProvider).online;
    final patient = snap.patient(widget.patient.id) ?? widget.patient;
    final current = patient.status;
    final location =
        snap.department(patient.location)?.name ?? patient.location;

    final Widget body = switch (_phase) {
      _Phase.conflict => _conflictState(),
      _Phase.timeout => WlErrorState(
        key: const ValueKey('status-timeout'),
        tone: WlErrorTone.neutral,
        title: "We couldn't confirm the status change",
        body:
            "The server didn't answer within 10 seconds. It may already be "
            "saved. Checking won't change it twice.",
        footnote:
            'Request reference ${requestReference(_requestId, prefix: 'ST')}',
        primary: WlStateAction('Check status', _save),
        secondary: WlStateAction('Close', _close),
      ),
      _Phase.failed => WlErrorState(
        key: const ValueKey('status-failed'),
        title: switch (_failure) {
          ForbiddenFailure() => 'Only doctors can change status.',
          InvalidRequestFailure(reason: 'SAME_STATUS') =>
            'The patient already has this status',
          InvalidRequestFailure(reason: 'REASON_REQUIRED') =>
            'A reason is required for discharge',
          _ => "We couldn't save the status",
        },
        body: "Your change wasn't saved.",
        primary: WlStateAction('Close', _close),
      ),
      _ => _chooser(t, patient, current, location, online),
    };

    return SingleChildScrollView(child: body);
  }

  Widget _conflictState() {
    final e = _conflict!;
    final who = [?e.byName, ?e.byRoleLabel].join(' · ');
    return WlErrorState(
      key: const ValueKey('status-conflict'),
      tone: WlErrorTone.warning,
      title: e.to != null
          ? 'Patient was already moved'
          : 'Status was already changed',
      body: "Your change wasn't saved.",
      rows: [
        if (who.isNotEmpty) ('Who', who),
        if (e.at != null) ('When', 'Today, ${hm(e.at!)}'),
        if (e.to != null) ('Where', '${e.from ?? '…'} → ${e.to}'),
      ],
      primary: WlStateAction(
        'Refresh and choose again',
        _refreshAndChooseAgain,
        icon: WlIcons.refresh,
      ),
      secondary: WlStateAction('Close', _close),
    );
  }

  Widget _chooser(
    WlTokens t,
    Patient patient,
    PatientStatus current,
    String location,
    bool online,
  ) {
    final c = t.colors;
    final saving = _phase == _Phase.saving;
    final discharge = _selected == PatientStatus.discharged;
    final reasonOk = !discharge || _reason.text.trim().isNotEmpty;
    final canSave = _selected != null && _selected != current && reasonOk;
    final showNote = (!online || _offlineFailure) && !saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Change status',
            style: t.typography.title2.copyWith(color: c.text),
          ),
        ),
        Text.rich(
          TextSpan(
            text: '${patient.fullName} · ',
            children: [TextSpan(text: patient.code, style: t.typography.id)],
          ),
          style: t.typography.subhead.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: t.space.sm),
        // Location and status are separate: say so before the choice.
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: t.space.sm,
            vertical: t.space.sm - 2,
          ),
          decoration: BoxDecoration(
            color: c.subtle,
            borderRadius: t.radius.inputBr,
          ),
          child: Row(
            children: [
              Icon(WlIcons.mapPin, size: 20, color: c.textSecondary),
              SizedBox(width: t.space.sm - 2),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text:
                        "Location doesn't change. ${patient.firstName} stays "
                        'in ',
                    children: [
                      TextSpan(
                        text: location,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  style: t.typography.subhead.copyWith(color: c.text),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.space.sm),
        Semantics(
          container: true,
          label: 'Status',
          child: AnimatedOpacity(
            opacity: saving ? 0.6 : 1,
            duration: WlMotion.duration(context, t.motion.fast),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in PatientStatus.values) ...[
                  _StatusOption(
                    status: s,
                    selected: _selected == s,
                    current: s == current,
                    since: s == current ? hm(patient.statusSince) : null,
                    onTap: saving || s == current
                        ? null
                        : () => setState(() => _selected = s),
                  ),
                  if (s != PatientStatus.values.last)
                    SizedBox(height: t.space.xs),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: t.space.md),
        _ReasonField(
          controller: _reason,
          required: discharge,
          enabled: !saving,
        ),
        SizedBox(height: t.space.md),
        if (showNote)
          const WlOfflineActionNote()
        else
          WlButton(
            key: const ValueKey('status-save'),
            label: discharge ? 'Discharge patient' : 'Save status',
            variant: discharge
                ? WlButtonVariant.destructive
                : WlButtonVariant.primary,
            loading: saving,
            loadingLabel: 'Saving…',
            // Disabled only while the form is incomplete (no new status,
            // or a discharge without a reason).
            onPressed: canSave ? _save : null,
          ),
        SizedBox(height: t.space.xxs),
        if (saving)
          Container(
            constraints: BoxConstraints(minHeight: t.space.touchMin),
            alignment: Alignment.center,
            child: Text(
              'Waiting for the server',
              style: t.typography.subhead.copyWith(color: c.textSecondary),
            ),
          )
        else
          WlButton(
            label: 'Cancel',
            variant: WlButtonVariant.text,
            dense: true,
            onPressed: _close,
          ),
      ],
    );
  }
}

/// Radio row: radio, status icon circle (colour + icon), label, and
/// "Current · since 09:52" on the patient's current status.
class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.current,
    required this.onTap,
    this.since,
  });

  final PatientStatus status;
  final bool selected;
  final bool current;
  final String? since;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = c.status(status);
    return Semantics(
      key: ValueKey('status-option-${status.name}'),
      label: current ? '${s.label}, current status' : s.label,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: onTap != null,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radius.inputBr,
        child: AnimatedContainer(
          duration: WlMotion.duration(context, t.motion.fast),
          constraints: BoxConstraints(minHeight: t.space.action),
          padding: EdgeInsets.symmetric(
            horizontal: selected ? t.space.sm + 1 : t.space.sm + 2,
            vertical: t.space.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surface,
            borderRadius: t.radius.inputBr,
            border: Border.all(
              color: selected ? c.primaryInk : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? c.primaryInk : c.borderStrong,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: c.primaryInk,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: t.space.sm),
              Container(
                width: t.space.xl,
                height: t.space.xl,
                decoration: BoxDecoration(color: s.bg, shape: BoxShape.circle),
                child: Icon(WlIcons.forStatus(status), size: 16, color: s.fg),
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Wrap(
                  spacing: t.space.xs,
                  runSpacing: t.space.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      s.label,
                      style: t.typography.callout.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (current)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: t.space.xs,
                          vertical: t.space.xxs / 2,
                        ),
                        decoration: BoxDecoration(
                          color: s.bg,
                          borderRadius: BorderRadius.circular(
                            t.radius.chip - 2,
                          ),
                        ),
                        child: Text(
                          since == null ? 'Current' : 'Current · since $since',
                          style: t.typography
                              .tabular(t.typography.caption)
                              .copyWith(
                                color: s.fg,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({
    required this.controller,
    required this.required,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final edge = required ? c.danger : c.borderStrong;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: t.radius.inputBr,
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: 'Reason',
            children: [
              TextSpan(
                text: required ? ' · required for discharge' : ' (optional)',
                style: TextStyle(
                  color: required ? c.danger : c.textSecondary,
                  fontWeight: required ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
          style: t.typography.subhead.copyWith(
            color: c.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: t.space.xs - 2),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: t.radius.inputBr,
            boxShadow: required
                ? [BoxShadow(color: c.dangerBg, spreadRadius: 3)]
                : null,
          ),
          child: TextField(
            key: const ValueKey('status-reason'),
            controller: controller,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            style: t.typography.body.copyWith(color: c.text),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.surface,
              isDense: true,
              contentPadding: EdgeInsets.all(t.space.sm),
              hintText: required
                  ? 'e.g. Discharged home with oral antibiotics'
                  : null,
              hintStyle: t.typography.body.copyWith(color: c.textSecondary),
              border: border(edge),
              enabledBorder: border(edge),
              disabledBorder: border(c.border),
              focusedBorder: border(required ? c.danger : c.primary, 2),
            ),
          ),
        ),
      ],
    );
  }
}
