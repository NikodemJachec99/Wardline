/// Time formatting used across screens. Times are always tabular in the UI
/// (WlType.tabular).
library;

String hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "now", "4 min ago", "2 h ago", "yesterday", else "13 Nov".
String timeAgo(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24 && now.day == t.day) return '${d.inHours} h ago';
  if (d.inDays < 2) return 'yesterday';
  return '${t.day} ${_months[t.month - 1]}';
}

/// "2 h 15 min".
String duration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
