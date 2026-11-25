import 'package:flutter/material.dart';

import '../../../../core/theme/wl_tokens.dart';
import '../../../../core/widgets/wl/wl.dart';
import '../../application/client_request.dart';

/// White card with hairline rows: "Performed by · Anna Nowak · Nurse".
/// Above text scale 1.3 each row stacks label over value
/// (platform-and-a11y.md), so nothing truncates.
class TransferDetailCard extends StatelessWidget {
  const TransferDetailCard({required this.rows, super.key});

  final List<(String, Widget)> rows;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final stacked = stackRows(MediaQuery.textScalerOf(context).scale(1));
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: t.radius.cardBr,
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (final (i, (label, value)) in rows.indexed)
            Container(
              constraints: BoxConstraints(minHeight: t.space.touchMin),
              padding: EdgeInsets.symmetric(
                horizontal: t.space.sm + 2,
                vertical: t.space.xs,
              ),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: c.border)),
              ),
              child: MergeSemantics(
                child: Flex(
                  direction: stacked ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: stacked
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: t.typography.subhead.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    if (stacked)
                      SizedBox(height: t.space.xxs)
                    else
                      SizedBox(width: t.space.sm),
                    if (stacked)
                      value
                    else
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: value,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Value text for [TransferDetailCard] rows.
class TransferDetailValue extends StatelessWidget {
  const TransferDetailValue(this.text, {this.leading, super.key});

  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final label = Text(
      text,
      textAlign: TextAlign.end,
      style: t.typography
          .tabular(t.typography.subhead)
          .copyWith(color: t.colors.text, fontWeight: FontWeight.w600),
    );
    if (leading == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading!,
        SizedBox(width: t.space.xs),
        Flexible(child: label),
      ],
    );
  }
}

/// Conflict / timeout / error shown as a locked sheet over the confirm
/// screen (TransferFlow steps 5 and 6): scrim + `WlBottomSheet` surface.
class TransferSheetOverlay extends StatelessWidget {
  const TransferSheetOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: ModalBarrier(color: t.colors.scrim, dismissible: false),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: BlockSemantics(
            child: WlBottomSheet(child: SingleChildScrollView(child: child)),
          ),
        ),
      ],
    );
  }
}
