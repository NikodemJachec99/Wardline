import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';
import '../../../core/widgets/wl/wl.dart';

class DepartmentHistoryScreen extends StatelessWidget {
  const DepartmentHistoryScreen({required this.departmentCode, super.key});

  final String departmentCode;

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Department history',
      icon: WlIcons.building,
    );
  }
}
