import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(title: 'Profil', icon: Icons.person_outline);
  }
}
