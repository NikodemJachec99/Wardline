import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/wl/wl.dart';
import 'router.dart';

/// App shell: [WlBottomNav] with Dashboard, Patients, Scan, History, Profile.
/// Scan (centre) opens the scanner as a modal; the other four are branches.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Branch 0..3 → nav index 0, 1, 3, 4 (2 is Scan).
  static int navIndexForBranch(int branch) => branch >= 2 ? branch + 1 : branch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: WlBottomNav(
        currentIndex: navIndexForBranch(navigationShell.currentIndex),
        onTap: (index) {
          if (index == 2) {
            context.push(Routes.scan);
            return;
          }
          final branch = index > 2 ? index - 1 : index;
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
