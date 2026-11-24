import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/core/id/patient_code.dart';

void main() {
  group('PatientCode.tryParse', () {
    test('accepts a canonical code', () {
      expect(PatientCode.tryParse('HPT-7K3M9QXA')?.value, 'HPT-7K3M9QXA');
    });

    test('accepts every allowed Crockford character', () {
      for (final c in '0123456789ABCDEFGHJKMNPQRSTVWXYZ'.split('')) {
        expect(PatientCode.isValid('HPT-${c * 8}'), isTrue, reason: c);
      }
    });

    test('trims whitespace and newlines from scanners', () {
      expect(PatientCode.tryParse('  HPT-7K3M9QXA\n')?.value, 'HPT-7K3M9QXA');
    });

    test('normalises lower case to upper case', () {
      expect(PatientCode.tryParse('hpt-7k3m9qxa')?.value, 'HPT-7K3M9QXA');
    });

    test('rejects a wrong prefix', () {
      for (final raw in [
        'HPX-7K3M9QXA',
        'HP-7K3M9QXA',
        'HPT7K3M9QXA',
        'XHPT-7K3M9QXA',
      ]) {
        expect(PatientCode.tryParse(raw), isNull, reason: raw);
      }
    });

    test('rejects I, L, O and U (not Crockford Base32)', () {
      for (final c in ['I', 'L', 'O', 'U', 'i', 'l', 'o', 'u']) {
        expect(PatientCode.tryParse('HPT-7K3M9QX$c'), isNull, reason: c);
      }
    });

    test('rejects empty and null', () {
      expect(PatientCode.tryParse(''), isNull);
      expect(PatientCode.tryParse('   '), isNull);
      expect(PatientCode.tryParse(null), isNull);
    });

    test('rejects too short and too long', () {
      expect(PatientCode.tryParse('HPT-7K3M9QX'), isNull);
      expect(PatientCode.tryParse('HPT-7K3M9QXAB'), isNull);
    });

    test('rejects inner spaces, symbols and URLs', () {
      for (final raw in [
        'HPT-7K3M 9QXA',
        'HPT-7K3M9QX!',
        'https://example.com/HPT-7K3M9QXA',
        'HPT-7K3M9QXA;Jan Kowalski',
      ]) {
        expect(PatientCode.tryParse(raw), isNull, reason: raw);
      }
    });

    test('accepts the fixed design sample IDs', () {
      for (final raw in ['HPT-9RT2KM5C', 'HPT-1QH8VX3B', 'HPT-9VG3HJ7N']) {
        expect(PatientCode.isValid(raw), isTrue, reason: raw);
      }
    });
  });
}
