import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';
import '../../../core/widgets/wl/wl.dart';

class WardMonitorScreen extends StatelessWidget {
  const WardMonitorScreen({required this.departmentCode, super.key});

  final String departmentCode;

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(title: 'Ward monitor', icon: WlIcons.monitor);
  }
}
