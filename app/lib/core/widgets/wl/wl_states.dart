import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_button.dart';
import 'wl_icons.dart';

@immutable
class WlStateAction {
  const WlStateAction(this.label, this.onPressed, {this.icon});

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

enum WlErrorTone { danger, warning, neutral }

/// Empty list / no results: icon circle, title, body, up to two actions.
class WlEmptyState extends StatelessWidget {
  const WlEmptyState({
    required this.icon,
    required this.title,
    this.body,
    this.primary,
    this.secondary,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final WlStateAction? primary;
  final WlStateAction? secondary;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return _StateLayout(
      icon: icon,
      iconBg: t.colors.subtle,
      iconFg: t.colors.textSecondary,
      title: title,
      body: body,
      primary: primary,
      secondary: secondary,
    );
  }
}

/// Load failed (danger), conflict PT409 (warning, with [rows] Who/When/
/// Where), timeout (neutral, request reference), unknown tag, no NFC,
/// camera denied. Copy: design/handoff/copy.md.
class WlErrorState extends StatelessWidget {
  const WlErrorState({
    required this.title,
    this.body,
    this.tone = WlErrorTone.danger,
    this.icon,
    this.rows = const [],
    this.primary,
    this.secondary,
    this.footnote,
    super.key,
  });

  final String title;
  final String? body;
  final WlErrorTone tone;
  final IconData? icon;
  final List<(String, String)> rows;
  final WlStateAction? primary;
  final WlStateAction? secondary;

  /// e.g. "Request ref 7F3A-21".
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final (Color bg, Color fg, IconData i) = switch (tone) {
      WlErrorTone.danger => (c.dangerBg, c.danger, WlIcons.error),
      WlErrorTone.warning => (c.warningBg, c.warningFg, WlIcons.alert),
      WlErrorTone.neutral => (c.subtle, c.textSecondary, WlIcons.clock),
    };
    return _StateLayout(
      icon: icon ?? i,
      iconBg: bg,
      iconFg: fg,
      title: title,
      body: body,
      rows: rows,
      primary: primary,
      secondary: secondary,
      footnote: footnote,
      liveRegion: true,
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    this.body,
    this.rows = const [],
    this.primary,
    this.secondary,
    this.footnote,
    this.liveRegion = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? body;
  final List<(String, String)> rows;
  final WlStateAction? primary;
  final WlStateAction? secondary;
  final String? footnote;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Padding(
      padding: EdgeInsets.all(t.space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 24, color: iconFg),
          ),
          SizedBox(height: t.space.md),
          Semantics(
            liveRegion: liveRegion,
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: t.typography.title3.copyWith(color: c.text),
            ),
          ),
          if (body != null) ...[
            SizedBox(height: t.space.xs),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: t.typography.subhead.copyWith(color: c.textSecondary),
            ),
          ],
          if (rows.isNotEmpty) ...[
            SizedBox(height: t.space.md),
            Container(
              padding: EdgeInsets.all(t.space.sm),
              decoration: BoxDecoration(
                color: c.subtle,
                borderRadius: t.radius.inputBr,
              ),
              child: Column(
                children: [
                  for (final (k, v) in rows)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: t.space.xxs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              k,
                              style: t.typography.subhead.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              v,
                              style: t.typography
                                  .tabular(t.typography.subhead)
                                  .copyWith(
                                    color: c.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (primary != null) ...[
            SizedBox(height: t.space.lg),
            WlButton(
              label: primary!.label,
              icon: primary!.icon,
              onPressed: primary!.onPressed,
            ),
          ],
          if (secondary != null) ...[
            SizedBox(height: t.space.xs),
            WlButton(
              label: secondary!.label,
              icon: secondary!.icon,
              variant: WlButtonVariant.text,
              dense: true,
              onPressed: secondary!.onPressed,
            ),
          ],
          if (footnote != null) ...[
            SizedBox(height: t.space.sm),
            Text(
              footnote!,
              style: t.typography.id.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
