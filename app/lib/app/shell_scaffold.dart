import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/wl/wl.dart';
import '../data/hospital_repository.dart';
import '../domain/models.dart';
import 'router.dart';
import 'state/providers.dart';

/// App shell: [WlBottomNav] with Dashboard, Patients, Scan, History, Profile.
/// Scan (centre) opens the scanner as a modal; the other four are branches.
/// Also shows the realtime toast for changes made by other people (flow 6).
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Branch 0..3 → nav index 0, 1, 3, 4 (2 is Scan).
  static int navIndexForBranch(int branch) => branch >= 2 ? branch + 1 : branch;

  /// "Jan Kowalczyk moved to Radiology · by A. Nowak".
  static String? remoteToastText(HospitalSnapshot s, HistoryEvent e) {
    final p = s.patient(e.patientId);
    if (p == null) return null;
    final parts = e.byName.split(' ');
    final by = e.byName.startsWith('Dr') || parts.length < 2
        ? e.byName
        : '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
    return switch (e) {
      LocationEvent(:final to) =>
        '${p.fullName} moved to ${s.department(to)?.name ?? to} · by $by',
      StatusEvent(:final to) =>
        '${p.fullName} · ${WlStatusLabels.of(to)} · by $by',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(hospitalProvider.select((s) => s.lastRemoteEvent), (prev, next) {
      if (next == null || identical(prev, next)) return;
      final text = remoteToastText(ref.read(hospitalProvider), next);
      if (text == null) return;
      showWlToast(context, title: text, tone: WlToastTone.info);
    });
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
