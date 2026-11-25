import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import '../features/admin/presentation/admin_screen.dart';
import '../features/admin/presentation/demo_mode_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/analytics/presentation/ward_monitor_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/history/presentation/day_timeline_screen.dart';
import '../features/history/presentation/department_history_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/map/presentation/hospital_map_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/patients/presentation/patient_profile_screen.dart';
import '../features/patients/presentation/patients_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/scan/presentation/scan_screen.dart';
import '../features/transfer/presentation/transfer_confirm_screen.dart';
import 'shell_scaffold.dart';
import 'state/providers.dart';

/// Routes from design/handoff/screens.md.
abstract final class Routes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String patients = '/patients';
  static const String scan = '/scan';
  static const String history = '/history';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String map = '/map';
  static const String admin = '/admin';
  static const String demo = '/admin/demo';
  static const String analytics = '/analytics';

  static String patient(String id) => '/patients/$id';

  /// Confirm screen; the destination sheet opens from the profile.
  static String transferConfirm(String id, String to) =>
      '/patients/$id/transfer?to=$to';
  static String departmentHistory(String code) => '/history/dept/$code';
  static const String dayTimeline = '/history/timeline';
  static String monitor(String code) => '/monitor/$code';

  static String mapFor({int? floor, String? department, String? patientId}) {
    final q = <String, String>{
      if (floor != null) 'floor': '$floor',
      'dept': ?department,
      'patient': ?patientId,
    };
    return Uri(path: map, queryParameters: q.isEmpty ? null : q).toString();
  }
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<StaffMember?>(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, s) => session.value = s);

  final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.dashboard,
    refreshListenable: session,
    redirect: (context, state) {
      final signedIn = session.value != null;
      final atLogin = state.matchedLocation == Routes.login;
      if (!signedIn && !atLogin) return Routes.login;
      if (signedIn && atLogin) return Routes.dashboard;
      final role = session.value?.role;
      if (state.matchedLocation.startsWith(Routes.admin) &&
          role != UserRole.admin) {
        return Routes.dashboard;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.patients,
                builder: (context, state) => const PatientsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => PatientProfileScreen(
                      patientId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'transfer',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => TransferConfirmScreen(
                          patientId: state.pathParameters['id']!,
                          toCode: state.uri.queryParameters['to'] ?? '',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.history,
                builder: (context, state) => const HistoryScreen(),
                routes: [
                  GoRoute(
                    path: 'dept/:code',
                    builder: (context, state) => DepartmentHistoryScreen(
                      departmentCode: state.pathParameters['code']!,
                    ),
                  ),
                  GoRoute(
                    path: 'timeline',
                    builder: (context, state) => const DayTimelineScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Scan opens as a full-screen modal over the shell.
      GoRoute(
        path: Routes.scan,
        pageBuilder: (context, state) => const MaterialPage<void>(
          fullscreenDialog: true,
          child: ScanScreen(),
        ),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.map,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return HospitalMapScreen(
            floor: int.tryParse(q['floor'] ?? ''),
            departmentCode: q['dept'],
            patientId: q['patient'],
          );
        },
      ),
      GoRoute(
        path: Routes.admin,
        builder: (context, state) => const AdminScreen(),
        routes: [
          GoRoute(
            path: 'demo',
            builder: (context, state) => const DemoModeScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.analytics,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/monitor/:code',
        builder: (context, state) =>
            WardMonitorScreen(departmentCode: state.pathParameters['code']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  ref.onDispose(session.dispose);
  return router;
});
