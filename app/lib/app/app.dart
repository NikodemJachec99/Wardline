import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/wl_tokens.dart';
import 'router.dart';
import 'state/providers.dart';
import 'theme.dart';

class WardlineApp extends ConsumerWidget {
  const WardlineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(
      settingsProvider.select((s) => s.reduceMotion),
    );
    return WlMotionScope(
      reduceMotion: reduceMotion,
      child: MaterialApp.router(
        title: 'Wardline',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
