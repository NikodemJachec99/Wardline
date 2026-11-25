import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/domain/history_feed.dart';
import 'package:wardline/domain/models.dart';

LocationEvent _move(String id, DateTime at, {String? from = 'ER'}) =>
    LocationEvent(
      id: id,
      patientId: 'p-1',
      at: at,
      byName: 'Anna Nowak',
      byRole: UserRole.nurse,
      from: from,
      to: 'INT',
    );

StatusEvent _status(String id, DateTime at) => StatusEvent(
  id: id,
  patientId: 'p-1',
  at: at,
  byName: 'Dr Piotr Lis',
  byRole: UserRole.doctor,
  from: PatientStatus.admitted,
  to: PatientStatus.inTreatment,
);

DateTime _at(int h, int m) => DateTime(2026, 11, 13, h, m);

void main() {
  test('interleaves both tables newest first by server time', () {
    final merged = mergeHistory(
      [_move('t1', _at(9, 0)), _move('t2', _at(10, 30))],
      [_status('s1', _at(9, 45)), _status('s2', _at(10, 50))],
    );
    expect(merged.map((e) => e.id), ['s2', 't2', 's1', 't1']);
  });

  test('accepts inputs in any order', () {
    final merged = mergeHistory(
      [_move('t1', _at(9, 0)), _move('t2', _at(10, 30))].reversed,
      [_status('s2', _at(10, 50)), _status('s1', _at(9, 45))],
    );
    expect(merged.map((e) => e.id), ['s2', 't2', 's1', 't1']);
  });

  test('keeps admissions (transfer with no from)', () {
    final merged = mergeHistory([_move('a1', _at(8, 0), from: null)], []);
    expect(merged.single, isA<LocationEvent>());
    expect((merged.single as LocationEvent).isAdmission, isTrue);
  });

  test('equal times: transfer before status change, then by id', () {
    final t = _at(10, 0);
    final merged = mergeHistory(
      [_move('t-b', t), _move('t-a', t)],
      [_status('s-a', t)],
    );
    expect(merged.map((e) => e.id), ['t-a', 't-b', 's-a']);
  });

  test('does not modify the inputs', () {
    final transfers = [_move('t1', _at(9, 0)), _move('t2', _at(10, 0))];
    mergeHistory(transfers, const []);
    expect(transfers.map((e) => e.id), ['t1', 't2']);
  });

  test('empty tables give an empty feed', () {
    expect(mergeHistory(const [], const []), isEmpty);
  });
}
