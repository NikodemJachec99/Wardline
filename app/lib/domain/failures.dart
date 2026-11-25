// Backend error codes (docs/PLAN.md §5.3) mapped to typed failures.
// UI copy lives in design/handoff/copy.md.

import 'package:flutter/foundation.dart';

/// Base class of everything a repository write can fail with.
@immutable
sealed class WlFailure implements Exception {
  const WlFailure();
}

/// PT401: no session.
final class UnauthenticatedFailure extends WlFailure {
  const UnauthenticatedFailure();
}

/// PT403: role can't do this. The UI never offers such actions; this means
/// the backend caught a bypass attempt.
final class ForbiddenFailure extends WlFailure {
  const ForbiddenFailure();
}

/// PT404: unknown patient.
final class NotFoundFailure extends WlFailure {
  const NotFoundFailure();
}

/// PT409: the patient changed since the screen loaded. Never auto-retry.
final class ConflictFailure extends WlFailure {
  const ConflictFailure({
    this.byName,
    this.byRoleLabel,
    this.at,
    this.from,
    this.to,
  });

  final String? byName;
  final String? byRoleLabel;
  final DateTime? at;

  /// Department names, for "Laboratory → Cardiology".
  final String? from;
  final String? to;
}

/// PT422: same location / same status / invalid department.
final class InvalidRequestFailure extends WlFailure {
  const InvalidRequestFailure(this.reason);

  final String reason;
}

/// No answer in time. The write may or may not have happened: "Check status"
/// resends with the same client_request_id.
final class TimeoutFailure extends WlFailure {
  const TimeoutFailure(this.requestId);

  final String requestId;
}

/// No connection. Writes are not queued (product rule 5).
final class OfflineFailure extends WlFailure {
  const OfflineFailure();
}

/// Maps a Postgres error code from the RPCs to a failure.
WlFailure failureFromCode(String? code, {String? detail}) => switch (code) {
  'PT401' => const UnauthenticatedFailure(),
  'PT403' => const ForbiddenFailure(),
  'PT404' => const NotFoundFailure(),
  'PT409' => const ConflictFailure(),
  'PT422' => InvalidRequestFailure(detail ?? 'invalid'),
  _ => InvalidRequestFailure(detail ?? code ?? 'unknown'),
};
