import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';
import '../../../core/widgets/wl/wl.dart';

class DayTimelineScreen extends StatelessWidget {
  const DayTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(title: 'Day timeline', icon: WlIcons.timeline);
  }
}
