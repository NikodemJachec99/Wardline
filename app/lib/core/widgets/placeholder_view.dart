import 'package:flutter/material.dart';

import '../theme/wl_tokens.dart';
import 'wl/wl.dart';

/// Temporary body for screens that are not implemented yet.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canPop)
              IconButton(
                tooltip: 'Back',
                icon: Icon(WlIcons.back, color: t.colors.text),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.gutter,
                canPop ? 0 : t.space.md,
                t.space.gutter,
                0,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: t.typography.title1.copyWith(color: t.colors.text),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: WlEmptyState(
                  icon: icon,
                  title: title,
                  body: 'Simulation · fictional data',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
