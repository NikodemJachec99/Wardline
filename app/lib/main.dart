import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SIMULATION ONLY: demo hospital from design/handoff/sample-data.json until
  // the Supabase repository (issue #16) is wired in.
  final sample = await rootBundle.loadString('assets/demo/sample-data.json');
  runApp(
    ProviderScope(
      overrides: [
        hospitalRepositoryProvider.overrideWithValue(
          buildDemoRepository(sample),
        ),
      ],
      child: const WardlineApp(),
    ),
  );
}
