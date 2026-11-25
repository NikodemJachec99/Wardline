// Dashboard, layout B (design/canvas/DashB.dc.html, DashDoctor, DashLoading).
// States: loading (skeleton KPIs, quick actions live) · live · live update
// (feed highlight, KPI count to the new value) · offline cached.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/failures.dart';
import '../../notifications/application/notifications.dart';
import '../application/clock.dart';
import '../application/dashboard_stats.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_parts.dart';
import 'widgets/dashboard_sections.dart';

/// The card stagger plays once per app session (motion.md: first build,
/// not on tab return or when the screen is rebuilt later).
final _introPlayedProvider = Provider<_IntroFlag>((ref) => _IntroFlag());

class _IntroFlag {
  bool played = false;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this);
  Timer? _tick;
  bool _introStarted = false;

  @override
  void initState() {
    super.initState();
    // "2 min ago" stays true without a new event.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introStarted) return;
    _introStarted = true;
    final flag = ref.read(_introPlayedProvider);
    if (flag.played) {
      _intro.value = 1;
      return;
    }
    flag.played = true;
    final t = WlTokens.of(context);
    if (WlMotion.reduced(context)) {
      _intro.duration = t.motion.fast;
    } else {
      _intro.duration = t.motion.base * StaggerIn.totalFactor(t.motion.base);
    }
    _intro.forward();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await ref.read(hospitalRepositoryProvider).refresh();
    } on WlFailure {
      // Offline: the cached data stays on screen with the banner.
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox.shrink();
    final s = ref.watch(hospitalProvider);
    final conn = ref.watch(connectivityProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final now = ref.watch(clockProvider)();
    final t = WlTokens.of(context);
    final c = t.colors;
    final reduced = WlMotion.reduced(context);
    final loading = s.departments.isEmpty;
    final stats = loading ? null : DashboardStats.from(s, now);
    final cachedAt = conn.online ? null : hm(conn.syncedAt);
    final doctor = me.role == UserRole.doctor;
    final home = s.department(me.homeDepartment ?? '');

    final subtitle = [
      me.roleLabel,
      if (doctor && home != null) home.name,
      ?me.shiftLabel,
    ].join(' · ');

    const kpiLabels = [
      'Total patients',
      'In treatment',
      'Ready for discharge',
      'Transfers today',
    ];
    final kpis = <Widget>[
      if (stats == null)
        for (final l in kpiLabels)
          WlKpiCard(key: ValueKey(l), label: l, value: 0, loading: true)
      else
        for (final k in stats.kpis)
          WlKpiCard(
            key: ValueKey(k.label),
            label: k.label,
            value: k.value,
            trend: k.trend,
            delta: k.deltaText,
            deltaSpoken: k.deltaSpoken,
            cachedSyncedAt: cachedAt,
          ),
    ];

    final sections = <Widget>[
      if (!conn.online)
        WlOfflineBanner(syncedAt: hm(conn.syncedAt))
      else if (conn.backOnlineAt != null)
        WlOfflineBanner.backOnline(syncedAt: hm(conn.syncedAt)),
      ActionTileGrid(
        tiles: [
          (
            icon: WlIcons.nfc,
            label: 'Scan NFC',
            onTap: () => context.push(Routes.scan),
          ),
          (
            icon: WlIcons.qr,
            label: 'Scan QR',
            onTap: () => context.push(Routes.scanQr),
          ),
          (
            icon: WlIcons.search,
            label: 'Search patient',
            onTap: () => context.go(Routes.patients),
          ),
        ],
      ),
      if (stats == null) ...[
        const MapEntryCardSkeleton(),
        ActivityFeedSkeleton(
          title: doctor ? 'Recent status changes' : 'Recent transfers',
        ),
      ] else ...[
        if (doctor && home != null)
          ReadyCard(
            count: readyInDepartment(s, home.code),
            departmentName: home.name,
            onTap: () => context.go(Routes.patients),
          ),
        if (!doctor)
          MapEntryCard(stats: stats, onTap: () => context.push(Routes.map)),
        ActivityFeedCard(
          title: doctor ? 'Recent status changes' : 'Recent transfers',
          snapshot: s,
          events: recentFeed(s, me.role),
          now: now,
          onSeeAll: () => context.go(Routes.history),
          onOpenPatient: (id) => context.go(Routes.patient(id)),
        ),
        if (doctor)
          MapEntryCard(stats: stats, onTap: () => context.push(Routes.map)),
        OccupancySection(
          stats: stats,
          initialSelection: me.homeDepartment,
          onOpen: (code) => context.go(Routes.departmentHistory(code)),
        ),
      ],
    ];

    final header = DashboardHeader(
      me: me,
      greeting: '${greetingFor(now)}, ${me.greetingName}',
      subtitle: subtitle,
      connection: conn.state,
      unread: unread,
      onBell: () => context.push(Routes.notifications),
      kpis: [
        for (final (i, k) in kpis.indexed)
          StaggerIn(animation: _intro, index: i, reduced: reduced, child: k),
      ],
    );

    return Scaffold(
      backgroundColor: c.page,
      body: Semantics(
        // DashLoading: aria-busy while the first data loads.
        label: loading ? 'Dashboard, loading' : null,
        child: RefreshIndicator.adaptive(
          color: c.primaryInk,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                for (final (i, w) in sections.indexed)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      t.space.gutter,
                      t.space.md,
                      t.space.gutter,
                      0,
                    ),
                    child: StaggerIn(
                      animation: _intro,
                      index: 2 + i,
                      reduced: reduced,
                      child: w,
                    ),
                  ),
                if (stats != null) ...[
                  SizedBox(height: t.space.md),
                  StaggerIn(
                    animation: _intro,
                    index: 2 + sections.length,
                    reduced: reduced,
                    child: YourDepartmentsStrip(
                      departments: yourDepartments(s, me, now),
                      snapshot: s,
                      onOpen: (code) =>
                          context.go(Routes.departmentHistory(code)),
                    ),
                  ),
                ],
                SizedBox(height: t.space.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
