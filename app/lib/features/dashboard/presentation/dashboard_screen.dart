import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
    );
  }
}
