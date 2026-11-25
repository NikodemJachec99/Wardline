import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';
import 'wl_initials_avatar.dart';
import 'wl_live_highlight.dart';
import 'wl_status_chip.dart';

/// Patient card. Compact (lists) or expanded (profile header).
///
/// Swipe on the compact card reveals View profile / Show on map only, never
/// a transfer. Both are also exposed as semantics custom actions.
class WlPatientCard extends StatefulWidget {
  const WlPatientCard.compact({
    required this.name,
    required this.age,
    required this.status,
    required this.subtitle,
    this.onTap,
    this.onShowOnMap,
    this.highlightKey,
    this.cachedAsOf,
    super.key,
  }) : patientCode = null,
       locationName = null,
       locationDetail = null,
       expanded = false;

  const WlPatientCard.expanded({
    required this.name,
    required this.age,
    required this.status,
    required String this.patientCode,
    required String this.locationName,
    required String this.locationDetail,
    this.highlightKey,
    this.cachedAsOf,
    super.key,
  }) : subtitle = '',
       onTap = null,
       onShowOnMap = null,
       expanded = true;

  final String name;
  final int age;
  final PatientStatus status;

  /// Compact: location, or "Moved to X · now" after a live update.
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onShowOnMap;

  /// Change to replay the live highlight.
  final Object? highlightKey;

  /// Offline: "as of 10:42".
  final String? cachedAsOf;

  final String? patientCode;
  final String? locationName;

  /// "Floor 1 · since 10:46 · by Anna Nowak".
  final String? locationDetail;
  final bool expanded;

  @override
  State<WlPatientCard> createState() => _WlPatientCardState();
}

class _WlPatientCardState extends State<WlPatientCard> {
  static const double _actionsWidth = 176;
  double _offset = 0;
  bool _pressed = false;

  void _settle() => setState(
    () => _offset = _offset < -_actionsWidth / 2 ? -_actionsWidth : 0,
  );

  @override
  Widget build(BuildContext context) {
    return widget.expanded ? _expanded(context) : _compact(context);
  }

  Widget _compact(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final s = c.status(widget.status);
    final sub = widget.cachedAsOf == null
        ? widget.subtitle
        : '${widget.subtitle} · as of ${widget.cachedAsOf}';

    final card = AnimatedScale(
      scale: _pressed && !WlMotion.reduced(context) ? 0.98 : 1,
      duration: t.motion.fast,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        decoration: BoxDecoration(
          color: _pressed ? c.subtle : c.surface,
          borderRadius: t.radius.cardBr,
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: WlLiveHighlight(
          pulseKey: widget.highlightKey,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: WlMotion.duration(context, t.motion.base),
                  width: 4,
                  color: s.base,
                ),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: t.space.sm),
                    child: Row(
                      children: [
                        WlInitialsAvatar.patient(widget.name),
                        SizedBox(width: t.space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: widget.name,
                                      style: t.typography.label.copyWith(
                                        color: c.text,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '  ${widget.age}',
                                      style: t.typography
                                          .tabular(t.typography.subhead)
                                          .copyWith(color: c.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: t.space.xxs / 2),
                              Text(
                                sub,
                                style: t.typography.subhead.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: t.space.xs),
                        WlStatusChip(
                          widget.status,
                          size: WlChipSize.sm,
                          short: true,
                        ),
                        SizedBox(width: t.space.xxs),
                        Icon(
                          WlIcons.chevronRight,
                          size: 20,
                          color: c.textDisabled,
                        ),
                        SizedBox(width: t.space.xs),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final label = '${widget.name}, ${widget.age}, $sub, ${s.label}';
    final actions = <CustomSemanticsAction, VoidCallback>{
      if (widget.onTap != null)
        const CustomSemanticsAction(label: 'View profile'): widget.onTap!,
      if (widget.onShowOnMap != null)
        const CustomSemanticsAction(label: 'Show on map'): widget.onShowOnMap!,
    };

    return Semantics(
      button: true,
      label: label,
      customSemanticsActions: actions,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Stack(
        children: [
          if (_offset != 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: _actionsWidth,
                  child: Row(
                    children: [
                      _SwipeAction(
                        icon: WlIcons.eye,
                        label: 'View profile',
                        onTap: () {
                          setState(() => _offset = 0);
                          widget.onTap?.call();
                        },
                      ),
                      _SwipeAction(
                        icon: WlIcons.map,
                        label: 'Show on map',
                        onTap: () {
                          setState(() => _offset = 0);
                          widget.onShowOnMap?.call();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: t.motion.fast,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              onTap: () {
                if (_offset != 0) {
                  setState(() => _offset = 0);
                } else {
                  widget.onTap?.call();
                }
              },
              onHorizontalDragUpdate: (d) => setState(
                () => _offset = (_offset + d.delta.dx).clamp(-_actionsWidth, 0),
              ),
              onHorizontalDragEnd: (_) => _settle(),
              child: card,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expanded(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final cached = widget.cachedAsOf == null
        ? ''
        : ' · as of ${widget.cachedAsOf}';

    Widget row(String label, Widget value) {
      final l = Text(
        label,
        style: t.typography.subhead.copyWith(color: c.textSecondary),
      );
      return stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                l,
                SizedBox(height: t.space.xxs),
                value,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 112, child: l),
                Expanded(child: value),
              ],
            );
    }

    return WlLiveHighlight(
      pulseKey: widget.highlightKey,
      borderRadius: t.radius.cardBr,
      child: Container(
        padding: EdgeInsets.all(t.space.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: t.radius.cardBr,
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WlInitialsAvatar.patient(widget.name, size: 56),
                SizedBox(width: t.space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          widget.name,
                          style: t.typography.title1.copyWith(color: c.text),
                        ),
                      ),
                      SizedBox(height: t.space.xxs),
                      Text(
                        '${widget.age} · ${widget.patientCode}',
                        style: t.typography.id.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space.md),
            Divider(height: 1, color: c.border),
            SizedBox(height: t.space.md),
            row(
              'Status',
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: WlStatusChip(widget.status),
              ),
            ),
            SizedBox(height: t.space.sm),
            row(
              'Last location',
              Semantics(
                label:
                    'Last location: ${widget.locationName}, ${widget.locationDetail}$cached',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        WlIcons.mapPin,
                        size: 20,
                        color: c.primaryInk,
                      ),
                    ),
                    SizedBox(width: t.space.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.locationName!,
                            style: t.typography.label.copyWith(color: c.text),
                          ),
                          Text(
                            '${widget.locationDetail}$cached',
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: t.colors.primaryInk),
            SizedBox(height: t.space.xxs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: t.typography.caption.copyWith(color: t.colors.primaryInk),
            ),
          ],
        ),
      ),
    );
  }
}
