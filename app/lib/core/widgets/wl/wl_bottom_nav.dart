import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

/// Five tabs: Dashboard, Patients, Scan (raised 64dp button), History,
/// Profile. 64 high (80 on Android) + bottom inset. No 6th tab.
class WlBottomNav extends StatelessWidget {
  const WlBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  /// 0 Dashboard, 1 Patients, 2 Scan, 3 History, 4 Profile.
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<(String, IconData)> tabs = [
    ('Dashboard', WlIcons.dashboard),
    ('Patients', WlIcons.patients),
    ('Scan', WlIcons.scan),
    ('History', WlIcons.history),
    ('Profile', WlIcons.profile),
  ];

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final android = Theme.of(context).platform == TargetPlatform.android;
    final barHeight = android ? 80.0 : t.space.navBar;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Main',
      child: Container(
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: EdgeInsets.only(bottom: bottom, left: 4, right: 4),
        child: SizedBox(
          height: barHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: i == 2
                      ? _ScanTab(
                          selected: currentIndex == 2,
                          onTap: () => onTap(2),
                        )
                      : _Tab(
                          label: tabs[i].$1,
                          icon: tabs[i].$2,
                          selected: currentIndex == i,
                          onTap: () => onTap(i),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
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
    final fg = selected ? c.primaryInk : c.textSecondary;
    final d = WlMotion.duration(context, t.motion.base);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: d,
              curve: t.motion.out,
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? c.primarySoft
                    : c.primarySoft.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 22, color: fg),
            ),
            SizedBox(height: t.space.xxs),
            AnimatedDefaultTextStyle(
              duration: d,
              style: t.typography.overline.copyWith(
                letterSpacing: 0,
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.fade),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanTab extends StatelessWidget {
  const _ScanTab({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final size = t.space.scanButton;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Scan wristband or QR code',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              top: -26,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: selected ? c.primaryPressed : c.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 4),
                  boxShadow: t.elevation.e2,
                ),
                child: Icon(WlIcons.scan, size: 28, color: c.onPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Scan',
                style: t.typography.overline.copyWith(
                  letterSpacing: 0,
                  color: selected ? c.primaryInk : c.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
