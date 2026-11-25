// Admin panel (design/canvas/Admin.dc.html): staff accounts with role
// labels, role sheet (own role read-only), Program NFC tag, Print cards &
// QR, and the entry to Demo mode. Admin only: the router redirects
// everyone else, and the backend checks again.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../domain/models.dart';
import '../../dashboard/presentation/widgets/dashboard_parts.dart';
import '../application/admin_state.dart';
import 'print_cards_screen.dart';
import 'program_tag_screen.dart';
import 'widgets/admin_widgets.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final me = ref.watch(sessionProvider);
    final staff = ref.watch(adminStaffProvider);
    final q = _query.trim().toLowerCase();
    final shown =
        [
          // You first, as on the artboard.
          ...staff.where((s) => s.id == me?.id),
          ...staff.where((s) => s.id != me?.id),
        ].where(
          (s) =>
              q.isEmpty ||
              s.name.toLowerCase().contains(q) ||
              (s.email ?? '').contains(q),
        );

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: t.space.lg + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            WlLargeTitle(
              title: 'Admin',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go(Routes.profile),
              showBack: true,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
              child: Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    style: t.typography.title2.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      const TextSpan(text: 'Staff '),
                      TextSpan(
                        text: '${staff.length}',
                        style: t.typography
                            .tabular(t.typography.title3)
                            .copyWith(
                              color: c.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                t.space.sm - 2,
                t.space.gutter,
                t.space.sm,
              ),
              child: WlSearchBar(
                hint: 'Name or email',
                semanticsLabel: 'Search staff',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
              child: DashCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, s) in shown.indexed) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: c.border),
                      _StaffRow(
                        key: ValueKey(s.id),
                        member: s,
                        isYou: s.id == me?.id,
                        onTap: s.id == me?.id
                            ? null
                            : () => _openRoleSheet(context, s),
                      ),
                    ],
                    if (shown.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(t.space.md),
                        child: Text(
                          'No staff match "$_query"',
                          style: t.typography.subhead.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                t.space.md,
                t.space.gutter,
                0,
              ),
              child: ActionTileGrid(
                tiles: [
                  (
                    icon: WlIcons.nfc,
                    label: 'Program NFC tag',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProgramTagScreen(),
                      ),
                    ),
                  ),
                  (
                    icon: WlIcons.printer,
                    label: 'Print cards & QR',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PrintCardsScreen(),
                      ),
                    ),
                  ),
                  (
                    icon: WlIcons.play,
                    label: 'Showcase',
                    onTap: () => context.push(Routes.demo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRoleSheet(BuildContext context, StaffMember member) {
    final busy = ValueNotifier<bool>(false);
    return showWlBottomSheet<void>(
      context: context,
      busy: busy,
      builder: (_) => RoleSheet(member: member, busy: busy),
    ).whenComplete(busy.dispose);
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.member,
    required this.isYou,
    required this.onTap,
    super.key,
  });

  final StaffMember member;
  final bool isYou;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final title = isYou ? '${member.name} · You' : member.name;
    final sub = isYou
        ? "Your role can't be changed by you"
        : (member.email ?? '');
    final role = roleLabel(member.role);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.sm + 2,
          vertical: t.space.sm - 2,
        ),
        child: Row(
          children: [
            WlInitialsAvatar.staff(member.name, role: member.role, size: 40),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.typography.callout.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub,
                    style: t.typography.caption.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: t.space.xs),
            RoleChip(role: member.role),
            if (onTap != null) ...[
              SizedBox(width: t.space.xxs),
              Icon(WlIcons.chevronRight, size: 18, color: c.textSecondary),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: isYou
          ? '$title, $role. $sub'
          : '$title, $role, ${member.email ?? ''}. Edit role',
      excludeSemantics: true,
      child: onTap == null
          ? ColoredBox(color: c.page, child: row)
          : InkWell(onTap: onTap, child: row),
    );
  }
}

/// Edit role: Nurse / Doctor / Admin radio rows, "Current" on the present
/// one, Save role (spinner, sheet locked while saving).
class RoleSheet extends ConsumerStatefulWidget {
  const RoleSheet({required this.member, required this.busy, super.key});

  final StaffMember member;
  final ValueNotifier<bool> busy;

  @override
  ConsumerState<RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends ConsumerState<RoleSheet> {
  late UserRole _role = widget.member.role;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    widget.busy.value = true;
    await ref
        .read(staffRoleOverridesProvider.notifier)
        .save(widget.member.id, _role);
    if (!mounted) return;
    widget.busy.value = false;
    final nav = Navigator.of(context);
    showWlToast(
      context,
      title: '${widget.member.name} is now ${roleLabel(_role)}',
      body: 'Simulation · saved on this device only',
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final m = widget.member;
    final online = ref.watch(connectivityProvider).online;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Edit ${m.name}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WlInitialsAvatar.staff(m.name, role: m.role, size: 48),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: t.typography.title3.copyWith(color: c.text),
                    ),
                    if (m.email != null)
                      Text(
                        m.email!,
                        style: t.typography.subhead.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: t.space.sm + 2),
          Semantics(
            label: 'Role',
            child: Column(
              children: [
                for (final r in UserRole.values) ...[
                  _RoleOption(
                    role: r,
                    selected: r == _role,
                    current: r == m.role,
                    onTap: _saving ? null : () => setState(() => _role = r),
                  ),
                  SizedBox(height: t.space.xs),
                ],
              ],
            ),
          ),
          SizedBox(height: t.space.xxs),
          const SimulationNote(
            'Applies immediately and signs the person out. Simulation: '
            'saved on this device only.',
          ),
          SizedBox(height: t.space.sm + 2),
          if (online)
            WlButton(
              label: 'Save role',
              loading: _saving,
              loadingLabel: 'Saving…',
              onPressed: _role == m.role ? null : _save,
            )
          else
            const WlOfflineActionNote(),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label:
          '${roleLabel(role)}, ${roleDescription(role)}'
          '${current ? ', current' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? c.primarySoft.withValues(alpha: 0.5) : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: t.radius.inputBr,
          side: BorderSide(
            color: selected ? c.primaryInk : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.space.action),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.sm + 2,
                vertical: t.space.xs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? c.primaryInk : c.borderStrong,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: c.primaryInk,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: t.space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roleLabel(role),
                          style: t.typography.callout.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          roleDescription(role),
                          style: t.typography.caption.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (current) RoleChip(role: role, text: 'Current'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
