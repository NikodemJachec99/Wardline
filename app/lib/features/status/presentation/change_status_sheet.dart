import 'package:flutter/material.dart';

import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';

/// Doctor only. Four statuses, current marked, "Location doesn't change",
/// reason required for Discharged, Save status → RPC set_patient_status.
///
/// STUB: signature is final; the flow is implemented in the status PR.
Future<void> showChangeStatusSheet(
  BuildContext context, {
  required Patient patient,
}) {
  return showWlBottomSheet<void>(
    context: context,
    builder: (context) =>
        const WlEmptyState(icon: WlIcons.status, title: 'Change status'),
  );
}
