import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';

/// Reads the text of the first NDEF Text record (`TNF_WELL_KNOWN`, type `T`).
///
/// Wardline wristbands carry exactly one Text record with the patient ID
/// (docs/ID_FORMAT.md). Other records (URI, MIME, empty) are skipped; the chip
/// UID is never looked at. Returns null when there is no readable Text record.
String? firstNdefText(NdefMessage? message) {
  if (message == null) return null;
  for (final record in message.records) {
    final text = decodeNdefText(record);
    if (text != null) return text;
  }
  return null;
}

/// Decodes one NDEF Text record (NFC Forum RTD-Text 1.0), or returns null.
///
/// Payload: status byte (bit 7 = UTF-16, bits 0-5 = language code length),
/// the IANA language code, then the text.
String? decodeNdefText(NdefRecord record) {
  if (record.typeNameFormat != TypeNameFormat.wellKnown) return null;
  if (record.type.length != 1 || record.type[0] != 0x54) return null;
  final payload = record.payload;
  if (payload.isEmpty) return null;

  final status = payload[0];
  final isUtf16 = (status & 0x80) != 0;
  final languageLength = status & 0x3F;
  final start = 1 + languageLength;
  if (start > payload.length) return null;

  final bytes = Uint8List.sublistView(payload, start);
  try {
    return isUtf16 ? _decodeUtf16(bytes) : utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

String _decodeUtf16(Uint8List bytes) {
  var bigEndian = true;
  var offset = 0;
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      bigEndian = false;
      offset = 2;
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      offset = 2;
    }
  }
  if ((bytes.length - offset).isOdd) {
    throw const FormatException('Odd UTF-16 length');
  }
  final units = <int>[];
  for (var i = offset; i < bytes.length; i += 2) {
    units.add(
      bigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : (bytes[i + 1] << 8) | bytes[i],
    );
  }
  return String.fromCharCodes(units);
}
