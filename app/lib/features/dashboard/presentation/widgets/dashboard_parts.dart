// Building blocks of Dashboard B (design/canvas/DashB.dc.html). Private to
// the dashboard feature; admin reuses [WlActionTile] and [DashCard].

import 'package:flutter/material.dart';

import '../../../../core/theme/wl_tokens.dart';

/// Text scale above 1.3 stacks label/value rows (platform-and-a11y.md).
bool largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > 1.3;

/// White card with a hairline border (radius 16), optionally tappable.
class DashCard extends StatelessWidget {
  const DashCard({
    required this.child,
    this.onTap,
    this.padding,
    this.semanticsLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    Widget body = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    if (onTap != null) body = InkWell(onTap: onTap, child: body);
    final card = Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: t.radius.cardBr,
        side: BorderSide(color: c.border),
      ),
      child: body,
    );
    if (semanticsLabel == null) return card;
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: card,
    );
  }
}

/// Quick action tile (DashB: Scan NFC, Scan QR, Search patient): 76 high,
/// icon over label. [horizontal] lays it out as a full-width row (large
/// text).
class WlActionTile extends StatelessWidget {
  const WlActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.horizontal = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool horizontal;

  static const double _height = 76;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final text = Text(
      label,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: t.typography.subhead.copyWith(
        color: c.text,
        fontWeight: FontWeight.w600,
      ),
    );
    final icon = Icon(this.icon, size: 24, color: c.primaryInk);
    return DashCard(
      onTap: onTap,
      semanticsLabel: label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: horizontal ? t.space.action : _height,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.space.xs,
            vertical: t.space.xs,
          ),
          child: horizontal
              ? Row(
                  children: [
                    SizedBox(width: t.space.xs),
                    icon,
                    SizedBox(width: t.space.sm),
                    Expanded(child: text),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    SizedBox(height: t.space.xxs + 2),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}

/// A row of tiles that turns into a column at large text sizes.
class ActionTileGrid extends StatelessWidget {
  const ActionTileGrid({required this.tiles, super.key});

  final List<({IconData icon, String label, VoidCallback onTap})> tiles;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final gap = t.space.sm - 2;
    if (largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, a) in tiles.indexed) ...[
            if (i > 0) SizedBox(height: gap),
            WlActionTile(
              icon: a.icon,
              label: a.label,
              onTap: a.onTap,
              horizontal: true,
            ),
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, a) in tiles.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: WlActionTile(icon: a.icon, label: a.label, onTap: a.onTap),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card section title (17/600) with an optional trailing link ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.trailingText,
    this.action,
    this.onAction,
    this.actionSemantics,
    super.key,
  });

  final String title;

  /// Secondary text on the right ("128 of 210 beds").
  final String? trailingText;
  final String? action;
  final VoidCallback? onAction;
  final String? actionSemantics;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final titleText = Semantics(
      header: true,
      child: Text(title, style: t.typography.title3.copyWith(color: c.text)),
    );
    final trailing = <Widget>[
      if (trailingText != null)
        Text(
          trailingText!,
          style: t.typography
              .tabular(t.typography.caption)
              .copyWith(color: c.textSecondary),
        ),
      if (action != null) LinkButton(label: action!, onTap: onAction!),
    ];
    if (largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleText, ...trailing],
      );
    }
    return Row(
      children: [
        Expanded(child: titleText),
        for (final w in trailing) ...[SizedBox(width: t.space.xs), w],
      ],
    );
  }
}

/// Teal text link with a 48dp target ("See all", "Open", "Mark all read").
class LinkButton extends StatelessWidget {
  const LinkButton({
    required this.label,
    required this.onTap,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radius.inputBr,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: t.space.touchMin,
            minWidth: t.space.touchMin,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.xs),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: t.typography.subhead.copyWith(
                  color: t.colors.primaryInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cards fade and rise in one after another on the first build
/// (motion.md "Card stagger": 220ms, +40ms per card, max 6). Reduced
/// motion: a plain 120ms fade, no offset, no stagger.
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    required this.animation,
    required this.index,
    required this.reduced,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final int index;
  final bool reduced;
  final Widget child;

  /// Delay between cards, motion.md.
  static const int stepMs = 40;
  static const int maxCards = 6;

  /// Whole sequence relative to `motion.base`.
  static double totalFactor(Duration base) =>
      (base.inMilliseconds + stepMs * (maxCards - 1)) / base.inMilliseconds;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    if (reduced) return FadeTransition(opacity: animation, child: child);
    final base = t.motion.base.inMilliseconds;
    final total = base + stepMs * (maxCards - 1);
    final i = index.clamp(0, maxCards - 1);
    final v = animation.drive(
      CurveTween(
        curve: Interval(
          i * stepMs / total,
          (i * stepMs + base) / total,
          curve: t.motion.out,
        ),
      ),
    );
    return FadeTransition(
      opacity: v,
      child: AnimatedBuilder(
        animation: v,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, t.space.xs * (1 - v.value)),
          child: child,
        ),
      ),
    );
  }
}
