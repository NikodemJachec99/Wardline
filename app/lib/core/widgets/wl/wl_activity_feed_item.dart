import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_initials_avatar.dart';
import 'wl_live_highlight.dart';

/// "Who did what" row: staff avatar, sentence with the patient in bold, sub
/// line, time ago. [live] replays the highlight and shows a teal dot.
class WlActivityFeedItem extends StatelessWidget {
  const WlActivityFeedItem({
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.patientName,
    required this.subline,
    required this.timeAgo,
    this.live = false,
    this.highlightKey,
    this.onTap,
    super.key,
  });

  final String actorName;
  final UserRole actorRole;

  /// Verb phrase, e.g. "moved".
  final String action;
  final String patientName;

  /// "Laboratory → Radiology".
  final String subline;
  final String timeAgo;
  final bool live;
  final Object? highlightKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final shortActor = _short(actorName);
    return Semantics(
      button: onTap != null,
      label: '$shortActor $action $patientName, $subline, $timeAgo',
      excludeSemantics: true,
      child: WlLiveHighlight(
        pulseKey: highlightKey,
        borderRadius: t.radius.inputBr,
        child: InkWell(
          onTap: onTap,
          borderRadius: t.radius.inputBr,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: t.space.sm - 2,
              horizontal: t.space.xxs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WlInitialsAvatar.staff(actorName, role: actorRole),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: t.typography.subhead.copyWith(color: c.text),
                          children: [
                            TextSpan(text: '$shortActor $action '),
                            TextSpan(
                              text: patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subline,
                        style: t.typography.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: t.space.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (live) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: t.space.xxs),
                    ],
                    Text(
                      timeAgo,
                      style: t.typography
                          .tabular(t.typography.caption)
                          .copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Anna Nowak" → "A. Nowak"; "Dr Ewa Lis" stays.
  static String _short(String name) {
    if (name.startsWith('Dr')) return name;
    final parts = name.split(' ');
    if (parts.length < 2) return name;
    return '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
  }
}
