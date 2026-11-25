import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';
import '../../status/presentation/change_status_sheet.dart';
import '../../transfer/presentation/choose_destination_sheet.dart';
import 'patient_profile_sections.dart';

/// Patient profile (`/patients/:id`, artboards `Profile`, `ProfileDoctor`,
/// `ProfileOffline`, `Platform` AX text). Status and location are separate
/// rows; the sticky action depends on the role (Nurse: Transfer patient,
/// Doctor: Change status, Admin: none) and is replaced offline.
class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({required this.patientId, super.key});

  final String patientId;

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  /// History ids present when the screen opened; later ones are highlighted.
  Set<String>? _seenEvents;

  /// Changes on every update of the patient ("just updated" highlight).
  Object? _cardPulse;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.patients);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(patientProvider(widget.patientId), (prev, next) {
      if (prev != null && next != null && prev.version != next.version) {
        setState(() => _cardPulse = next.version);
      }
    });
    final t = WlTokens.of(context);
    final c = t.colors;
    final snap = ref.watch(hospitalProvider);
    final patient = ref.watch(patientProvider(widget.patientId));
    final history = ref.watch(patientHistoryProvider(widget.patientId));
    final conn = ref.watch(connectivityProvider);
    final me = ref.watch(sessionProvider);
    final offline = !conn.online;
    final syncedAt = hm(conn.syncedAt);
    final stale =
        DateTime.now().difference(conn.syncedAt) > const Duration(minutes: 15);

    final header = WlLargeTitle(
      title: 'Patient',
      showBack: true,
      onBack: _back,
      trailing: [WlConnectionIndicator(state: conn.state)],
    );

    if (patient == null) {
      return ColoredBox(
        color: c.page,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: SingleChildScrollView(
                  child: offline
                      ? WlErrorState(
                          tone: WlErrorTone.neutral,
                          icon: WlIcons.wifiOff,
                          title: 'Connect to load',
                          body: "This patient hasn't been loaded on this device yet. Connect to the internet to open the record.",
                          secondary: WlStateAction('Back to patients', _back),
                        )
                      : WlErrorState(
                          title: 'Patient not found',
                          body: 'No patient has this ID. Check the band, or find the patient by name.',
                          primary: WlStateAction('Back to patients', _back),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final seen = _seenEvents ??= {for (final e in history) e.id};
    final highlight = {
      for (final e in history)
        if (!seen.contains(e.id)) e.id,
    };
    final dept = snap.department(patient.location);
    final floor = profileFloor(dept);
    final locationName = dept?.name ?? patient.location;
    final by = patient.locationBy;
    final locationDetail = [
      if (floor.isNotEmpty) floor,
      'since ${hm(patient.locationSince)}',
      if (by != null) 'by $by',
    ].join(' · ');

    final statusEvents = history.whereType<StatusEvent>().toList();
    final lastStatus = statusEvents.isEmpty ? null : statusEvents.first;
    final admission = history
        .whereType<LocationEvent>()
        .where((e) => e.isAdmission)
        .lastOrNull;
    final reachedAt = <PatientStatus, DateTime>{
      PatientStatus.admitted: admission?.at ?? patient.admittedAt,
      // history is newest first: the last write wins with the newest time.
      for (final e in statusEvents.reversed) e.to: e.at,
    };

    final timeline = buildTimeline(
      snapshot: snap,
      patient: patient,
      history: history,
      highlight: highlight,
    );

    final content = <Widget>[
      if (offline) ...[
        WlOfflineBanner(syncedAt: syncedAt),
        SizedBox(height: t.space.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: WlCacheBadge(syncedAt: syncedAt, stale: stale),
        ),
        SizedBox(height: t.space.sm),
      ] else if (conn.backOnlineAt != null) ...[
        WlOfflineBanner.backOnline(syncedAt: syncedAt),
        SizedBox(height: t.space.sm),
      ],
      WlPatientCard.expanded(
        name: patient.fullName,
        age: patient.age,
        status: patient.status,
        patientCode: patient.code,
        locationName: locationName,
        locationDetail: locationDetail,
        highlightKey: _cardPulse,
        cachedAsOf: offline ? syncedAt : null,
      ),
      SizedBox(height: t.space.lg),
      ProfileSection(
        title: 'Medical info',
        child: ProfileInfoRows(
          rows: [
            ('Condition', patient.condition),
            ('Admitted', admittedLabel(patient.admittedAt, DateTime.now())),
            if (admission != null)
              (
                'Admitted via',
                snap.department(admission.to)?.name ?? admission.to,
              ),
          ],
        ),
      ),
      SizedBox(height: t.space.lg),
      ProfileSection(
        title: 'Location',
        padding: EdgeInsets.all(t.space.xs),
        child: WlMiniMap(
          floor: dept?.floor ?? 0,
          highlightDepartment: patient.location,
          patientInitials: WlInitialsAvatar.initialsOf(patient.fullName),
          onTap: () => context.push(
            Routes.mapFor(
              floor: dept?.floor,
              department: patient.location,
              patientId: patient.id,
            ),
          ),
        ),
      ),
      SizedBox(height: t.space.lg),
      ProfileSection(
        title: 'Status',
        padding: EdgeInsets.all(t.space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: t.space.sm,
              runSpacing: t.space.xs,
              children: [
                WlStatusChip(patient.status),
                Text(
                  [
                    'since ${hm(patient.statusSince)}',
                    if (lastStatus != null && lastStatus.to == patient.status)
                      lastStatus.byName,
                  ].join('\n'),
                  textAlign: TextAlign.end,
                  style: t.typography
                      .tabular(t.typography.caption)
                      .copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                ),
              ],
            ),
            SizedBox(height: t.space.md),
            StatusStepper(current: patient.status, reachedAt: reachedAt),
          ],
        ),
      ),
      SizedBox(height: t.space.lg),
      ProfileSection(
        title: 'History',
        trailing: history.length == 1 ? '1 event' : '${history.length} events',
        padding: EdgeInsets.fromLTRB(
          t.space.sm,
          t.space.sm,
          t.space.sm,
          t.space.sm,
        ),
        child: history.isEmpty
            ? Padding(
                padding: EdgeInsets.all(t.space.sm),
                child: Text(
                  'No history yet',
                  style: t.typography.subhead.copyWith(color: c.textSecondary),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: timeline,
              ),
      ),
      SizedBox(height: t.space.lg),
    ];

    final action = _actionBar(context, patient, me, offline, by);

    return ColoredBox(
      color: c.page,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  t.space.gutter,
                  t.space.xxs,
                  t.space.gutter,
                  t.space.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: content,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }

  /// Sticky bottom action. Role-forbidden actions are not rendered; offline
  /// the write action is replaced by a note (product rules 2 and 5).
  Widget? _actionBar(
    BuildContext context,
    Patient p,
    StaffMember? me,
    bool offline,
    String? movedBy,
  ) {
    final role = me?.role;
    if (role == null || role == UserRole.admin) return null;
    final t = WlTokens.of(context);
    final c = t.colors;

    final String caption;
    if (role == UserRole.doctor) {
      final statusLabel = WlStatusLabels.of(p.status);
      final lastStatus = ref
          .read(patientHistoryProvider(p.id))
          .whereType<StatusEvent>()
          .firstOrNull;
      final setBy = lastStatus == null || lastStatus.to != p.status
          ? null
          : lastStatus.byName == me!.name
          ? 'you'
          : lastStatus.byName;
      caption =
          '$statusLabel since ${hm(p.statusSince)}'
          '${setBy == null ? '' : ' · set by $setBy'}';
    } else {
      caption =
          'Last moved ${timeAgo(p.locationSince, DateTime.now())}'
          '${movedBy == null ? '' : ' by $movedBy'}';
    }

    final Widget control = offline
        ? WlOfflineActionNote(
            detail: role == UserRole.nurse
                ? "Transfers resume when you're back online."
                : null,
          )
        : role == UserRole.nurse
        ? WlButton(
            label: 'Transfer patient',
            icon: WlIcons.transfer,
            onPressed: () => showChooseDestinationSheet(context, patient: p),
          )
        : WlButton(
            label: 'Change status',
            icon: WlIcons.status,
            onPressed: () => showChangeStatusSheet(context, patient: p),
          );

    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        t.space.gutter,
        t.space.sm,
        t.space.gutter,
        t.space.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!offline) ...[
            Text(
              caption,
              textAlign: TextAlign.center,
              style: t.typography
                  .tabular(t.typography.caption)
                  .copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
            ),
            SizedBox(height: t.space.xs),
          ],
          control,
        ],
      ),
    );
  }
}
