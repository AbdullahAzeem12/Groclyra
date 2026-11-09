import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/database/app_database.dart';
import 'core/storage/preferences_service.dart';
import 'core/services/rate_limit_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive edge-to-edge transparent system overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Groclyra SQL Database (SQLite)
  try {
    await AppDatabase.instance.init();
    debugPrint('Groclyra SQLite Database initialized successfully.');
  } catch (e) {
    debugPrint('Groclyra SQLite Database initialization warning: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  final preferencesService = await PreferencesService.create();
  final rateLimitService = await RateLimitService.create();

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
        rateLimitServiceProvider.overrideWithValue(rateLimitService),
      ],
      child: const GroclyraApp(),
    ),
  );
}
