// App-wide state. Screens read the hospital through these providers only, so
// swapping the demo repository for Supabase (issue #16) touches nothing else.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/wl/wl.dart';
import '../../data/demo/demo_hospital_repository.dart';
import '../../data/demo/demo_seed.dart';
import '../../data/hospital_repository.dart';
import '../../domain/models.dart';

/// Overridden in main() (and in tests) with a ready repository.
final hospitalRepositoryProvider = Provider<HospitalRepository>(
  (ref) => throw UnimplementedError('Override hospitalRepositoryProvider'),
);

/// The demo repository, when the app runs on demo data (demo controls).
final demoRepositoryProvider = Provider<DemoHospitalRepository?>((ref) {
  final repo = ref.watch(hospitalRepositoryProvider);
  return repo is DemoHospitalRepository ? repo : null;
});

/// Current hospital snapshot; updates on every change.
final hospitalProvider = NotifierProvider<HospitalController, HospitalSnapshot>(
  HospitalController.new,
);

class HospitalController extends Notifier<HospitalSnapshot> {
  StreamSubscription<HospitalSnapshot>? _sub;

  @override
  HospitalSnapshot build() {
    final repo = ref.watch(hospitalRepositoryProvider);
    _sub?.cancel();
    _sub = repo.watch().listen((s) => state = s);
    ref.onDispose(() => _sub?.cancel());
    return repo.current;
  }
}

final patientProvider = Provider.family<Patient?, String>(
  (ref, id) => ref.watch(hospitalProvider.select((s) => s.patient(id))),
);

final patientHistoryProvider = Provider.family<List<HistoryEvent>, String>(
  (ref, id) => ref.watch(hospitalProvider).historyFor(id),
);

// ---------------------------------------------------------------- session

final sessionProvider = NotifierProvider<SessionController, StaffMember?>(
  SessionController.new,
);

class SessionController extends Notifier<StaffMember?> {
  @override
  StaffMember? build() => null;

  /// Demo sign-in: fictional accounts from the sample data, password
  /// [DemoSeed.demoPassword]. Returns false for wrong credentials.
  Future<bool> signIn(String email, String password) async {
    final online =
        ref.read(connectivityProvider).state != WlConnectionState.offline;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!online) throw StateError('offline');
    final staff = ref.read(hospitalProvider).staff;
    for (final s in staff) {
      if (s.email == email.trim().toLowerCase() &&
          password == DemoSeed.demoPassword) {
        state = s;
        return true;
      }
    }
    return false;
  }

  /// Demo only: switch role without typing (Profile › Demo).
  void signInAs(StaffMember member) => state = member;

  void signOut() => state = null;
}

// ----------------------------------------------------------- connectivity

class ConnectivityStatus {
  const ConnectivityStatus({
    required this.state,
    required this.syncedAt,
    this.backOnlineAt,
  });

  final WlConnectionState state;
  final DateTime syncedAt;

  /// Set for ~3s after reconnecting ("Back online · synced 10:47").
  final DateTime? backOnlineAt;

  bool get online => state != WlConnectionState.offline;
}

final connectivityProvider =
    NotifierProvider<ConnectivityController, ConnectivityStatus>(
      ConnectivityController.new,
    );

class ConnectivityController extends Notifier<ConnectivityStatus> {
  Timer? _clearBackOnline;

  @override
  ConnectivityStatus build() {
    ref.onDispose(() => _clearBackOnline?.cancel());
    ref.listen(hospitalProvider, (_, s) {
      if (state.online) {
        state = ConnectivityStatus(
          state: state.state,
          syncedAt: s.syncedAt,
          backOnlineAt: state.backOnlineAt,
        );
      }
    });
    return ConnectivityStatus(
      state: WlConnectionState.live,
      syncedAt: ref.read(hospitalProvider).syncedAt,
    );
  }

  /// Demo toggle (Profile › Demo, admin Demo mode). A real build listens to
  /// the OS and the Realtime channel instead.
  Future<void> setOnline(bool online) async {
    final demo = ref.read(demoRepositoryProvider);
    if (!online) {
      demo?.setOnline(false);
      state = ConnectivityStatus(
        state: WlConnectionState.offline,
        syncedAt: state.syncedAt,
      );
      return;
    }
    state = ConnectivityStatus(
      state: WlConnectionState.reconnecting,
      syncedAt: state.syncedAt,
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
    demo?.setOnline(true);
    await ref.read(hospitalRepositoryProvider).refresh();
    final now = DateTime.now();
    state = ConnectivityStatus(
      state: WlConnectionState.live,
      syncedAt: ref.read(hospitalProvider).syncedAt,
      backOnlineAt: now,
    );
    _clearBackOnline?.cancel();
    _clearBackOnline = Timer(const Duration(seconds: 3), () {
      state = ConnectivityStatus(state: state.state, syncedAt: state.syncedAt);
    });
  }
}

// --------------------------------------------------------------- settings

class AppSettings {
  const AppSettings({
    this.reduceMotion = false,
    this.notifyArrivals = true,
    this.notifyStatus = true,
    this.notifyDischarges = true,
    this.haptics = true,
  });

  final bool reduceMotion;
  final bool notifyArrivals;
  final bool notifyStatus;
  final bool notifyDischarges;
  final bool haptics;

  AppSettings copyWith({
    bool? reduceMotion,
    bool? notifyArrivals,
    bool? notifyStatus,
    bool? notifyDischarges,
    bool? haptics,
  }) => AppSettings(
    reduceMotion: reduceMotion ?? this.reduceMotion,
    notifyArrivals: notifyArrivals ?? this.notifyArrivals,
    notifyStatus: notifyStatus ?? this.notifyStatus,
    notifyDischarges: notifyDischarges ?? this.notifyDischarges,
    haptics: haptics ?? this.haptics,
  );
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void update(AppSettings Function(AppSettings) change) =>
      state = change(state);
}

/// Builds the demo repository from the bundled sample data.
DemoHospitalRepository buildDemoRepository(
  String sampleJson, {
  DateTime? now,
}) => DemoHospitalRepository(
  DemoSeed.fromJson(sampleJson, now: now ?? DateTime.now()),
);
