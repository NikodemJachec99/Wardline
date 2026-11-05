import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/patients/presentation/patients_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/scan/presentation/scan_screen.dart';
import 'shell_scaffold.dart';

abstract final class Routes {
  static const String dashboard = '/dashboard';
  static const String patients = '/patients';
  static const String scan = '/scan';
  static const String history = '/history';
  static const String profile = '/profile';
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final GoRouter router = GoRouter(
    initialLocation: Routes.dashboard,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          _branch(Routes.dashboard, const DashboardScreen()),
          _branch(Routes.patients, const PatientsScreen()),
          _branch(Routes.scan, const ScanScreen()),
          _branch(Routes.history, const HistoryScreen()),
          _branch(Routes.profile, const ProfileScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) {
  return StatefulShellBranch(
    routes: <RouteBase>[
      GoRoute(path: path, builder: (context, state) => screen),
    ],
  );
}
