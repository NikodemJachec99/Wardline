import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';

/// Realtime row highlight: `primarySoft` held, then fades to transparent
/// (2400ms, hold 60%, 300ms delay). Reduced motion: a static "Updated" dot
/// for 5s instead.
///
/// Change [pulseKey] (e.g. the event id) to replay it.
class WlLiveHighlight extends StatefulWidget {
  const WlLiveHighlight({
    required this.child,
    this.pulseKey,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final Object? pulseKey;
  final BorderRadius? borderRadius;

  @override
  State<WlLiveHighlight> createState() => _WlLiveHighlightState();
}

class _WlLiveHighlightState extends State<WlLiveHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2700),
  );
  bool _dot = false;

  @override
  void initState() {
    super.initState();
    if (widget.pulseKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    }
  }

  @override
  void didUpdateWidget(WlLiveHighlight old) {
    super.didUpdateWidget(old);
    if (widget.pulseKey != null && widget.pulseKey != old.pulseKey) _play();
  }

  void _play() {
    if (!mounted) return;
    if (WlMotion.reduced(context)) {
      setState(() => _dot = true);
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _dot = false);
      });
      return;
    }
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // 300ms delay, then hold 60% of 2400ms, then fade.
        final v = _c.value * 2700;
        double alpha;
        if (!_c.isAnimating && _c.value == 0) {
          alpha = 0;
        } else if (v < 300) {
          alpha = v / 300;
        } else if (v < 300 + 1440) {
          alpha = 1;
        } else {
          alpha = 1 - ((v - 1740) / 960).clamp(0.0, 1.0);
        }
        if (_c.isCompleted) alpha = 0;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: t.colors.primarySoft.withValues(alpha: alpha),
            borderRadius: widget.borderRadius,
          ),
          child: child,
        );
      },
      child: Stack(
        children: [
          widget.child,
          if (_dot)
            Positioned(
              top: t.space.xs,
              right: t.space.xs,
              child: Semantics(
                label: 'Updated',
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
