import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';
import '../../../core/widgets/wl/wl.dart';

class TransferConfirmScreen extends StatelessWidget {
  const TransferConfirmScreen({
    required this.patientId,
    required this.toCode,
    super.key,
  });

  final String patientId;
  final String toCode;

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Confirm transfer',
      icon: WlIcons.transfer,
    );
  }
}
