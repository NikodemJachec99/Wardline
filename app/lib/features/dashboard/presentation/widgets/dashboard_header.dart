import 'package:flutter/material.dart';

import '../../../../core/theme/wl_tokens.dart';
import '../../../../core/widgets/wl/wl.dart';
import '../../../../domain/models.dart';
import 'dashboard_parts.dart';

/// Gradient header of Dashboard B: avatar, greeting, role · shift,
/// connection pill, notifications bell, then the KPI cards on glass.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.me,
    required this.greeting,
    required this.subtitle,
    required this.connection,
    required this.unread,
    required this.onBell,
    required this.kpis,
    super.key,
  });

  final StaffMember me;
  final String greeting;
  final String subtitle;
  final WlConnectionState connection;
  final int unread;
  final VoidCallback onBell;
  final List<Widget> kpis;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final large = largeText(context);
    final top = MediaQuery.paddingOf(context).top;

    final avatar = WlInitialsAvatar.staff(me.name, role: me.role, size: 44);
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            greeting,
            style: t.typography.title2.copyWith(
              color: c.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          subtitle,
          style: t.typography
              .tabular(t.typography.subhead)
              .copyWith(
                color: c.onPrimary.withValues(alpha: 0.92),
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
    final status = <Widget>[
      WlConnectionIndicator(state: connection, onDark: true),
      SizedBox(width: t.space.xxs),
      _BellButton(unread: unread, onTap: onBell),
    ];

    // The bell needs room next to the Live pill, so they share the
    // avatar's row and the greeting gets the full width below (DashB has
    // no bell; at 390dp the greeting would wrap mid-time otherwise).
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [avatar, const Spacer(), ...status]),
        SizedBox(height: t.space.sm),
        texts,
      ],
    );

    final gap = t.space.sm - 2;
    final Widget grid = large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, k) in kpis.indexed) ...[
                if (i > 0) SizedBox(height: gap),
                k,
              ],
            ],
          )
        : Column(
            children: [
              for (var r = 0; r < kpis.length; r += 2) ...[
                if (r > 0) SizedBox(height: gap),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: kpis[r]),
                      SizedBox(width: gap),
                      Expanded(
                        child: r + 1 < kpis.length
                            ? kpis[r + 1]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );

    return Container(
      decoration: BoxDecoration(
        gradient: c.dashboardHeader,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(t.radius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        t.space.gutter,
        top + t.space.sm,
        t.space.gutter,
        t.space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          identity,
          SizedBox(height: t.space.md),
          grid,
        ],
      ),
    );
  }
}

/// Glass bell (48dp target) with a teal unread dot.
class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  static const double _circle = 40;
  static const double _dot = 10;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: t.space.touchMin / 2,
        child: SizedBox.square(
          dimension: t.space.touchMin,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _circle,
                  height: _circle,
                  decoration: BoxDecoration(
                    color: c.glassFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.glassBorder),
                  ),
                  child: Icon(WlIcons.bell, size: 20, color: c.primaryInk),
                ),
                if (unread > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: _dot,
                      height: _dot,
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
