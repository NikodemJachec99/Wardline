import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(title: 'Skanuj', icon: Icons.nfc_outlined);
  }
}
