import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:wardline/features/scan/data/ndef_text.dart';

NdefRecord _text(String text, {String lang = 'en', bool utf16 = false}) {
  final langBytes = ascii.encode(lang);
  final body = utf16
      ? Uint8List.fromList([
          0xFE,
          0xFF,
          for (final u in text.codeUnits) ...[u >> 8, u & 0xFF],
        ])
      : utf8.encode(text);
  return NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList([0x54]),
    identifier: Uint8List(0),
    payload: Uint8List.fromList([
      (utf16 ? 0x80 : 0) | langBytes.length,
      ...langBytes,
      ...body,
    ]),
  );
}

NdefRecord _uri(String uri) => NdefRecord(
  typeNameFormat: TypeNameFormat.wellKnown,
  type: Uint8List.fromList([0x55]),
  identifier: Uint8List(0),
  payload: Uint8List.fromList([0x00, ...utf8.encode(uri)]),
);

void main() {
  group('decodeNdefText', () {
    test('reads a UTF-8 en Text record', () {
      expect(decodeNdefText(_text('HPT-7K3M9QXA')), 'HPT-7K3M9QXA');
    });

    test('skips the language code of any length', () {
      expect(
        decodeNdefText(_text('HPT-7K3M9QXA', lang: 'pl-PL')),
        'HPT-7K3M9QXA',
      );
    });

    test('reads a UTF-16 Text record', () {
      expect(
        decodeNdefText(_text('HPT-7K3M9QXA', utf16: true)),
        'HPT-7K3M9QXA',
      );
    });

    test('ignores non-Text records', () {
      expect(decodeNdefText(_uri('example.com')), isNull);
    });

    test('returns null for a truncated payload', () {
      final broken = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList([0x54]),
        identifier: Uint8List(0),
        payload: Uint8List.fromList([0x05, 0x65]),
      );
      expect(decodeNdefText(broken), isNull);
    });
  });

  group('firstNdefText', () {
    test('returns the first Text record, skipping others', () {
      final message = NdefMessage(
        records: [
          _uri('example.com'),
          _text('HPT-9RT2KM5C'),
          _text('HPT-1QH8VX3B'),
        ],
      );
      expect(firstNdefText(message), 'HPT-9RT2KM5C');
    });

    test('returns null for an empty or missing message', () {
      expect(firstNdefText(null), isNull);
      expect(firstNdefText(const NdefMessage(records: [])), isNull);
    });
  });
}
