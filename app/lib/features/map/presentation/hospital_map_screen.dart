import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';
import '../../../core/widgets/wl/wl.dart';

class HospitalMapScreen extends StatelessWidget {
  const HospitalMapScreen({
    this.floor,
    this.departmentCode,
    this.patientId,
    super.key,
  });

  final int? floor;
  final String? departmentCode;
  final String? patientId;

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(title: 'Hospital map', icon: WlIcons.map);
  }
}
