import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';

/// Initials only: never a photo, never status-coloured.
class WlInitialsAvatar extends StatelessWidget {
  /// Neutral patient avatar. Sizes 56 / 40 / 32.
  const WlInitialsAvatar.patient(this.name, {this.size = 40, super.key})
    : role = null;

  /// Staff avatar: role bg + inset ring in the role colour. Always pair it
  /// with a visible role label nearby.
  const WlInitialsAvatar.staff(
    this.name, {
    required UserRole this.role,
    this.size = 32,
    super.key,
  });

  final String name;
  final UserRole? role;
  final double size;

  static String initialsOf(String name) {
    final parts = name
        .replaceFirst(RegExp(r'^Dr\.?\s+'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final r = role == null ? null : c.role(role!);
    final style = (size >= 48 ? t.typography.title3 : t.typography.caption)
        .copyWith(
          color: r?.fg ?? c.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: size <= 24 ? 9 : null,
        );
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: r?.bg ?? c.subtle,
          border: Border.all(
            color: r?.ring ?? c.border,
            width: r == null ? 1 : 2,
          ),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(initialsOf(name), style: style),
          ),
        ),
      ),
    );
  }
}
