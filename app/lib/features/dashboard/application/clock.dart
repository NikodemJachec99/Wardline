import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now" for the dashboard, notifications and demo mode (greeting, "today",
/// time ago, unread). Tests override it with the design clock (10:46) so the
/// demo data and goldens line up.
///
/// TODO(shared): move to app/state/providers.dart once other screens need it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

/// "Good morning" before 12:00, "Good afternoon" before 18:00, else
/// "Good evening".
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// 0 → "Ground", 1 → "Floor 1".
String floorLabel(int floor) => floor == 0 ? 'Ground' : 'Floor $floor';
