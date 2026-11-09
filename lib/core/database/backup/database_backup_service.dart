import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sql;
import '../app_database.dart';

/// Groclyra Database Backup, Integrity & Storage Diagnostics Service
class DatabaseBackupService {
  DatabaseBackupService._();
  static final DatabaseBackupService instance = DatabaseBackupService._();

  /// Returns the physical on-disk file path of groclyra.db
  Future<String> getDatabasePath() async {
    final dbPath = await sql.getDatabasesPath();
    return p.join(dbPath, 'groclyra.db');
  }

  /// Returns physical database file size in bytes
  Future<int> getDatabaseSizeBytes() async {
    try {
      final path = await getDatabasePath();
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      debugPrint('[DatabaseBackupService] Error reading file size: $e');
    }
    return 0;
  }

  /// Run SQLite integrity checks
  Future<Map<String, dynamic>> checkIntegrity() async {
    final results = <String, dynamic>{
      'integrityCheck': 'UNKNOWN',
      'foreignKeysCheck': 'UNKNOWN',
    };
    try {
      final db = AppDatabase.instance;
      final integrity = await db.rawQuery('PRAGMA integrity_check;');
      final fk = await db.rawQuery('PRAGMA foreign_key_check;');
      results['integrityCheck'] = integrity.isNotEmpty ? integrity.first.values.first : 'OK';
      results['foreignKeysCheck'] = fk.isEmpty ? 'OK' : '${fk.length} violations';
    } catch (e) {
      results['error'] = e.toString();
    }
    return results;
  }

  /// Reclaims unused disk space and defragments SQLite B-trees
  Future<void> vacuumDatabase() async {
    try {
      await AppDatabase.instance.rawQuery('VACUUM;');
      debugPrint('[DatabaseBackupService] VACUUM completed successfully.');
    } catch (e) {
      debugPrint('[DatabaseBackupService] VACUUM error: $e');
    }
  }

  /// Exports a standalone backup copy of groclyra.db into Application Documents Directory
  Future<File?> createBackupCopy() async {
    try {
      final sourcePath = await getDatabasePath();
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('[DatabaseBackupService] Source database does not exist on disk.');
        return null;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupPath = p.join(docsDir.path, 'groclyra_backup_$timestamp.db');
      final backupFile = await sourceFile.copy(backupPath);
      debugPrint('[DatabaseBackupService] Backup created: $backupPath (${await backupFile.length()} bytes)');
      return backupFile;
    } catch (e) {
      debugPrint('[DatabaseBackupService] Backup creation failed: $e');
      return null;
    }
  }

  /// Restores groclyra.db from an existing valid SQLite backup file
  Future<bool> restoreFromBackup(File backupFile) async {
    try {
      if (!await backupFile.exists()) return false;
      final targetPath = await getDatabasePath();
      await backupFile.copy(targetPath);
      await AppDatabase.instance.init();
      debugPrint('[DatabaseBackupService] Successfully restored database from: ${backupFile.path}');
      return true;
    } catch (e) {
      debugPrint('[DatabaseBackupService] Database restore failed: $e');
      return false;
    }
  }

  /// Returns row count statistics across all 18 SQL tables
  Future<Map<String, int>> getTableStatistics() async {
    final tables = [
      'users',
      'categories',
      'products',
      'reviews',
      'addresses',
      'orders',
      'order_items',
      'wishlist',
      'seller_profiles',
      'delivery_tasks',
      'rider_profiles',
      'vendor_integrations',
      'notifications',
      'support_messages',
      'notification_preferences',
      'system_telemetry',
      'coupons',
      'schema_migrations',
      'app_preferences',
      'app_secure_vault',
      'cart_cache',
      'app_rate_limits',
      'offline_mutations',
    ];

    final stats = <String, int>{};
    for (final table in tables) {
      try {
        final rows = await AppDatabase.instance.rawQuery('SELECT COUNT(*) as count FROM $table;');
        if (rows.isNotEmpty) {
          final countVal = rows.first['count'];
          stats[table] = countVal is int ? countVal : int.tryParse(countVal.toString()) ?? 0;
        } else {
          stats[table] = 0;
        }
      } catch (_) {
        stats[table] = 0;
      }
    }
    return stats;
  }
}

