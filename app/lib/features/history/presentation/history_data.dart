// Pure helpers for the three History screens: filters, sections, counts and
// the day-timeline summary. Kept free of widgets so tests can check the
// numbers against the snapshot directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';

/// "Now" for History (sections, "today", the timeline now marker).
/// Overridden in tests with the design clock (10:46).
final historyNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

enum HistoryKind { all, transfers, status }

enum HistoryRange { lastHour, today, twoDays }

enum DeptSegment { all, arrivals, departures, status }

extension HistoryRangeLabel on HistoryRange {
  String get label => switch (this) {
    HistoryRange.lastHour => 'Last hour',
    HistoryRange.today => 'Today',
    HistoryRange.twoDays => 'Yesterday and today',
  };

  /// Phrase for the empty state: "No transfers in Radiology today".
  String get phrase => switch (this) {
    HistoryRange.lastHour => 'in the last hour',
    HistoryRange.today => 'today',
    HistoryRange.twoDays => 'since yesterday',
  };
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

/// Department a patient was in at [at] (the newest location event at or
/// before it). Status rows have no location of their own.
String? locationAt(HospitalSnapshot s, String patientId, DateTime at) {
  for (final e in s.events) {
    if (e is LocationEvent && e.patientId == patientId && !e.at.isAfter(at)) {
      return e.to;
    }
  }
  return s.patient(patientId)?.location;
}

bool inRange(HistoryEvent e, HistoryRange range, DateTime now) =>
    switch (range) {
      HistoryRange.lastHour => !e.at.isBefore(
        now.subtract(const Duration(hours: 1)),
      ),
      HistoryRange.today => sameDay(e.at, now),
      HistoryRange.twoDays => !e.at.isBefore(
        startOfDay(now).subtract(const Duration(days: 1)),
      ),
    };

bool touchesDepartment(HospitalSnapshot s, HistoryEvent e, String code) =>
    switch (e) {
      LocationEvent(:final from, :final to) => from == code || to == code,
      StatusEvent() => locationAt(s, e.patientId, e.at) == code,
    };

/// Global History feed: union of both history tables, newest first.
List<HistoryEvent> filterHistory(
  HospitalSnapshot s, {
  required HistoryKind kind,
  required HistoryRange range,
  required DateTime now,
  String? department,
}) {
  return [
    for (final e in s.events)
      if (_kindMatches(e, kind) &&
          inRange(e, range, now) &&
          (department == null || touchesDepartment(s, e, department)))
        e,
  ];
}

bool _kindMatches(HistoryEvent e, HistoryKind kind) => switch (kind) {
  HistoryKind.all => true,
  HistoryKind.transfers => e is LocationEvent && !e.isAdmission,
  HistoryKind.status => e is StatusEvent,
};

/// One block of rows under a small uppercase header.
class HistorySection {
  const HistorySection(this.title, this.events);

  final String title;
  final List<HistoryEvent> events;
}

/// "Last 30 minutes", "Earlier today", "Yesterday", "Earlier".
List<HistorySection> sectionsFor(List<HistoryEvent> events, DateTime now) {
  final buckets = <String, List<HistoryEvent>>{};
  for (final e in events) {
    final String key;
    if (sameDay(e.at, now) && now.difference(e.at).inMinutes < 30) {
      key = 'Last 30 minutes';
    } else if (sameDay(e.at, now)) {
      key = 'Earlier today';
    } else if (sameDay(e.at, now.subtract(const Duration(days: 1)))) {
      key = 'Yesterday';
    } else {
      key = 'Earlier';
    }
    (buckets[key] ??= []).add(e);
  }
  return [
    for (final MapEntry(:key, :value) in buckets.entries)
      HistorySection(key, value),
  ];
}

/// Today's numbers for one department (Department history tiles).
class DepartmentDay {
  const DepartmentDay({
    required this.arrivals,
    required this.departures,
    required this.statusChanges,
    required this.occupied,
    required this.beds,
  });

  final int arrivals;
  final int departures;
  final int statusChanges;
  final int occupied;
  final int beds;

  int get percent => beds == 0 ? 0 : (occupied * 100 / beds).round();
}

/// Department feed for today: transfers in/out of [code] and status changes
/// of patients who were there at the time. Admissions count as arrivals.
List<HistoryEvent> departmentEvents(
  HospitalSnapshot s,
  String code,
  DateTime now, {
  DeptSegment segment = DeptSegment.all,
}) {
  return [
    for (final e in s.events)
      if (sameDay(e.at, now) && _deptMatches(s, e, code, segment)) e,
  ];
}

bool _deptMatches(
  HospitalSnapshot s,
  HistoryEvent e,
  String code,
  DeptSegment segment,
) {
  return switch ((e, segment)) {
    (LocationEvent(:final to), DeptSegment.arrivals) => to == code,
    (LocationEvent(:final from), DeptSegment.departures) => from == code,
    (LocationEvent(:final from, :final to), DeptSegment.all) =>
      from == code || to == code,
    (StatusEvent(), DeptSegment.all || DeptSegment.status) =>
      locationAt(s, e.patientId, e.at) == code,
    _ => false,
  };
}

DepartmentDay departmentDay(HospitalSnapshot s, String code, DateTime now) {
  var arrivals = 0;
  var departures = 0;
  var status = 0;
  for (final e in departmentEvents(s, code, now)) {
    switch (e) {
      case LocationEvent(:final from, :final to):
        if (to == code) arrivals++;
        if (from == code) departures++;
      case StatusEvent():
        status++;
    }
  }
  return DepartmentDay(
    arrivals: arrivals,
    departures: departures,
    statusChanges: status,
    occupied: s.occupancy(code),
    beds: s.department(code)?.beds ?? 0,
  );
}

/// How long the patient stayed in [code] before leaving with [out].
Duration? stayBefore(HospitalSnapshot s, LocationEvent out) {
  var past = false;
  for (final e in s.events) {
    if (identical(e, out)) {
      past = true;
      continue;
    }
    if (!past) continue;
    if (e is LocationEvent &&
        e.patientId == out.patientId &&
        e.to == out.from) {
      return out.at.difference(e.at);
    }
  }
  return null;
}

/// Transfers (not admissions) on [now]'s day, oldest first.
List<LocationEvent> transfersOn(HospitalSnapshot s, DateTime now) {
  final list = [
    for (final e in s.events)
      if (e is LocationEvent && !e.isAdmission && sameDay(e.at, now)) e,
  ];
  return list.reversed.toList();
}

/// "Peak 09:00–10:00 with 11 transfers" for the chart semantics.
String timelineSummary(List<LocationEvent> transfers) {
  if (transfers.isEmpty) return 'No transfers today';
  final perHour = List<int>.filled(24, 0);
  for (final e in transfers) {
    perHour[e.at.hour]++;
  }
  var peak = 0;
  for (var h = 1; h < 24; h++) {
    if (perHour[h] > perHour[peak]) peak = h;
  }
  final from = hm(DateTime(2000, 1, 1, peak));
  final to = peak == 23 ? '24:00' : hm(DateTime(2000, 1, 1, peak + 1));
  final n = perHour[peak];
  return 'Peak $from–$to with $n ${n == 1 ? 'transfer' : 'transfers'}';
}

/// "Anna Nowak" → "A. Nowak"; "Dr Piotr Zając" → "Dr P. Zając".
String shortStaffName(String name) {
  final dr = name.startsWith('Dr ');
  final parts = name.replaceFirst('Dr ', '').split(' ');
  if (parts.length < 2) return name;
  final short = '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
  return dr ? 'Dr $short' : short;
}

String roleLabel(UserRole role) => switch (role) {
  UserRole.nurse => 'Nurse',
  UserRole.doctor => 'Doctor',
  UserRole.admin => 'Admin',
};

String floorLabel(int floor) => floor == 0 ? 'Ground floor' : 'Floor $floor';

String deptName(HospitalSnapshot s, String? code) =>
    code == null ? '' : (s.department(code)?.shortName ?? code);
