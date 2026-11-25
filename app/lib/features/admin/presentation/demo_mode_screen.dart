// Demo mode / Showcase (design/canvas/DemoMode.dc.html): one-tap scenarios
// on the simulation data set, wired to the demo repository. States: idle ·
// running. Admin only (router guard).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/providers.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/demo/demo_hospital_repository.dart';
import 'widgets/admin_widgets.dart';

class DemoModeScreen extends ConsumerStatefulWidget {
  const DemoModeScreen({super.key});

  /// DemoMode artboard: "A transfer every 20 s".
  static const Duration liveInterval = Duration(seconds: 20);

  /// DemoMode artboard: "lost connection for 60 s".
  static const Duration offlineFor = Duration(seconds: 60);

  @override
  ConsumerState<DemoModeScreen> createState() => _DemoModeScreenState();
}

class _DemoModeScreenState extends ConsumerState<DemoModeScreen> {
  Timer? _live;
  int _liveSent = 0;
  Timer? _offline;
  int _offlineLeft = 0;
  late final ConnectivityController _connectivity = ref.read(
    connectivityProvider.notifier,
  );

  DemoHospitalRepository? get _demo => ref.read(demoRepositoryProvider);

  @override
  void dispose() {
    _live?.cancel();
    // Leaving the screen ends the timed offline scenario.
    if (_offline != null) {
      _offline!.cancel();
      unawaited(_connectivity.setOnline(true));
    }
    super.dispose();
  }

  void _toggleLive() {
    if (_live != null) {
      setState(() {
        _live!.cancel();
        _live = null;
      });
      return;
    }
    void send() {
      if (_demo?.simulateRemoteTransfer() != null && mounted) {
        setState(() => _liveSent++);
      }
    }

    setState(() {
      _liveSent = 0;
      _live = Timer.periodic(DemoModeScreen.liveInterval, (_) => send());
    });
    send();
  }

  void _toggleOffline(bool running) {
    if (running) {
      _offline?.cancel();
      setState(() => _offline = null);
      unawaited(_connectivity.setOnline(true));
      return;
    }
    unawaited(_connectivity.setOnline(false));
    setState(() {
      _offlineLeft = DemoModeScreen.offlineFor.inSeconds;
      _offline = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _offlineLeft--);
        if (_offlineLeft <= 0) {
          timer.cancel();
          setState(() => _offline = null);
          unawaited(_connectivity.setOnline(true));
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final demo = ref.watch(demoRepositoryProvider);
    // Rebuild on every change: a write consumes the conflict / timeout knob.
    ref.watch(hospitalProvider);
    final conn = ref.watch(connectivityProvider);
    final online = conn.online;

    final Widget content;
    if (demo == null) {
      content = const WlEmptyState(
        icon: WlIcons.play,
        title: 'Demo mode is off',
        body:
            'This build uses the live server. Scenarios only run on the '
            'simulation data set.',
      );
    } else {
      final k = demo.knobs;
      final left =
          '${_offlineLeft ~/ 60}:${(_offlineLeft % 60).toString().padLeft(2, '0')}';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScenarioCard(
            icon: WlIcons.transfer,
            title: 'Live transfers',
            desc: 'A transfer every 20 s between random departments.',
            running: _live != null,
            status:
                'Running · $_liveSent transfer${_liveSent == 1 ? '' : 's'} '
                'sent',
            needsConnection: !online,
            onToggle: _toggleLive,
          ),
          _ScenarioCard(
            icon: WlIcons.patients,
            title: "Another nurse's transfer",
            desc: 'A nurse on another device moves a random patient now.',
            needsConnection: !online,
            onToggle: () => demo.simulateRemoteTransfer(),
          ),
          _ScenarioCard(
            icon: WlIcons.status,
            title: "A doctor's status change",
            desc: 'A doctor changes a random patient\'s status now.',
            needsConnection: !online,
            onToggle: () => demo.simulateRemoteStatus(),
          ),
          _ScenarioCard(
            icon: WlIcons.alert,
            title: 'Conflict',
            desc:
                'Someone else moves the patient while you are confirming '
                'your next transfer or status change.',
            running: k.conflictNext,
            status: 'Armed · confirm any transfer or status change',
            onToggle: () => setState(() => k.conflictNext = !k.conflictNext),
          ),
          _ScenarioCard(
            icon: WlIcons.clock,
            title: 'Timeout',
            desc:
                'Your next change is saved, but the answer never arrives. '
                '"Check status" finds it.',
            running: k.timeoutNext,
            status: 'Armed · the next change times out',
            onToggle: () => setState(() => k.timeoutNext = !k.timeoutNext),
          ),
          _ScenarioCard(
            icon: WlIcons.wifiOff,
            title: 'Offline',
            desc: 'Simulates lost connection for 60 s on this device.',
            running: !online,
            status: _offline != null ? 'Offline for $left' : 'Offline',
            onToggle: () => _toggleOffline(!online),
          ),
          SizedBox(height: t.space.xs - 2),
          const SimulationNote(
            'Scenarios change the simulation data on this device only, the '
            'same way real events from other devices would.',
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: t.space.lg + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const WlLargeTitle(
              title: 'Showcase',
              showBack: true,
              trailing: [RoleChip(role: UserRole.admin, text: 'Admin only')],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                0,
                t.space.gutter,
                t.space.md,
              ),
              child: Text(
                'One-tap scenarios for presentations. Uses the simulation '
                'data set only.',
                style: t.typography.subhead.copyWith(color: c.textSecondary),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}

/// One scenario: icon, title, description, "Running · …" status with a
/// pulsing dot, and Run / Stop. One-shot scenarios have no running state.
class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onToggle,
    this.running = false,
    this.status,
    this.needsConnection = false,
  });

  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onToggle;
  final bool running;
  final String? status;

  /// Other devices' events can't reach an offline device.
  final bool needsConnection;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final showButton = running || !needsConnection;
    final button = Semantics(
      button: true,
      toggled: status == null ? null : running,
      label: '${running ? 'Stop' : 'Run'} $title',
      excludeSemantics: true,
      child: Material(
        color: running ? c.surface : c.primaryInk,
        shape: RoundedRectangleBorder(
          borderRadius: t.radius.inputBr,
          side: running ? BorderSide(color: c.borderStrong) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: t.space.touchMin,
              minWidth: 64,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.sm + 2),
              child: Center(
                widthFactor: 1,
                child: Text(
                  running ? 'Stop' : 'Run',
                  style: t.typography.callout.copyWith(
                    color: running ? c.text : c.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: t.space.sm - 2),
      child: AnimatedContainer(
        duration: WlMotion.duration(context, t.motion.base),
        curve: t.motion.out,
        padding: EdgeInsets.all(t.space.sm + 2),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: t.radius.cardBr,
          border: Border.all(
            color: running ? c.primary : c.border,
            width: running ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: running ? c.primary : c.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: running ? c.onPrimary : c.primaryInk,
              ),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.typography.label.copyWith(color: c.text),
                  ),
                  SizedBox(height: t.space.xxs / 2),
                  Text(
                    desc,
                    style: t.typography.subhead.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  if (running && status != null) ...[
                    SizedBox(height: t.space.xxs),
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          const _PulseDot(),
                          SizedBox(width: t.space.xxs + 2),
                          Flexible(
                            child: Text(
                              status!,
                              style: t.typography
                                  .tabular(t.typography.caption)
                                  .copyWith(
                                    color: c.primaryInk,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!showButton) ...[
                    SizedBox(height: t.space.xxs),
                    Text(
                      'Needs a connection',
                      style: t.typography.caption.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showButton) ...[SizedBox(width: t.space.sm), button],
          ],
        ),
      ),
    );
  }
}

/// Teal dot with a 2s ring (motion.md live pulse). Reduced motion: static dot.
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2), // motion.md live pulse
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WlMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = WlTokens.of(context).colors;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: c.primary,
            shape: BoxShape.circle,
            boxShadow: _c.isAnimating
                ? [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.5 * (1 - v)),
                      spreadRadius: 7 * v,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
