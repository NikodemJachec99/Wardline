// Admin panel state. In production roles change through an Edge Function
// (service role on the server, never in the app). The demo has no such
// endpoint, so a saved role is kept here, on this device only, and the UI
// says so.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../domain/models.dart';

final staffRoleOverridesProvider =
    NotifierProvider<StaffRoleOverrides, Map<String, UserRole>>(
      StaffRoleOverrides.new,
    );

class StaffRoleOverrides extends Notifier<Map<String, UserRole>> {
  @override
  Map<String, UserRole> build() => const {};

  /// Simulated round trip, then the new role. Returns when "saved".
  Future<void> save(String staffId, UserRole role) async {
    final latency =
        ref.read(demoRepositoryProvider)?.knobs.latency ??
        const Duration(seconds: 1);
    await Future<void>.delayed(latency);
    state = {...state, staffId: role};
  }
}

/// Staff with simulated role changes applied.
final adminStaffProvider = Provider<List<StaffMember>>((ref) {
  final overrides = ref.watch(staffRoleOverridesProvider);
  return [
    for (final s in ref.watch(hospitalProvider.select((s) => s.staff)))
      overrides[s.id] == null
          ? s
          : StaffMember(
              id: s.id,
              name: s.name,
              role: overrides[s.id]!,
              email: s.email,
              homeDepartment: s.homeDepartment,
              shiftLabel: s.shiftLabel,
            ),
  ];
});

String roleLabel(UserRole r) => switch (r) {
  UserRole.nurse => 'Nurse',
  UserRole.doctor => 'Doctor',
  UserRole.admin => 'Admin',
};

/// Admin artboard, role sheet.
String roleDescription(UserRole r) => switch (r) {
  UserRole.nurse => 'Can transfer patients',
  UserRole.doctor => 'Can change status',
  UserRole.admin => 'Manages staff, tags and printing',
};
