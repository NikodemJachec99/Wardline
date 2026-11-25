import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

/// Offline banner ("You're offline. Showing data from 10:42.") or, with
/// [backOnline], the green "Back online · synced 10:47" variant.
class WlOfflineBanner extends StatelessWidget {
  const WlOfflineBanner({required this.syncedAt, super.key})
    : backOnline = false;

  const WlOfflineBanner.backOnline({required this.syncedAt, super.key})
    : backOnline = true;

  final String syncedAt;
  final bool backOnline;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final ok = c.status(PatientStatus.readyForDischarge);
    final title = backOnline
        ? 'Back online · synced $syncedAt'
        : "You're offline";
    final body = backOnline
        ? null
        : 'Showing data from $syncedAt. It may be out of date.';
    return Semantics(
      liveRegion: true,
      label: body == null ? title : '$title. $body',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        decoration: BoxDecoration(
          color: backOnline ? ok.bg : c.warningBg,
          borderRadius: t.radius.inputBr,
          border: Border.all(
            color: backOnline
                ? ok.base.withValues(alpha: 0.3)
                : c.warningBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              backOnline ? WlIcons.wifi : WlIcons.wifiOff,
              size: 20,
              color: backOnline ? ok.fg : c.warningFg,
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.typography
                        .tabular(t.typography.callout)
                        .copyWith(
                          color: backOnline ? ok.fg : c.warningFg,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (body != null)
                    Text(
                      body,
                      style: t.typography
                          .tabular(t.typography.subhead)
                          .copyWith(color: c.warningFg),
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

/// "Cached · synced 10:42" (neutral) or "... · may be outdated" (warning,
/// after 15 min).
class WlCacheBadge extends StatelessWidget {
  const WlCacheBadge({required this.syncedAt, this.stale = false, super.key});

  final String syncedAt;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final text = stale
        ? 'Cached · synced $syncedAt · may be outdated'
        : 'Cached · synced $syncedAt';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.xs, vertical: 3),
      decoration: BoxDecoration(
        color: stale ? c.warningBg : c.subtle,
        borderRadius: t.radius.chipBr,
        border: Border.all(color: stale ? c.warningBorder : c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            WlIcons.clock,
            size: 14,
            color: stale ? c.warningFg : c.textSecondary,
          ),
          SizedBox(width: t.space.xxs),
          Flexible(
            child: Text(
              text,
              style: t.typography
                  .tabular(t.typography.caption)
                  .copyWith(color: stale ? c.warningFg : c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

enum WlConnectionState { live, reconnecting, offline }

/// Live (green dot + pulse) · Reconnecting… (amber spinner) · Offline.
class WlConnectionIndicator extends StatefulWidget {
  const WlConnectionIndicator({
    required this.state,
    this.onDark = false,
    super.key,
  });

  final WlConnectionState state;

  /// On the dashboard gradient header: white glass pill.
  final bool onDark;

  @override
  State<WlConnectionIndicator> createState() => _WlConnectionIndicatorState();
}

class _WlConnectionIndicatorState extends State<WlConnectionIndicator>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WlConnectionIndicator old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause the pulse in the background.
    if (state == AppLifecycleState.resumed) {
      _sync();
    } else {
      _pulse.stop();
    }
  }

  void _sync() {
    if (widget.state == WlConnectionState.live && !WlMotion.reduced(context)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final ok = c.status(PatientStatus.readyForDischarge);
    final (String label, Color fg, Color bg) = switch (widget.state) {
      WlConnectionState.live => ('Live', ok.fg, ok.bg),
      WlConnectionState.reconnecting => (
        'Reconnecting…',
        c.warningFg,
        c.warningBg,
      ),
      WlConnectionState.offline => ('Offline', c.textSecondary, c.subtle),
    };
    final Widget lead = switch (widget.state) {
      WlConnectionState.live => AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          size: const Size(16, 16),
          painter: _PulsePainter(
            ok.base,
            _pulse.isAnimating ? _pulse.value : null,
          ),
        ),
      ),
      WlConnectionState.reconnecting => SizedBox.square(
        dimension: 12,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.warning),
      ),
      WlConnectionState.offline => Icon(WlIcons.wifiOff, size: 14, color: fg),
    };
    return Semantics(
      liveRegion: true,
      label: 'Connection: $label',
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: t.space.sm - 2),
        decoration: BoxDecoration(
          color: widget.onDark ? c.glassFill : bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            lead,
            SizedBox(width: t.space.xxs + 2),
            Text(
              label,
              style: t.typography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.color, this.v);

  final Color color;
  final double? v;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (v != null) {
      canvas.drawCircle(
        center,
        4 + 7 * v!,
        Paint()..color = color.withValues(alpha: 0.45 * (1 - v!)),
      );
    }
    canvas.drawCircle(center, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.v != v;
}
