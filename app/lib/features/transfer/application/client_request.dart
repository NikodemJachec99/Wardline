// One client_request_id per user intent (docs/PLAN.md §5.3, product rule 4).
// Generated once when a confirm screen / sheet opens and reused for
// "Check status" after a timeout, so the server never applies it twice.

import 'dart:math';

final Random _secure = Random.secure();

/// UUID v4 string from a secure random source (no extra package needed).
String newClientRequestId() {
  final b = List<int>.generate(16, (_) => _secure.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Short, readable reference shown on the timeout state, e.g. "TX-8M2Q-4K7D".
String requestReference(String requestId, {String prefix = 'TX'}) {
  final hex = requestId.replaceAll('-', '').toUpperCase();
  if (hex.length < 8) return '$prefix-$hex';
  return '$prefix-${hex.substring(0, 4)}-${hex.substring(hex.length - 4)}';
}

/// "Ground floor" / "Floor 1" (sample-data.json floors).
String floorName(int floor) => floor == 0 ? 'Ground floor' : 'Floor $floor';

/// "Ground" / "Floor 1" for dense meta lines.
String floorShort(int floor) => floor == 0 ? 'Ground' : 'Floor $floor';

/// True when label/value rows should stack (platform-and-a11y.md: text
/// scale above 1.3).
bool stackRows(double textScale) => textScale > 1.3;
