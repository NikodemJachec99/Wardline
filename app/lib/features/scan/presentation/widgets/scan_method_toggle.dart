import 'package:flutter/material.dart';

import '../../../../core/theme/wl_tokens.dart';
import '../../../../core/widgets/wl/wl.dart';
import '../scan_copy.dart';

enum ScanMethod { nfc, qr }

/// Segmented "NFC wristband | QR code" control (ScanNfc / ScanEdge). Each
/// segment is a 48dp-high tab with a selected state for screen readers.
class ScanMethodToggle extends StatelessWidget {
  const ScanMethodToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ScanMethod value;
  final ValueChanged<ScanMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Semantics(
      container: true,
      label: ScanCopy.methodGroup,
      child: Container(
        padding: EdgeInsets.all(t.space.xxs / 2),
        decoration: BoxDecoration(
          color: t.colors.subtle,
          borderRadius: t.radius.inputBr,
        ),
        child: Row(
          children: [
            Expanded(
              child: _Segment(
                label: ScanCopy.methodNfc,
                icon: WlIcons.nfc,
                selected: value == ScanMethod.nfc,
                onTap: () => onChanged(ScanMethod.nfc),
              ),
            ),
            SizedBox(width: t.space.xxs / 2),
            Expanded(
              child: _Segment(
                label: ScanCopy.methodQr,
                icon: WlIcons.qr,
                selected: value == ScanMethod.qr,
                onTap: () => onChanged(ScanMethod.qr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final style = t.typography.subhead.copyWith(
      color: selected ? c.text : c.textSecondary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: WlMotion.duration(context, t.motion.fast),
          curve: t.motion.out,
          constraints: BoxConstraints(minHeight: t.space.touchMin),
          padding: EdgeInsets.symmetric(
            horizontal: t.space.xs,
            vertical: t.space.xxs,
          ),
          decoration: BoxDecoration(
            color: selected ? c.surface : c.subtle,
            borderRadius: t.radius.chipBr,
            boxShadow: selected ? t.elevation.e1 : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? c.primaryInk : c.textSecondary,
              ),
              SizedBox(width: t.space.xxs + 2),
              Flexible(
                child: Text(label, style: style, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
