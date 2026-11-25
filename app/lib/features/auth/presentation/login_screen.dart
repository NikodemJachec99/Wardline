import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';
import '../../../core/widgets/wl/wl.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(title: 'Sign in', icon: WlIcons.lock);
  }
}
