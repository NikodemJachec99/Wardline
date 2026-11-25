import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

enum WlToastTone { success, info, warning, danger }

/// Shows a toast above the bottom nav for 4s. Success toasts only after the
/// server confirmed the write.
void showWlToast(
  BuildContext context, {
  required String title,
  String? body,
  WlToastTone tone = WlToastTone.success,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _ToastHost(
      duration: duration,
      onDone: remove,
      child: WlToast(
        title: title,
        body: body,
        tone: tone,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                remove();
                onAction();
              },
      ),
    ),
  );
  overlay.insert(entry);
}

class WlToast extends StatelessWidget {
  const WlToast({
    required this.title,
    this.body,
    this.tone = WlToastTone.success,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? body;
  final WlToastTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final ok = c.status(PatientStatus.readyForDischarge);
    final (Color bg, Color fg, IconData icon) = switch (tone) {
      WlToastTone.success => (ok.bg, ok.fg, WlIcons.check),
      WlToastTone.info => (c.primarySoft, c.primaryInk, WlIcons.info),
      WlToastTone.warning => (c.warningBg, c.warningFg, WlIcons.alert),
      WlToastTone.danger => (c.dangerBg, c.danger, WlIcons.error),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: EdgeInsets.all(t.space.sm),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: t.radius.cardBr,
            boxShadow: t.elevation.e2,
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: fg),
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: t.typography.callout.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (body != null)
                      Text(
                        body!,
                        style: t.typography.subhead.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: c.primaryInk,
                    minimumSize: Size(t.space.touchMin, t.space.touchMin),
                    textStyle: t.typography.callout.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.child,
    required this.duration,
    required this.onDone,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    _timer = Timer(widget.duration, () async {
      if (!mounted) return;
      setState(() => _shown = false);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final reduced = WlMotion.reduced(context);
    final bottom = MediaQuery.paddingOf(context).bottom + t.space.navBar + 24;
    return Positioned(
      left: t.space.gutter,
      right: t.space.gutter,
      bottom: bottom,
      child: AnimatedSlide(
        offset: Offset(0, _shown || reduced ? 0 : 0.2),
        duration: _shown ? t.motion.base : t.motion.fast,
        curve: t.motion.out,
        child: AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: _shown ? t.motion.base : t.motion.fast,
          child: widget.child,
        ),
      ),
    );
  }
}
