import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(title: 'Pacjenci', icon: Icons.people_outline);
  }
}
