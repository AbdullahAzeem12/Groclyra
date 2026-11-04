import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme_data.dart';
import 'core/theme/theme_controller.dart';
import 'routing/app_router.dart';

class GroclyraApp extends ConsumerWidget {
  const GroclyraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeState.mode,
      theme: AppThemeData.buildTheme(
        palette: themeState.palette,
        brightness: Brightness.light,
      ),
      darkTheme: AppThemeData.buildTheme(
        palette: themeState.palette,
        brightness: Brightness.dark,
      ),
      routerConfig: router,
    );
  }
}
