import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';
import '../../../core/widgets/wl/wl.dart';

class DemoModeScreen extends StatelessWidget {
  const DemoModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(title: 'Demo mode', icon: WlIcons.play);
  }
}
