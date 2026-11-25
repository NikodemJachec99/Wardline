import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/features/profile/presentation/profile_screen.dart';

DateTime _at(int day, int h, int m) => DateTime(2026, 11, day, h, m);

void main() {
  const day = 'Day shift 07:00–19:00';
  const night = 'Night shift 19:00–07:00';
  String? line(String? label, DateTime now) =>
      ProfileScreen.shiftLine(label, now);

  group('day shift', () {
    test('during the shift: time left', () {
      expect(
        line(day, _at(13, 10, 46)),
        'Day shift 07:00–19:00 · ends in 8 h 14 min',
      );
    });

    test('before it starts and once it ended: label only', () {
      expect(line(day, _at(13, 6, 59)), day);
      expect(line(day, _at(13, 19, 0)), day);
      expect(line(day, _at(13, 23, 0)), day);
    });
  });

  group('night shift past midnight', () {
    test('at the start: the full 12 h', () {
      expect(line(night, _at(13, 19, 0)), '$night · ends in 12 h');
    });

    test('before midnight: ends tomorrow morning', () {
      expect(line(night, _at(13, 23, 30)), '$night · ends in 7 h 30 min');
    });

    test('after midnight: started yesterday, ends this morning', () {
      expect(line(night, _at(14, 2, 15)), '$night · ends in 4 h 45 min');
      expect(line(night, _at(14, 6, 59)), '$night · ends in 1 min');
    });

    test('daytime, off shift: label only', () {
      expect(line(night, _at(14, 7, 0)), night);
      expect(line(night, _at(14, 12, 0)), night);
      expect(line(night, _at(14, 18, 59)), night);
    });

    test('across a month end', () {
      expect(
        line(night, DateTime(2026, 11, 30, 22, 0)),
        '$night · ends in 9 h',
      );
      expect(line(night, DateTime(2026, 12, 1, 1, 0)), '$night · ends in 6 h');
    });
  });

  group('labels', () {
    test('times only get a "Shift" prefix', () {
      expect(
        line('08:00–16:00', _at(13, 10, 46)),
        'Shift 08:00–16:00 · ends in 5 h 14 min',
      );
    });

    test('no times: label as is', () {
      expect(line('On call', _at(13, 10, 46)), 'On call');
    });

    test('no shift: nothing', () {
      expect(line(null, _at(13, 10, 46)), isNull);
      expect(line('', _at(13, 10, 46)), isNull);
    });
  });
}
