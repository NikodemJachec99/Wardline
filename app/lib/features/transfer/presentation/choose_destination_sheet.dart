import 'package:flutter/material.dart';

import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';

/// Nurse only. Destination sheet with search; current department marked and
/// not selectable. Choosing one pushes the confirm screen
/// (`Routes.transferConfirm`).
///
/// STUB: signature is final; the flow is implemented in the transfer PR.
Future<void> showChooseDestinationSheet(
  BuildContext context, {
  required Patient patient,
  String? identifiedBy,
}) {
  return showWlBottomSheet<void>(
    context: context,
    builder: (context) =>
        const WlEmptyState(icon: WlIcons.transfer, title: 'Choose destination'),
  );
}
