import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';
import '../../../core/widgets/wl/wl.dart';

class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({required this.patientId, super.key});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(title: 'Patient', icon: WlIcons.user);
  }
}
