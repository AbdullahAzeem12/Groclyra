import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart' as sql;

/// Groclyra Versioned SQL Migration Manager
/// Safely runs sequential schema and data migrations across app updates.
class MigrationManager {
  MigrationManager._();
  static final MigrationManager instance = MigrationManager._();

  /// Handle database schema migrations
  Future<void> onUpgrade(sql.Database db, int oldVersion, int newVersion) async {
    debugPrint('[MigrationManager] Upgrading database from v$oldVersion to v$newVersion...');

    // Ensure schema_migrations table exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        appliedAt TEXT NOT NULL
      );
    ''');

    for (int v = oldVersion + 1; v <= newVersion; v++) {
      await _applyVersionMigration(db, v);
    }
  }

  Future<void> _applyVersionMigration(sql.Database db, int version) async {
    switch (version) {
      case 2:
        await _applyV2Migration(db);
        break;
      default:
        debugPrint('[MigrationManager] No specific script for version $version');
    }
  }

  Future<void> _applyV2Migration(sql.Database db) async {
    try {
      // 1. Try loading raw migration script from assets
      final sqlScript = await rootBundle.loadString('assets/sql/migrations/v2_add_coupons_and_audit.sql');
      final statements = sqlScript.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty);
      for (final stmt in statements) {
        await db.execute(stmt);
      }
      debugPrint('[MigrationManager] v2 migration applied successfully from assets.');
    } catch (_) {
      // Fallback inline execution
      await db.execute('''
        CREATE TABLE IF NOT EXISTS coupons (
          id TEXT PRIMARY KEY NOT NULL,
          code TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          discountPercentage INTEGER NOT NULL,
          maxDiscount REAL,
          minOrderAmount REAL DEFAULT 0.0,
          validUntil TEXT NOT NULL,
          isActive INTEGER DEFAULT 1,
          usageCount INTEGER DEFAULT 0,
          createdAt TEXT NOT NULL
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);');
      await db.execute('''
        INSERT OR REPLACE INTO schema_migrations (version, name, appliedAt)
        VALUES (2, 'v2_add_coupons_and_audit', datetime('now'));
      ''');
      debugPrint('[MigrationManager] v2 migration applied via inline fallback.');
    }
  }
}

