// Notifications (design/canvas/Account.dc.html, first three phones):
// unread · read · empty. Derived from the realtime history, filtered by
// role + home department; own actions never notify.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/state/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../dashboard/application/clock.dart';
import '../../dashboard/presentation/widgets/dashboard_parts.dart';
import '../application/notifications.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox.shrink();
    final s = ref.watch(hospitalProvider);
    final all = ref.watch(notificationsProvider);
    final read = ref.watch(notificationReadProvider);
    final now = ref.watch(clockProvider)();
    final unread = all.where((n) => !read.isRead(n)).length;
    final scope = notificationScope(me, s);
    final today = startOfDay(now);

    final groups = <(String, List<WardNotification>)>[
      (
        'Today',
        [
          for (final n in all)
            if (!n.at.isBefore(today)) n,
        ],
      ),
      (
        'Yesterday',
        [
          for (final n in all)
            if (n.at.isBefore(today)) n,
        ],
      ),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: WlLargeTitle(
                title: 'Notifications',
                trailing: [
                  if (unread > 0)
                    LinkButton(
                      label: 'Mark all read',
                      onTap: () => ref
                          .read(notificationReadProvider.notifier)
                          .markAllRead(all),
                    ),
                ],
              ),
            ),
            if (all.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: const Alignment(0, -0.4),
                  child: Semantics(
                    liveRegion: true,
                    child: WlEmptyState(
                      icon: WlIcons.bell,
                      title: "You're all caught up",
                      body: notificationEmptyBody(me, s),
                      secondary: WlStateAction(
                        'Notification settings',
                        () => context.go(Routes.profile),
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              if (scope != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      t.space.gutter,
                      0,
                      t.space.gutter,
                      t.space.xxs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: t.space.xs - 2),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c.role(me.role).ring,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        SizedBox(width: t.space.xs - 2),
                        Expanded(
                          child: Text(
                            scope,
                            style: t.typography.subhead.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final (label, items) in groups) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      t.space.gutter + t.space.xxs,
                      t.space.sm + 2,
                      t.space.gutter,
                      t.space.xs - 2,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        label.toUpperCase(),
                        style: t.typography.overline.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: t.space.gutter),
                  sliver: SliverToBoxAdapter(
                    child: DashCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, n) in items.indexed) ...[
                            if (i > 0)
                              Divider(height: 1, thickness: 1, color: c.border),
                            _NotificationRow(
                              key: ValueKey(n.id),
                              n: n,
                              unread: !read.isRead(n),
                              onTap: () {
                                ref
                                    .read(notificationReadProvider.notifier)
                                    .markRead(n.id);
                                context.push(Routes.patient(n.patientId));
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space.gutter + t.space.xxs,
                    t.space.sm,
                    t.space.gutter,
                    t.space.lg + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Text(
                    'Your own changes never notify you.',
                    style: t.typography.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.n,
    required this.unread,
    required this.onTap,
    super.key,
  });

  final WardNotification n;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final (Color bg, Color fg, IconData icon) = switch (n.kind) {
      NotificationKind.arrived ||
      NotificationKind.left => (c.primarySoft, c.primaryInk, WlIcons.transfer),
      NotificationKind.admission => (
        c.status(PatientStatus.admitted).bg,
        c.status(PatientStatus.admitted).fg,
        WlIcons.admission,
      ),
      _ => (
        c.status(n.status!).bg,
        c.status(n.status!).fg,
        WlIcons.forStatus(n.status!),
      ),
    };
    final time = hm(n.at);
    return Semantics(
      button: true,
      label: '${unread ? 'Unread. ' : ''}${n.title}. ${n.body}. $time',
      excludeSemantics: true,
      child: Material(
        color: unread ? c.primarySoft.withValues(alpha: 0.5) : c.surface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.space.touchMin),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.sm + 2,
                vertical: t.space.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: fg),
                  ),
                  SizedBox(width: t.space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: t.typography.subhead.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: t.space.xxs / 2),
                        Text(
                          n.body,
                          style: t.typography.subhead.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: t.space.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        time,
                        style: t.typography
                            .tabular(t.typography.caption)
                            .copyWith(color: c.textSecondary),
                      ),
                      if (unread) ...[
                        SizedBox(height: t.space.xxs + 2),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
