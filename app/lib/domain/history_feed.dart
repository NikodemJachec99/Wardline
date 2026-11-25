// One activity stream from the two history tables (PLAN §8 M11, M19):
// `location_history` (transfers, admissions) ∪ `status_history`.
// For the Supabase repository (#16): both tables are fetched separately
// (and arrive separately over Realtime) and merged here. The demo data is
// generated already merged, so it does not need this.

import 'models.dart';

/// Merges transfers and status changes into one list, newest first by
/// server time (`created_at`).
///
/// The order is total, so the feed never reshuffles between rebuilds:
/// equal times put the transfer before the status change, then sort by id.
/// Inputs may be in any order; neither list is modified.
List<HistoryEvent> mergeHistory(
  Iterable<LocationEvent> transfers,
  Iterable<StatusEvent> statusChanges,
) {
  return [...transfers, ...statusChanges]..sort(compareNewestFirst);
}

/// Newest first; ties: transfer before status change, then by id.
int compareNewestFirst(HistoryEvent a, HistoryEvent b) {
  final byTime = b.at.compareTo(a.at);
  if (byTime != 0) return byTime;
  final byKind = _kind(a).compareTo(_kind(b));
  if (byKind != 0) return byKind;
  return a.id.compareTo(b.id);
}

int _kind(HistoryEvent e) => switch (e) {
  LocationEvent() => 0,
  StatusEvent() => 1,
};
