import 'package:flutter/foundation.dart';
import 'package:groclyra/core/database/app_database.dart';

/// Groclyra Database Seeder (SQLite).
/// Safe to call multiple times: seeds missing demo data without overwriting user data.
class FirestoreSeeder {
  static Future<void> seedIfEmpty() async {
    if (!kDebugMode) {
      debugPrint('FirestoreSeeder: demonstration seeding is disabled in non-debug mode.');
      return;
    }
    try {
      await AppDatabase.instance.seedInitialData();
      debugPrint('FirestoreSeeder: SQLite catalog and demo data verified!');
    } catch (e) {
      debugPrint('FirestoreSeeder.seedIfEmpty error: $e');
    }
  }

  static Future<void> seedCategories() async {
    await AppDatabase.instance.seedInitialData();
  }

  static Future<void> seedProducts() async {
    await AppDatabase.instance.seedInitialData();
  }
}
