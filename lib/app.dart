import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/application/theme_controller.dart';

class VCloudApp extends ConsumerWidget {
  const VCloudApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'VCloud',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode.when(
        data: (mode) => mode.themeMode,
        loading: () => ThemeMode.system,
        error: (e, st) => ThemeMode.system,
      ),
      routerConfig: router,
    );
  }
}
