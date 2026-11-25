import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/wl_tokens.dart';
import '../../../../core/widgets/wl/wl.dart';
import '../../../../domain/models.dart';
import '../scan_copy.dart';

/// What the user picked in the quick summary. The scan screen acts on it
/// after the sheet has closed.
enum ScanSummaryAction { viewProfile, history, transfer, changeStatus }

/// Labels wider than this text scale stack vertically (platform-and-a11y.md).
bool _stacked(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > 1.3;

/// Quick summary after a successful read (`ScanSuccess`, flow 1 step 3):
/// name, ID, status chip, last location + time, actions by role. Opening it
/// changes nothing on the server.
class ScanSummarySheet extends StatelessWidget {
  const ScanSummarySheet({
    required this.patient,
    required this.locationName,
    required this.method,
    required this.scannedAt,
    required this.now,
    required this.role,
    required this.online,
    super.key,
  });

  final Patient patient;
  final String locationName;

  /// "NFC" or "QR" (`LocationEvent.identifiedBy`).
  final String method;
  final DateTime scannedAt;
  final DateTime now;
  final UserRole? role;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final stacked = _stacked(context);
    final nurse = role == UserRole.nurse;
    final doctor = role == UserRole.doctor;
    final hasRoleAction = nurse || doctor;
    final since = now.difference(patient.locationSince);

    final header = [
      Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              method == 'QR'
                  ? LucideIcons.scanQrCode
                  : LucideIcons.smartphoneNfc,
              size: 16,
              color: c.primaryInk,
            ),
            SizedBox(width: t.space.xxs + 2),
            Flexible(
              child: Text(
                ScanCopy.identified,
                style: t.typography.subhead.copyWith(
                  color: c.primaryInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      Text(
        '$method · ${hm(scannedAt)}',
        style: t.typography
            .tabular(t.typography.caption)
            .copyWith(color: c.textSecondary, fontWeight: FontWeight.w400),
      ),
    ];

    Widget row(String label, Widget value) {
      final l = Text(
        label,
        style: t.typography.subhead.copyWith(color: c.textSecondary),
      );
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md - 2,
          vertical: t.space.xs + 2,
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  l,
                  SizedBox(height: t.space.xxs),
                  value,
                ],
              )
            : Row(
                children: [
                  l,
                  SizedBox(width: t.space.sm),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: value,
                    ),
                  ),
                ],
              ),
      );
    }

    final location = Semantics(
      label:
          'Last location: $locationName, since ${hm(patient.locationSince)}, '
          '${duration(since)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: stacked
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(WlIcons.mapPin, size: 16, color: c.textSecondary),
              SizedBox(width: t.space.xxs + 2),
              Flexible(
                child: Text(
                  locationName,
                  textAlign: stacked ? TextAlign.start : TextAlign.end,
                  style: t.typography.callout.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'since ${hm(patient.locationSince)} · ${duration(since)}',
            style: t.typography
                .tabular(t.typography.caption)
                .copyWith(color: c.textSecondary, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );

    final Widget? roleAction = !hasRoleAction
        ? null
        : !online
        ? null
        : WlButton(
            label: nurse ? ScanCopy.transfer : ScanCopy.changeStatus,
            variant: WlButtonVariant.secondary,
            dense: true,
            onPressed: () => Navigator.of(context).pop(
              nurse
                  ? ScanSummaryAction.transfer
                  : ScanSummaryAction.changeStatus,
            ),
          );
    final history = WlButton(
      label: ScanCopy.history,
      icon: WlIcons.history,
      variant: WlButtonVariant.secondary,
      dense: true,
      onPressed: () => Navigator.of(context).pop(ScanSummaryAction.history),
    );

    final hint = online && hasRoleAction
        ? '${ScanCopy.nothingChanged} '
              '${nurse ? ScanCopy.nurseHint : ScanCopy.doctorHint}'
        : ScanCopy.nothingChanged;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: ScanCopy.identified,
      explicitChildNodes: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stacked)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: header,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: header[0]),
                  header[1],
                ],
              ),
            SizedBox(height: t.space.sm),
            Row(
              children: [
                WlInitialsAvatar.patient(patient.fullName, size: 56),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          patient.fullName,
                          style: t.typography.title2.copyWith(color: c.text),
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${patient.age} · ',
                              style: t.typography.tabular(t.typography.subhead),
                            ),
                            TextSpan(
                              text: patient.code,
                              style: t.typography.id.copyWith(
                                fontSize: t.typography.subhead.fontSize,
                              ),
                            ),
                          ],
                        ),
                        style: t.typography.subhead.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space.sm),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: t.radius.inputBr,
              ),
              child: Column(
                children: [
                  row(ScanCopy.status, WlStatusChip(patient.status)),
                  Divider(height: 1, thickness: 1, color: c.border),
                  row(ScanCopy.lastLocation, location),
                ],
              ),
            ),
            SizedBox(height: t.space.md),
            WlButton(
              label: ScanCopy.viewProfile,
              onPressed: () =>
                  Navigator.of(context).pop(ScanSummaryAction.viewProfile),
            ),
            SizedBox(height: t.space.xs),
            if (roleAction == null)
              history
            else if (stacked) ...[
              history,
              SizedBox(height: t.space.xs),
              roleAction,
            ] else
              Row(
                children: [
                  Expanded(child: history),
                  SizedBox(width: t.space.xs),
                  Expanded(child: roleAction),
                ],
              ),
            if (hasRoleAction && !online) ...[
              SizedBox(height: t.space.xs),
              const WlOfflineActionNote(),
            ],
            SizedBox(height: t.space.xs),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: t.typography.caption.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which button the user tapped on an issue sheet.
enum ScanIssueChoice { primary, secondary }

/// Invalid tag / unknown ID (`ScanEdge` columns 1–2): tinted icon, title,
/// body, primary + secondary action. Announced as an alert.
class ScanIssueSheet extends StatelessWidget {
  const ScanIssueSheet({
    required this.icon,
    required this.tone,
    required this.title,
    required this.semanticTitle,
    required this.body,
    required this.primaryLabel,
    this.secondaryLabel,
    super.key,
  });

  final IconData icon;
  final WlErrorTone tone;
  final InlineSpan title;
  final String semanticTitle;
  final String body;
  final String primaryLabel;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final (Color bg, Color fg) = switch (tone) {
      WlErrorTone.warning => (c.warningBg, c.warningFg),
      WlErrorTone.danger => (c.dangerBg, c.danger),
      WlErrorTone.neutral => (
        c.status(PatientStatus.discharged).bg,
        c.status(PatientStatus.discharged).fg,
      ),
    };
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: semanticTitle,
      explicitChildNodes: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: t.space.touchMin,
                height: t.space.touchMin,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 24, color: fg),
              ),
            ),
            SizedBox(height: t.space.sm),
            Semantics(
              liveRegion: true,
              header: true,
              label: semanticTitle,
              excludeSemantics: true,
              child: Text.rich(
                title,
                style: t.typography.title2.copyWith(color: c.text),
              ),
            ),
            SizedBox(height: t.space.xs - 2),
            Text(
              body,
              style: t.typography.body.copyWith(color: c.textSecondary),
            ),
            SizedBox(height: t.space.md),
            WlButton(
              label: primaryLabel,
              onPressed: () =>
                  Navigator.of(context).pop(ScanIssueChoice.primary),
            ),
            if (secondaryLabel != null) ...[
              SizedBox(height: t.space.xs),
              WlButton(
                label: secondaryLabel!,
                variant: WlButtonVariant.secondary,
                dense: true,
                onPressed: () =>
                    Navigator.of(context).pop(ScanIssueChoice.secondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
