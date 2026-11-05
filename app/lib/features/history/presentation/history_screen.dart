import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Historia',
      icon: Icons.history_outlined,
    );
  }
}
