// Builds the demo hospital from design/handoff/sample-data.json (bundled as
// assets/demo/sample-data.json). The 12 named patients come from the design;
// 116 more are generated deterministically so the totals match the design
// (128 patients, 57 admitted, 54 in treatment, 17 ready, 42 transfers today).
// SIMULATION ONLY: every name and ID is fictional.

import 'dart:convert';
import 'dart:math';

import '../../domain/models.dart';

class DemoSeed {
  DemoSeed({
    required this.departments,
    required this.staff,
    required this.patients,
    required this.events,
    required this.identificationsNfc,
    required this.identificationsQr,
  });

  final List<Department> departments;
  final List<StaffMember> staff;
  final List<Patient> patients;
  final List<HistoryEvent> events;
  final int identificationsNfc;
  final int identificationsQr;

  /// Demo sign-in accounts (fictional). Password for all: [demoPassword].
  static const String demoPassword = 'wardline';

  static String emailFor(String name) {
    final ascii = name
        .replaceFirst('Dr ', '')
        .toLowerCase()
        .replaceAll('ą', 'a')
        .replaceAll('ć', 'c')
        .replaceAll('ę', 'e')
        .replaceAll('ł', 'l')
        .replaceAll('ń', 'n')
        .replaceAll('ó', 'o')
        .replaceAll('ś', 's')
        .replaceAll('ź', 'z')
        .replaceAll('ż', 'z')
        .replaceAll(' ', '.');
    return '$ascii@wardline.test';
  }

  /// Times in the design are relative to "now" = 10:46. Demo events keep the
  /// same distance from the real clock.
  static DemoSeed fromJson(String source, {required DateTime now}) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final designNow = DateTime.parse(json['now'] as String);
    DateTime at(String hhmm) {
      final parts = hhmm.split(':').map(int.parse).toList();
      final t = DateTime(
        designNow.year,
        designNow.month,
        designNow.day,
        parts[0],
        parts[1],
      );
      final designLocal = DateTime(
        designNow.year,
        designNow.month,
        designNow.day,
        10,
        46,
      );
      return now.subtract(designLocal.difference(t));
    }

    final departments = [
      for (final d
          in (json['departments'] as List).cast<Map<String, dynamic>>())
        Department(
          code: d['code'] as String,
          name: d['name'] as String,
          shortName: d['short'] as String?,
          kind: DepartmentKind.values.byName(d['kind'] as String),
          floor: d['floor'] as int,
          beds: d['beds'] as int,
          map: MapRect(
            (d['map']['x'] as num).toDouble(),
            (d['map']['y'] as num).toDouble(),
            (d['map']['w'] as num).toDouble(),
            (d['map']['d'] as num).toDouble(),
          ),
        ),
    ];
    final occupiedTarget = {
      for (final d
          in (json['departments'] as List).cast<Map<String, dynamic>>())
        d['code'] as String: d['occupied'] as int,
    };

    final staff = [
      for (final (i, s)
          in (json['staff'] as List).cast<Map<String, dynamic>>().indexed)
        StaffMember(
          id: 'staff-$i',
          name: s['name'] as String,
          role: UserRole.values.byName(s['role'] as String),
          email: emailFor(s['name'] as String),
          homeDepartment: s['home'] as String?,
          shiftLabel: s['shift'] as String?,
        ),
    ];
    UserRole roleOf(String name) =>
        staff.firstWhere((s) => s.name == name, orElse: () => staff.first).role;

    final rnd = Random(20261113);
    final patients = <Patient>[];
    final events = <HistoryEvent>[];
    var eventSeq = 0;
    String nextId() => 'evt-${eventSeq++}';

    // Named patients from the design.
    for (final p in (json['patients'] as List).cast<Map<String, dynamic>>()) {
      final name = (p['name'] as String).split(' ');
      final status = PatientStatusX.parse(p['status'] as String);
      final locSince = p['locationSince'] != null
          ? at(p['locationSince'] as String)
          : now.subtract(Duration(minutes: 20 + rnd.nextInt(200)));
      final statusSince = p['statusSince'] != null
          ? at(p['statusSince'] as String)
          : locSince.subtract(Duration(minutes: rnd.nextInt(40)));
      final admitted = p['admitted'] != null
          ? at((p['admitted'] as String).split('T').last)
          : statusSince.subtract(Duration(minutes: 30 + rnd.nextInt(600)));
      patients.add(
        Patient(
          id: 'p-${p['code']}',
          code: p['code'] as String,
          firstName: name.first,
          lastName: name.sublist(1).join(' '),
          age: p['age'] as int,
          condition:
              (p['condition'] as String?) ??
              _conditions[rnd.nextInt(_conditions.length)],
          admittedAt: admitted,
          location: p['location'] as String,
          locationSince: locSince,
          status: status,
          statusSince: statusSince,
          version: 1,
          locationBy: staff[rnd.nextInt(3)].name,
        ),
      );
    }

    // Jan's day (Profile timeline, flows 1–3).
    final jan = patients.first;
    var janVersion = 0;
    for (final e in (json['janToday'] as List).cast<Map<String, dynamic>>()) {
      janVersion++;
      final by = e['by'] as String;
      final when = at(e['at'] as String);
      switch (e['type']) {
        case 'admission':
        case 'transfer':
          events.add(
            LocationEvent(
              id: nextId(),
              patientId: jan.id,
              at: when,
              byName: by,
              byRole: roleOf(by),
              from: e['from'] as String?,
              to: e['to'] as String,
              identifiedBy: e['type'] == 'admission' ? null : 'NFC',
            ),
          );
        case 'status':
          events.add(
            StatusEvent(
              id: nextId(),
              patientId: jan.id,
              at: when,
              byName: by,
              byRole: roleOf(by),
              from: PatientStatusX.parse(e['from'] as String),
              to: PatientStatusX.parse(e['to'] as String),
            ),
          );
      }
    }
    patients[0] = jan.copyWith(version: janVersion, locationBy: 'Ewa Lis');

    // Generated patients so department occupancy matches the design.
    final totals = json['totals'] as Map<String, dynamic>;
    final statusPool = <PatientStatus>[
      ...List.filled(
        (totals['admitted'] as int) - _count(patients, PatientStatus.admitted),
        PatientStatus.admitted,
      ),
      ...List.filled(
        (totals['inTreatment'] as int) -
            _count(patients, PatientStatus.inTreatment),
        PatientStatus.inTreatment,
      ),
      ...List.filled(
        (totals['readyForDischarge'] as int) -
            _count(patients, PatientStatus.readyForDischarge),
        PatientStatus.readyForDischarge,
      ),
    ]..shuffle(rnd);
    final codes = patients.map((p) => p.code).toSet();
    var si = 0;
    for (final d in departments) {
      final missing =
          occupiedTarget[d.code]! -
          patients.where((p) => p.location == d.code).length;
      for (var i = 0; i < missing; i++) {
        String code;
        do {
          code =
              'HPT-${List.generate(8, (_) => _crockford[rnd.nextInt(_crockford.length)]).join()}';
        } while (!codes.add(code));
        final female = rnd.nextBool();
        final first = female
            ? _femaleFirst[rnd.nextInt(_femaleFirst.length)]
            : _maleFirst[rnd.nextInt(_maleFirst.length)];
        var last = _lastNames[rnd.nextInt(_lastNames.length)];
        if (female && last.endsWith('ski')) {
          last = '${last.substring(0, last.length - 3)}ska';
        }
        if (female && last.endsWith('cki')) {
          last = '${last.substring(0, last.length - 3)}cka';
        }
        final locSince = now.subtract(Duration(minutes: 15 + rnd.nextInt(420)));
        final admitted = locSince.subtract(
          Duration(minutes: rnd.nextInt(60 * 30)),
        );
        final status = si < statusPool.length
            ? statusPool[si++]
            : PatientStatus.admitted;
        final p = Patient(
          id: 'p-$code',
          code: code,
          firstName: first,
          lastName: last,
          age: 18 + rnd.nextInt(75),
          condition: _conditions[rnd.nextInt(_conditions.length)],
          admittedAt: admitted,
          location: d.code,
          locationSince: locSince,
          status: status,
          statusSince: locSince.add(Duration(minutes: rnd.nextInt(10))),
          version: 2,
          locationBy: staff[rnd.nextInt(3)].name,
        );
        patients.add(p);
        events.add(
          LocationEvent(
            id: nextId(),
            patientId: p.id,
            at: admitted,
            byName: p.locationBy!,
            byRole: UserRole.nurse,
            to: rnd.nextBool() ? 'ER' : 'ADM',
          ),
        );
      }
    }

    // Transfers today, per hour as in the design chart (Jan's 3 included).
    final perHour = (json['transfersPerHourToday'] as List).cast<int>();
    final janTransfers = events
        .whereType<LocationEvent>()
        .where((e) => e.patientId == jan.id && !e.isAdmission)
        .map((e) => _designHour(e.at, now))
        .toList();
    final nurses = staff.where((s) => s.role == UserRole.nurse).toList();
    for (var h = 0; h < perHour.length; h++) {
      final need = perHour[h] - janTransfers.where((x) => x == h).length;
      for (var i = 0; i < need; i++) {
        final p = patients[12 + rnd.nextInt(patients.length - 12)];
        final from = departments[rnd.nextInt(departments.length)].code;
        final minute = rnd.nextInt(h == perHour.length - 1 ? 46 : 60);
        final when = at(
          '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        );
        if (when.isAfter(now)) continue;
        final nurse = nurses[rnd.nextInt(nurses.length)];
        events.add(
          LocationEvent(
            id: nextId(),
            patientId: p.id,
            at: when,
            byName: nurse.name,
            byRole: UserRole.nurse,
            from: from == p.location ? 'ER' : from,
            to: p.location,
            identifiedBy: rnd.nextInt(4) == 0 ? 'QR' : 'NFC',
          ),
        );
      }
    }
    // A few status changes today for the doctor's feed.
    final doctors = staff.where((s) => s.role == UserRole.doctor).toList();
    for (final p
        in patients
            .skip(12)
            .where((p) => p.status != PatientStatus.admitted)
            .take(14)) {
      final doc = doctors[rnd.nextInt(doctors.length)];
      events.add(
        StatusEvent(
          id: nextId(),
          patientId: p.id,
          at: p.statusSince,
          byName: doc.name,
          byRole: UserRole.doctor,
          from: p.status == PatientStatus.readyForDischarge
              ? PatientStatus.inTreatment
              : PatientStatus.admitted,
          to: p.status,
        ),
      );
    }
    events.sort((a, b) => b.at.compareTo(a.at));

    // Keep "since … · by …" consistent with the newest transfer.
    for (var i = 12; i < patients.length; i++) {
      final p = patients[i];
      final last = events.whereType<LocationEvent>().firstWhere(
        (e) => e.patientId == p.id,
      );
      patients[i] = p.copyWith(
        locationSince: last.at,
        locationBy: last.byName,
        statusSince: p.statusSince.isAfter(last.at) ? p.statusSince : last.at,
      );
    }

    final ids = json['identificationsToday'] as Map<String, dynamic>;
    return DemoSeed(
      departments: departments,
      staff: staff,
      patients: patients,
      events: events,
      identificationsNfc: ids['nfc'] as int,
      identificationsQr: ids['qr'] as int,
    );
  }

  /// Hour bucket (0..10) of an event on the design clock.
  static int _designHour(DateTime t, DateTime now) {
    final minutesBefore = now.difference(t).inMinutes;
    final designMinute = 10 * 60 + 46 - minutesBefore;
    return designMinute ~/ 60;
  }

  static int _count(List<Patient> ps, PatientStatus s) =>
      ps.where((p) => p.status == s).length;

  static const String _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const List<String> _femaleFirst = [
    'Anna',
    'Maria',
    'Katarzyna',
    'Małgorzata',
    'Agnieszka',
    'Barbara',
    'Ewa',
    'Krystyna',
    'Elżbieta',
    'Zofia',
    'Joanna',
    'Teresa',
    'Danuta',
    'Monika',
    'Halina',
    'Irena',
    'Jadwiga',
    'Natalia',
    'Alicja',
    'Iwona',
  ];
  static const List<String> _maleFirst = [
    'Piotr',
    'Krzysztof',
    'Andrzej',
    'Tomasz',
    'Paweł',
    'Jan',
    'Michał',
    'Marcin',
    'Stanisław',
    'Jakub',
    'Adam',
    'Marek',
    'Łukasz',
    'Grzegorz',
    'Mateusz',
    'Wojciech',
    'Mariusz',
    'Dariusz',
    'Zbigniew',
    'Jerzy',
  ];
  static const List<String> _lastNames = [
    'Nowicki',
    'Wróblewski',
    'Kaczmarek',
    'Piotrowski',
    'Grabowski',
    'Pawłowski',
    'Michalski',
    'Krajewski',
    'Zalewski',
    'Jasiński',
    'Wieczorek',
    'Adamczyk',
    'Dudek',
    'Sikora',
    'Baran',
    'Rutkowski',
    'Ostrowski',
    'Malinowski',
    'Borkowski',
    'Czarnecki',
    'Sawicki',
    'Kubiak',
    'Wysocki',
    'Kalinowski',
    'Głowacki',
    'Majewski',
    'Olszewski',
    'Stępień',
    'Jaworski',
    'Zawadzki',
    'Tomaszewski',
    'Pietrzak',
    'Marciniak',
    'Kowalczuk',
    'Lis',
  ];
  static const List<String> _conditions = [
    'Pneumonia',
    'Hip fracture',
    'Chest pain',
    'Appendicitis',
    'Stroke',
    'Heart failure',
    'Diabetes, uncontrolled',
    'Kidney stones',
    'Sepsis',
    'Concussion',
    'Asthma attack',
    'Atrial fibrillation',
    'Cellulitis',
    'Post-op recovery',
    'Gastroenteritis',
    'Knee replacement',
  ];
}
