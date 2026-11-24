import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';

enum WlButtonVariant { primary, secondary, destructive, text }

/// Primary actions are 56 high, secondary actions in sheets 48 ([dense]).
///
/// Disabled ([onPressed] null) is only for invalid forms. Never disable a
/// button because of role or offline: don't render it / replace it instead.
class WlButton extends StatefulWidget {
  const WlButton({
    required this.label,
    this.onPressed,
    this.variant = WlButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.loadingLabel,
    this.fullWidth = true,
    this.dense = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final WlButtonVariant variant;
  final IconData? icon;

  /// Spinner + [loadingLabel]; taps are ignored while true.
  final bool loading;
  final String? loadingLabel;
  final bool fullWidth;
  final bool dense;

  @override
  State<WlButton> createState() => _WlButtonState();
}

class _WlButtonState extends State<WlButton> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final enabled = widget.onPressed != null && !widget.loading;
    final disabled = widget.onPressed == null && !widget.loading;
    final reduced = WlMotion.reduced(context);

    late final Color fill;
    late final Color fg;
    Color? borderColor;
    switch (widget.variant) {
      case WlButtonVariant.primary:
        fill = _pressed ? c.primaryInkPressed : c.primaryInk;
        fg = c.onPrimary;
      case WlButtonVariant.secondary:
        fill = _pressed ? c.subtle : c.surface;
        fg = c.text;
        borderColor = c.borderStrong;
      case WlButtonVariant.destructive:
        fill = _pressed ? c.dangerPressed : c.danger;
        fg = c.onPrimary;
      case WlButtonVariant.text:
        fill = _pressed ? c.subtle : c.surface.withValues(alpha: 0);
        fg = c.primaryInk;
    }
    final effectiveFill = disabled && widget.variant != WlButtonVariant.text
        ? c.border
        : fill;
    final effectiveFg = disabled ? c.textDisabled : fg;
    final height = widget.dense ? t.space.input : t.space.action;
    final text = widget.loading
        ? (widget.loadingLabel ?? widget.label)
        : widget.label;

    final content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading) ...[
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: effectiveFg,
            ),
          ),
          SizedBox(width: t.space.xs),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: effectiveFg),
          SizedBox(width: t.space.xs),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: t.typography.label.copyWith(color: effectiveFg),
          ),
        ),
      ],
    );

    final button = AnimatedScale(
      scale: _pressed && !reduced ? 0.98 : 1,
      duration: t.motion.fast,
      curve: t.motion.out,
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        padding: EdgeInsets.symmetric(horizontal: t.space.md),
        decoration: BoxDecoration(
          color: effectiveFill,
          borderRadius: t.radius.inputBr,
          border: borderColor != null && !disabled
              ? Border.all(color: borderColor)
              : null,
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );

    // Focus ring: 2px white gap + 2px primary ring.
    final focusRing = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radius.input + 4),
        border: _focused ? Border.all(color: c.primary, width: 2) : null,
      ),
      child: Padding(padding: const EdgeInsets.all(2), child: button),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: focusRing,
        ),
      ),
    );
  }
}
