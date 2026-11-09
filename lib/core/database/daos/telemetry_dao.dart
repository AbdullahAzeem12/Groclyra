import 'package:sqflite/sqflite.dart' as sql;
import '../tables/database_tables.dart';
import '../realtime/sql_realtime_stream.dart';

/// Groclyra System Telemetry & Notification Preferences DAO
class TelemetryDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  TelemetryDao(this._getDb, this._streamManager);

  /// Get telemetry value by key
  Future<String?> getTelemetry(String key) async {
    final db = await _getDb();
    if (db == null) return null;
    final results = await db.query(
      SystemTelemetryTable.tableName,
      where: '${SystemTelemetryTable.colKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    return results.isNotEmpty ? results.first[SystemTelemetryTable.colValue]?.toString() : null;
  }

  /// Upsert telemetry value
  Future<void> setTelemetry(String key, String value) async {
    final db = await _getDb();
    if (db == null) return;
    await db.insert(
      SystemTelemetryTable.tableName,
      {
        SystemTelemetryTable.colKey: key,
        SystemTelemetryTable.colValue: value,
        SystemTelemetryTable.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    _streamManager.notifyTable(SystemTelemetryTable.tableName);
  }

  /// Get notification preferences
  Future<Map<String, dynamic>?> getNotificationPreferences(String userId) async {
    final db = await _getDb();
    if (db == null) return null;
    final results = await db.query(
      NotificationPreferencesTable.tableName,
      where: '${NotificationPreferencesTable.colUserId} = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Upsert notification preferences
  Future<void> setNotificationPreferences(Map<String, dynamic> row) async {
    final db = await _getDb();
    if (db == null) return;
    await db.insert(
      NotificationPreferencesTable.tableName,
      row,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    _streamManager.notifyTable(NotificationPreferencesTable.tableName);
  }
}

