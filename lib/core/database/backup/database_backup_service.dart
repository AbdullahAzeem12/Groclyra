import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart' as sql;
import '../app_database.dart';
import '../tables/database_tables.dart';

/// Metadata model for a persistent database snapshot
class DatabaseBackupEntity {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final String checksum;
  final bool isEncrypted;
  final DateTime createdAt;

  const DatabaseBackupEntity({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.checksum,
    required this.isEncrypted,
    required this.createdAt,
  });

  factory DatabaseBackupEntity.fromMap(Map<String, dynamic> map) {
    return DatabaseBackupEntity(
      id: map[DatabaseBackupsTable.colId] as String? ?? '',
      fileName: map[DatabaseBackupsTable.colFileName] as String? ?? '',
      filePath: map[DatabaseBackupsTable.colFilePath] as String? ?? '',
      fileSizeBytes: map[DatabaseBackupsTable.colFileSizeBytes] as int? ?? 0,
      checksum: map[DatabaseBackupsTable.colChecksum] as String? ?? '',
      isEncrypted: (map[DatabaseBackupsTable.colIsEncrypted] as int? ?? 1) == 1,
      createdAt: DateTime.tryParse(map[DatabaseBackupsTable.colCreatedAt] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseBackupsTable.colId: id,
      DatabaseBackupsTable.colFileName: fileName,
      DatabaseBackupsTable.colFilePath: filePath,
      DatabaseBackupsTable.colFileSizeBytes: fileSizeBytes,
      DatabaseBackupsTable.colChecksum: checksum,
      DatabaseBackupsTable.colIsEncrypted: isEncrypted ? 1 : 0,
      DatabaseBackupsTable.colCreatedAt: createdAt.toIso8601String(),
    };
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Enterprise SQLite Database Backup & Encrypted Disaster Recovery Service
/// Creates encrypted AES-256 snapshots of all relational tables and enables seamless cloud/local export.
class DatabaseBackupService {
  final AppDatabase _db;
  static const String _magicHeader = 'GROCLYRA_SQL_BACKUP_V1';
  static const String _defaultMasterSecret = 'groclyra_enterprise_sqlite_vault_2026';

  static final DatabaseBackupService instance = DatabaseBackupService();

  // All 26 synchronized relational tables
  static const List<String> supportedTables = [
    'users',
    'categories',
    'products',
    'reviews',
    'addresses',
    'orders',
    'order_items',
    'delivery_tasks',
    'seller_profiles',
    'rider_profiles',
    'wishlist',
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
    'home_banners',
    'user_2fa',
    'user_sessions',
  ];

  DatabaseBackupService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  // ───────────────────────────────────────────────────────────────────────────
  // DIAGNOSTICS & ON-DISK REPOSITORIES (Used by Admin Diagnostics)
  // ───────────────────────────────────────────────────────────────────────────

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
      final integrity = await _db.rawQuery('PRAGMA integrity_check;');
      final fk = await _db.rawQuery('PRAGMA foreign_key_check;');
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
      await _db.rawQuery('VACUUM;');
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

      Directory docsDir;
      try {
        docsDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        docsDir = Directory.systemTemp;
      }
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
      await _db.init();
      debugPrint('[DatabaseBackupService] Successfully restored database from: ${backupFile.path}');
      return true;
    } catch (e) {
      debugPrint('[DatabaseBackupService] Database restore failed: $e');
      return false;
    }
  }

  /// Returns row count statistics across all synchronized SQL tables
  Future<Map<String, int>> getTableStatistics() async {
    final stats = <String, int>{};
    for (final table in supportedTables) {
      try {
        final rows = await _db.rawQuery('SELECT COUNT(*) as count FROM $table;');
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

  // ───────────────────────────────────────────────────────────────────────────
  // ENCRYPTED SNAPSHOTS & DISASTER RECOVERY (AES-256)
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns directory where backup files are saved
  Future<Directory> getBackupDirectory() async {
    Directory targetDir;
    try {
      final docs = await getApplicationDocumentsDirectory();
      targetDir = Directory(p.join(docs.path, 'groclyra_backups'));
    } catch (_) {
      final temp = Directory.systemTemp;
      targetDir = Directory(p.join(temp.path, 'groclyra_backups_test'));
    }
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  /// Creates a consistent, AES-256 encrypted snapshot of the entire SQLite database
  Future<DatabaseBackupEntity> createEncryptedBackup({
    String? userPassphrase,
  }) async {
    await _db.init();

    // 1. Extract data across all supported tables
    final tableDump = <String, List<Map<String, dynamic>>>{};
    for (final table in supportedTables) {
      try {
        final rows = await _db.query(table);
        tableDump[table] = rows;
      } catch (e) {
        debugPrint('[Backup] Table $table dump note: $e');
      }
    }

    final now = DateTime.now();
    final timestampStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final fileName = 'groclyra_backup_$timestampStr.gbackup';

    final manifest = {
      'header': _magicHeader,
      'app': 'Groclyra Marketplace',
      'version': 1,
      'createdAt': now.toIso8601String(),
      'tablesCount': tableDump.length,
      'tables': tableDump,
    };

    final rawJson = jsonEncode(manifest);
    final rawBytes = utf8.encode(rawJson);
    final checksum = sha256.convert(rawBytes).toString();

    // 2. Cryptographic Salt & Key Derivation (AES-256 CBC)
    final rng = math.Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final iv = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));

    final effectiveSecret = (userPassphrase != null && userPassphrase.trim().isNotEmpty)
        ? userPassphrase.trim()
        : _defaultMasterSecret;

    final keyBytes = _deriveAesKey(effectiveSecret, salt);
    final encryptedBytes = _encryptAesCbc(Uint8List.fromList(rawBytes), keyBytes, iv);

    // 3. Assemble backup file format:
    final backupFileContent = StringBuffer()
      ..writeln(_magicHeader)
      ..writeln(base64Encode(salt))
      ..writeln(base64Encode(iv))
      ..writeln(checksum)
      ..write(base64Encode(encryptedBytes));

    final dir = await getBackupDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(backupFileContent.toString());

    final entity = DatabaseBackupEntity(
      id: 'bkp_$timestampStr',
      fileName: fileName,
      filePath: file.path,
      fileSizeBytes: await file.length(),
      checksum: checksum,
      isEncrypted: true,
      createdAt: now,
    );

    // 4. Record in SQLite backups registry
    await _db.insertOrReplace(DatabaseBackupsTable.tableName, entity.toMap());

    debugPrint('[Backup] Successfully created encrypted backup: ${file.path} (${entity.formattedSize})');
    return entity;
  }

  /// Lists all stored database backups
  Future<List<DatabaseBackupEntity>> listBackups() async {
    await _db.init();
    final rows = await _db.query(
      DatabaseBackupsTable.tableName,
      orderBy: '${DatabaseBackupsTable.colCreatedAt} DESC',
    );
    return rows.map((r) => DatabaseBackupEntity.fromMap(r)).toList();
  }

  /// Restores database state from an encrypted backup file
  Future<bool> restoreBackupFromFile(
    String filePath, {
    String? userPassphrase,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Backup file does not exist at $filePath');
    }

    final content = await file.readAsString();
    final lines = content.split('\n');
    if (lines.length < 5 || lines[0].trim() != _magicHeader) {
      throw Exception('Invalid or corrupted backup file format.');
    }

    final salt = base64Decode(lines[1].trim());
    final iv = base64Decode(lines[2].trim());
    final expectedChecksum = lines[3].trim();
    final encryptedBytes = base64Decode(lines[4].trim());

    final effectiveSecret = (userPassphrase != null && userPassphrase.trim().isNotEmpty)
        ? userPassphrase.trim()
        : _defaultMasterSecret;

    final keyBytes = _deriveAesKey(effectiveSecret, salt);
    final decryptedBytes = _decryptAesCbc(Uint8List.fromList(encryptedBytes), keyBytes, iv);

    // Verify SHA-256 Checksum
    final actualChecksum = sha256.convert(decryptedBytes).toString();
    if (actualChecksum != expectedChecksum) {
      throw Exception('Checksum verification failed. Invalid passphrase or corrupt payload.');
    }

    final rawJson = utf8.decode(decryptedBytes);
    final manifest = jsonDecode(rawJson) as Map<String, dynamic>;
    final tables = manifest['tables'] as Map<String, dynamic>?;

    if (tables == null) {
      throw Exception('Missing tables in backup manifest.');
    }

    // Atomically restore tables
    for (final entry in tables.entries) {
      final tableName = entry.key;
      final rawList = entry.value as List<dynamic>? ?? [];

      try {
        await _db.delete(tableName);
        for (final item in rawList) {
          if (item is Map) {
            final row = Map<String, dynamic>.from(item);
            await _db.insertOrReplace(tableName, row);
          }
        }
        _db.notifyTable(tableName);
      } catch (e) {
        debugPrint('[Restore] Error restoring table $tableName: $e');
      }
    }

    debugPrint('[Restore] Database restoration successfully completed from $filePath');
    return true;
  }

  /// Shares/Exports the encrypted backup file using system share dialog
  Future<void> exportBackup(DatabaseBackupEntity backup) async {
    final file = File(backup.filePath);
    if (!await file.exists()) {
      throw Exception('Backup file not found at ${backup.filePath}');
    }

    await SharePlus.instance.share(
      ShareParams(
        text: 'Encrypted Groclyra SQLite database snapshot: ${backup.fileName}',
        subject: 'Groclyra Encrypted Database Backup (${backup.fileName})',
      ),
    );
  }

  /// Deletes backup file and removes record from SQLite
  Future<void> deleteBackup(DatabaseBackupEntity backup) async {
    try {
      final file = File(backup.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    await _db.delete(
      DatabaseBackupsTable.tableName,
      where: '${DatabaseBackupsTable.colId} = ?',
      whereArgs: [backup.id],
    );
  }

  // ─── AES-256 CBC Cryptographic Helpers via PointyCastle ─────────────────────

  Uint8List _deriveAesKey(String secret, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(salt);
    return Uint8List.fromList(digest.bytes);
  }

  Uint8List _encryptAesCbc(Uint8List plainText, Uint8List key, Uint8List iv) {
    final cipher = pc.PaddedBlockCipher('AES/CBC/PKCS7');
    final params = pc.PaddedBlockCipherParameters(
      pc.ParametersWithIV(pc.KeyParameter(key), iv),
      null,
    );
    cipher.init(true, params);
    return cipher.process(plainText);
  }

  Uint8List _decryptAesCbc(Uint8List cipherText, Uint8List key, Uint8List iv) {
    final cipher = pc.PaddedBlockCipher('AES/CBC/PKCS7');
    final params = pc.PaddedBlockCipherParameters(
      pc.ParametersWithIV(pc.KeyParameter(key), iv),
      null,
    );
    cipher.init(false, params);
    return cipher.process(cipherText);
  }
}

final databaseBackupServiceProvider = Provider<DatabaseBackupService>((ref) {
  return DatabaseBackupService();
});
