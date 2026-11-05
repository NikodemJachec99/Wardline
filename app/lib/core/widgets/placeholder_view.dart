import 'package:flutter/material.dart';

/// Temporary body for screens that are not implemented yet.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(title, style: text.titleLarge),
            const SizedBox(height: 8),
            Text('SIMULATION ONLY — fictional data', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
