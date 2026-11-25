import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';
import 'wl_initials_avatar.dart';
import 'wl_live_highlight.dart';

enum WlTimelineKind { transfer, status, admission }

/// One history entry on the patient profile: node, rail, title, time, line,
/// staff. Tap expands the details (From, To, identified by, ...).
class WlTimelineItem extends StatefulWidget {
  const WlTimelineItem({
    required this.kind,
    required this.title,
    required this.time,
    required this.staffName,
    required this.staffRole,
    this.line,
    this.details = const [],
    this.isLast = false,
    this.highlightKey,
    this.statusForNode,
    super.key,
  });

  final WlTimelineKind kind;
  final String title;

  /// "10:46" (tabular).
  final String time;
  final String? line;
  final String staffName;
  final UserRole staffRole;
  final List<(String, String)> details;
  final bool isLast;
  final Object? highlightKey;

  /// Status entries: node uses this status' colours (default In Treatment).
  final PatientStatus? statusForNode;

  @override
  State<WlTimelineItem> createState() => _WlTimelineItemState();
}

class _WlTimelineItemState extends State<WlTimelineItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final (Color bg, Color fg, IconData icon) = switch (widget.kind) {
      WlTimelineKind.transfer => (
        c.primarySoft,
        c.primaryInk,
        WlIcons.transfer,
      ),
      WlTimelineKind.status => (
        c.status(widget.statusForNode ?? PatientStatus.inTreatment).bg,
        c.status(widget.statusForNode ?? PatientStatus.inTreatment).fg,
        WlIcons.status,
      ),
      WlTimelineKind.admission => (
        c.status(PatientStatus.admitted).bg,
        c.status(PatientStatus.admitted).fg,
        WlIcons.admission,
      ),
    };
    final role = c.role(widget.staffRole);

    return WlLiveHighlight(
      pulseKey: widget.highlightKey,
      borderRadius: t.radius.inputBr,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: fg),
                  ),
                  if (!widget.isLast)
                    Expanded(child: Container(width: 2, color: c.border)),
                ],
              ),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Semantics(
                button: widget.details.isNotEmpty,
                expanded: widget.details.isEmpty ? null : _open,
                child: InkWell(
                  onTap: widget.details.isEmpty
                      ? null
                      : () => setState(() => _open = !_open),
                  borderRadius: t.radius.inputBr,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: widget.isLast ? 0 : t.space.md,
                      top: t.space.xxs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: t.typography.callout.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: t.space.xs),
                            Text(
                              widget.time,
                              style: t.typography
                                  .tabular(t.typography.subhead)
                                  .copyWith(color: c.textSecondary),
                            ),
                          ],
                        ),
                        if (widget.line != null) ...[
                          SizedBox(height: t.space.xxs / 2),
                          Text(
                            widget.line!,
                            style: t.typography.subhead.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                        SizedBox(height: t.space.xs),
                        Row(
                          children: [
                            WlInitialsAvatar.staff(
                              widget.staffName,
                              role: widget.staffRole,
                              size: 20,
                            ),
                            SizedBox(width: t.space.xs - 2),
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: widget.staffName,
                                      style: t.typography.caption.copyWith(
                                        color: c.text,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' · ${role.label}',
                                      style: t.typography.caption.copyWith(
                                        color: role.fg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_open) ...[
                          SizedBox(height: t.space.sm),
                          Container(
                            padding: EdgeInsets.all(t.space.sm),
                            decoration: BoxDecoration(
                              color: c.subtle,
                              borderRadius: t.radius.inputBr,
                            ),
                            child: Column(
                              children: [
                                for (final (k, v) in widget.details)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: t.space.xxs / 2,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            k,
                                            style: t.typography.caption
                                                .copyWith(
                                                  color: c.textSecondary,
                                                ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            v,
                                            style: t.typography
                                                .tabular(t.typography.caption)
                                                .copyWith(color: c.text),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
