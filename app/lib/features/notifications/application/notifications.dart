// Notifications are derived from the realtime history (screens.md):
// filtered by role + home department, own actions never notify.
// Nurse: admissions (hospital-wide, plus ER/ADM → home ward), ready for
// discharge and discharged in the home ward.
// Doctor: arrivals in / departures from their ward, status changes there.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import '../../dashboard/application/clock.dart';

enum NotificationKind {
  admission,
  readyForDischarge,
  discharged,
  arrived,
  left,
  statusChanged,
}

@immutable
class WardNotification {
  const WardNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    required this.patientId,
    this.status,
  });

  /// The history event id.
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime at;
  final String patientId;

  /// Target status for status notifications (icon + colour).
  final PatientStatus? status;
}

/// "Anna Nowak" → "A. Nowak"; "Dr Julia Wróbel" → "Dr J. Wróbel".
String shortStaffName(String name) {
  final dr = name.startsWith('Dr ');
  final parts = name.replaceFirst('Dr ', '').split(' ');
  if (parts.length < 2) return name;
  final short = '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
  return dr ? 'Dr $short' : short;
}

/// Line under the title: "For nurses: admissions & discharges · Internal
/// Medicine". Null for roles without notifications.
String? notificationScope(StaffMember me, HospitalSnapshot s) {
  final home = s.department(me.homeDepartment ?? '')?.name;
  return switch (me.role) {
    UserRole.nurse =>
      'For nurses: admissions & discharges${home == null ? '' : ' · $home'}',
    UserRole.doctor =>
      'For doctors: arrivals in ${home ?? 'your ward'}, status changes',
    UserRole.admin => null,
  };
}

/// Empty state body: says what will appear here.
String notificationEmptyBody(StaffMember me, HospitalSnapshot s) {
  final home = s.department(me.homeDepartment ?? '')?.name ?? 'your ward';
  return switch (me.role) {
    UserRole.nurse =>
      'New admissions and discharges in $home will show up here.',
    UserRole.doctor =>
      'Arrivals in $home and status changes there will show up here.',
    UserRole.admin =>
      'Admins don\'t get ward notifications. Nurses and doctors see them '
          'for their home department.',
  };
}

/// Today and yesterday, newest first.
List<WardNotification> deriveNotifications(
  HospitalSnapshot s,
  StaffMember me,
  AppSettings settings,
  DateTime now,
) {
  final home = me.homeDepartment;
  if (home == null || me.role == UserRole.admin) return const [];
  final homeName = s.department(home)?.name ?? home;
  final since = startOfDay(now).subtract(const Duration(days: 1));
  String dept(String? code) =>
      code == null ? '' : (s.department(code)?.name ?? code);

  final out = <WardNotification>[];
  for (final e in s.events) {
    if (e.at.isBefore(since)) continue;
    if (e.byName == me.name) continue; // own actions never notify
    final p = s.patient(e.patientId);
    if (p == null) continue;
    final by = shortStaffName(e.byName);
    WardNotification n(
      NotificationKind kind,
      String title,
      String body, {
      PatientStatus? status,
    }) => WardNotification(
      id: e.id,
      kind: kind,
      title: title,
      body: body,
      at: e.at,
      patientId: p.id,
      status: status,
    );

    switch (me.role) {
      case UserRole.nurse:
        switch (e) {
          // New patients anywhere (Account artboard: Emergency, Neurology)
          // and patients sent up to the ward from ER / Admissions.
          case LocationEvent(:final from, :final to)
              when (from == null ||
                      (to == home && (from == 'ER' || from == 'ADM'))) &&
                  settings.notifyArrivals:
            out.add(
              n(
                NotificationKind.admission,
                'New admission',
                [
                  '${p.fullName}, ${p.age}',
                  if (from != null) '${dept(from)} → $homeName' else dept(to),
                  p.condition,
                ].join(' · '),
              ),
            );
          case StatusEvent(:final to)
              when p.location == home &&
                  to == PatientStatus.readyForDischarge &&
                  settings.notifyDischarges:
            out.add(
              n(
                NotificationKind.readyForDischarge,
                'Ready for discharge',
                '${p.fullName} · $homeName. Arrange transport and paperwork.',
                status: to,
              ),
            );
          case StatusEvent(:final to)
              when p.location == home &&
                  to == PatientStatus.discharged &&
                  settings.notifyDischarges:
            out.add(
              n(
                NotificationKind.discharged,
                'Discharged',
                '${p.fullName} · $homeName. A bed is free.',
                status: to,
              ),
            );
          default:
            break;
        }
      case UserRole.doctor:
        switch (e) {
          case LocationEvent(:final from, :final to)
              when to == home && settings.notifyArrivals:
            out.add(
              n(
                NotificationKind.arrived,
                'Arrived in your ward',
                from == null
                    ? '${p.fullName} · new admission · by $by'
                    : '${p.fullName} ← ${dept(from)} · by $by',
              ),
            );
          case LocationEvent(:final from, :final to)
              when from == home && settings.notifyArrivals:
            out.add(
              n(
                NotificationKind.left,
                'Left your ward',
                '${p.fullName} → ${dept(to)} · by $by',
              ),
            );
          case StatusEvent(:final to)
              when p.location == home && settings.notifyStatus:
            out.add(
              n(
                NotificationKind.statusChanged,
                'Status changed',
                '${p.fullName} → ${WlStatusLabels.of(to)} · by $by',
                status: to,
              ),
            );
          default:
            break;
        }
      case UserRole.admin:
        break;
    }
  }
  return out;
}

final notificationsProvider = Provider<List<WardNotification>>((ref) {
  final me = ref.watch(sessionProvider);
  if (me == null) return const [];
  return deriveNotifications(
    ref.watch(hospitalProvider),
    me,
    ref.watch(settingsProvider),
    ref.watch(clockProvider)(),
  );
});

/// Read state, kept on this device for the session. The demo has no
/// server-side read receipts: anything older than an hour when you signed
/// in counts as seen.
@immutable
class NotificationReadState {
  const NotificationReadState({
    required this.seenBefore,
    this.readIds = const {},
  });

  final DateTime seenBefore;
  final Set<String> readIds;

  bool isRead(WardNotification n) =>
      !n.at.isAfter(seenBefore) || readIds.contains(n.id);
}

final notificationReadProvider =
    NotifierProvider<NotificationReadController, NotificationReadState>(
      NotificationReadController.new,
    );

class NotificationReadController extends Notifier<NotificationReadState> {
  @override
  NotificationReadState build() {
    ref.watch(sessionProvider.select((s) => s?.id));
    return NotificationReadState(
      seenBefore: ref.read(clockProvider)().subtract(const Duration(hours: 1)),
    );
  }

  void markRead(String id) => state = NotificationReadState(
    seenBefore: state.seenBefore,
    readIds: {...state.readIds, id},
  );

  void markAllRead(Iterable<WardNotification> all) =>
      state = NotificationReadState(
        seenBefore: state.seenBefore,
        readIds: {...state.readIds, for (final n in all) n.id},
      );
}

final unreadNotificationCountProvider = Provider<int>((ref) {
  final read = ref.watch(notificationReadProvider);
  return ref.watch(notificationsProvider).where((n) => !read.isRead(n)).length;
});
