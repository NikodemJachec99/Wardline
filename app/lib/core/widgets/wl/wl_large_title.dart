import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

/// Screen header: optional back button, large title (title1), optional
/// subtitle and trailing widgets (connection indicator, actions). Use it on
/// every screen so headers match the design.
class WlLargeTitle extends StatelessWidget {
  const WlLargeTitle({
    required this.title,
    this.subtitle,
    this.trailing = const [],
    this.showBack,
    this.onBack,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  /// Defaults to `Navigator.canPop`.
  final bool? showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final back = showBack ?? Navigator.of(context).canPop();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        back ? t.space.xxs : t.space.gutter,
        t.space.xs,
        t.space.gutter,
        t.space.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (back)
            IconButton(
              tooltip: 'Back',
              icon: Icon(WlIcons.back, color: c.text),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: (back ? t.typography.title2 : t.typography.title1)
                        .copyWith(color: c.text),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: t.typography.subhead.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          for (final w in trailing) ...[SizedBox(width: t.space.xs), w],
        ],
      ),
    );
  }
}
