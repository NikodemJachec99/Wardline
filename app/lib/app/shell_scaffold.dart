import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/wl/wl.dart';

/// App shell: five tabs in [WlBottomNav] (Dashboard, Patients, Scan, History,
/// Profile). Scan is the raised centre button.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: WlBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
