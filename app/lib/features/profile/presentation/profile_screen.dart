import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';

/// "Now" for the shift countdown. Overridden in tests (design clock 10:46).
final profileNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// `/profile` (Account artboard, "Profile & settings"): who is signed in,
/// display and notification settings, the Admin entry for admins, demo
/// controls (simulation only) and Sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final me = ref.watch(sessionProvider);
    if (me == null) return Scaffold(backgroundColor: c.page);
    final settings = ref.watch(settingsProvider);
    final conn = ref.watch(connectivityProvider);
    final s = ref.watch(hospitalProvider);
    final now = ref.watch(profileNowProvider)();
    final platform = switch (Theme.of(context).platform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      _ => 'the system',
    };
    final textPct = (MediaQuery.textScalerOf(context).scale(100)).round();
    void update(AppSettings Function(AppSettings) change) =>
        ref.read(settingsProvider.notifier).update(change);

    final demoAccounts = [
      for (final role in UserRole.values)
        ?s.staff.where((m) => m.role == role).firstOrNull,
    ];

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: t.space.lg + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const WlLargeTitle(title: 'Profile', showBack: false),
            if (!conn.online)
              _Inset(child: WlOfflineBanner(syncedAt: hm(conn.syncedAt)))
            else if (conn.backOnlineAt != null)
              _Inset(
                child: WlOfflineBanner.backOnline(syncedAt: hm(conn.syncedAt)),
              ),
            _IdentityCard(
              member: me,
              department: me.homeDepartment == null
                  ? null
                  : s.department(me.homeDepartment!)?.name,
              shift: _shiftLine(me.shiftLabel, now),
            ),
            const _GroupLabel('Display'),
            _Box(
              children: [
                _SwitchRow(
                  title: 'Reduce motion',
                  subtitle: settings.reduceMotion
                      ? 'On · fades instead of slides, no shimmer'
                      : 'Off · follows $platform when not set here',
                  value: settings.reduceMotion,
                  onChanged: (v) => update((a) => a.copyWith(reduceMotion: v)),
                ),
                _InfoRow(
                  title: 'Text size',
                  subtitle: 'Follows $platform · currently $textPct%',
                ),
                _SwitchRow(
                  title: 'Haptics',
                  subtitle: 'Vibrate when a wristband is read',
                  value: settings.haptics,
                  onChanged: (v) => update((a) => a.copyWith(haptics: v)),
                ),
              ],
            ),
            const _GroupLabel('Notifications'),
            _Box(
              children: [
                _NavRow(
                  icon: WlIcons.bell,
                  title: 'Notifications',
                  subtitle: me.role == UserRole.doctor
                      ? 'Arrivals in your ward, status changes'
                      : 'Admissions, discharges',
                  onTap: () => context.push(Routes.notifications),
                ),
                _SwitchRow(
                  title: 'Arrivals in my ward',
                  value: settings.notifyArrivals,
                  onChanged: (v) =>
                      update((a) => a.copyWith(notifyArrivals: v)),
                ),
                _SwitchRow(
                  title: 'Status changes',
                  value: settings.notifyStatus,
                  onChanged: (v) => update((a) => a.copyWith(notifyStatus: v)),
                ),
                _SwitchRow(
                  title: 'Admissions and discharges',
                  value: settings.notifyDischarges,
                  onChanged: (v) =>
                      update((a) => a.copyWith(notifyDischarges: v)),
                ),
              ],
            ),
            if (me.role == UserRole.admin) ...[
              const _GroupLabel('Administration'),
              _Box(
                children: [
                  _NavRow(
                    icon: WlIcons.shield,
                    title: 'Admin',
                    subtitle: 'Staff, roles and wristband tags',
                    onTap: () => context.push(Routes.admin),
                  ),
                ],
              ),
            ],
            const _GroupLabel('Demo'),
            _Box(
              children: [
                _DemoRoleRow(
                  accounts: demoAccounts,
                  current: me,
                  onPick: (m) => ref.read(sessionProvider.notifier).signInAs(m),
                ),
                _SwitchRow(
                  title: 'Simulate offline',
                  subtitle: "Shows cached data. Changes need a connection.",
                  value: !conn.online,
                  onChanged: (offline) => ref
                      .read(connectivityProvider.notifier)
                      .setOnline(!offline),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                t.space.lg,
                t.space.gutter,
                0,
              ),
              child: WlButton(
                label: 'Sign out',
                icon: WlIcons.logOut,
                variant: WlButtonVariant.destructive,
                onPressed: () => ref.read(sessionProvider.notifier).signOut(),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: t.space.sm),
              child: Text(
                'Wardline 1.0',
                textAlign: TextAlign.center,
                style: t.typography.caption.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Day shift 07:00–19:00 · ends in 8 h 14 min".
  static String? _shiftLine(String? label, DateTime now) {
    if (label == null || label.isEmpty) return null;
    final text = RegExp(r'^\d').hasMatch(label) ? 'Shift $label' : label;
    final times = RegExp(r'(\d{2}):(\d{2})').allMatches(label).toList();
    if (times.length < 2) return text;
    DateTime at(RegExpMatch m) => DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
    );
    final start = at(times.first);
    final end = at(times.last);
    if (now.isBefore(start) || !now.isBefore(end)) return text;
    return '$text · ends in ${duration(end.difference(now))}';
  }
}

class _Inset extends StatelessWidget {
  const _Inset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.gutter,
        0,
        t.space.gutter,
        t.space.sm,
      ),
      child: child,
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.member,
    required this.department,
    required this.shift,
  });

  final StaffMember member;
  final String? department;
  final String? shift;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final role = c.role(member.role);
    final roleLine = department == null
        ? role.label
        : '${role.label} · $department';
    return Semantics(
      container: true,
      label: [member.name, roleLine, ?shift].join(', '),
      excludeSemantics: true,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: t.space.gutter),
        padding: EdgeInsets.all(t.space.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: t.radius.cardBr,
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            WlInitialsAvatar.staff(member.name, role: member.role, size: 60),
            SizedBox(width: t.space.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: t.typography.title3.copyWith(color: c.text),
                  ),
                  Text(
                    roleLine,
                    style: t.typography.subhead.copyWith(
                      color: role.fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (shift != null)
                    Text(
                      shift!,
                      style: t.typography
                          .tabular(t.typography.subhead)
                          .copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.gutter + t.space.xxs,
        t.space.md,
        t.space.gutter + t.space.xxs,
        t.space.xs - 2,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: t.typography.overline.copyWith(color: t.colors.textSecondary),
        ),
      ),
    );
  }
}

/// White rounded group (`.box`) with hairlines between rows.
class _Box extends StatelessWidget {
  const _Box({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: t.space.gutter),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: t.radius.cardBr,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Container(height: 1, color: c.border),
            child,
          ],
        ],
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: t.typography.callout.copyWith(color: c.text)),
        if (subtitle != null)
          Text(
            subtitle!,
            style: t.typography
                .tabular(t.typography.caption)
                .copyWith(color: c.textSecondary, fontWeight: FontWeight.w400),
          ),
      ],
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: t.space.action),
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm + 2,
        vertical: t.space.xs,
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

/// Whole row toggles; one merged node ("Reduce motion, switch, off").
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: _RowShell(
          child: Row(
            children: [
              Expanded(
                child: _RowText(title: title, subtitle: subtitle),
              ),
              SizedBox(width: t.space.sm),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: c.primaryInk,
                activeThumbColor: c.onPrimary,
                inactiveTrackColor: c.borderStrong,
                inactiveThumbColor: c.onPrimary,
                trackOutlineColor: WidgetStatePropertyAll(
                  c.surface.withValues(alpha: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: _RowShell(
      child: _RowText(title: title, subtitle: subtitle),
    ),
  );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: _RowShell(
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.textSecondary),
              SizedBox(width: t.space.sm),
              Expanded(
                child: _RowText(title: title, subtitle: subtitle),
              ),
              Icon(WlIcons.chevronRight, size: 20, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Demo only: switch role without typing (signInAs).
class _DemoRoleRow extends StatelessWidget {
  const _DemoRoleRow({
    required this.accounts,
    required this.current,
    required this.onPick,
  });

  final List<StaffMember> accounts;
  final StaffMember current;
  final ValueChanged<StaffMember> onPick;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(top: t.space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.sm + 2),
            child: const _RowText(
              title: 'Sign in as',
              subtitle: 'Fictional demo accounts',
            ),
          ),
          WlFilterChips(
            padding: EdgeInsets.symmetric(horizontal: t.space.sm + 2),
            chips: [
              for (final a in accounts)
                WlFilterChipData(
                  label: a.roleLabel,
                  selected: a.role == current.role,
                  onTap: () => onPick(a),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
