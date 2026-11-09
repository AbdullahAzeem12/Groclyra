import 'package:sqflite/sqflite.dart' as sql;
import '../tables/database_tables.dart';
import '../realtime/sql_realtime_stream.dart';

/// Groclyra Rider Delivery Tasks DAO
class DeliveryDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  DeliveryDao(this._getDb, this._streamManager);

  /// Fetch tasks for a rider
  Future<List<Map<String, dynamic>>> getTasksForRider(String riderId) async {
    final db = await _getDb();
    if (db == null) return [];
    return await db.query(
      DeliveryTasksTable.tableName,
      where: '${DeliveryTasksTable.colRiderId} = ?',
      whereArgs: [riderId],
      orderBy: '${DeliveryTasksTable.colCreatedAt} DESC',
    );
  }

  /// Realtime stream of rider delivery tasks
  Stream<List<Map<String, dynamic>>> watchTasksForRider(String riderId) {
    return _streamManager.createRealtimeQuery(
      watchTables: [DeliveryTasksTable.tableName],
      query: () => getTasksForRider(riderId),
    );
  }

  /// Get pending unassigned tasks in a city
  Future<List<Map<String, dynamic>>> getPendingTasks() async {
    final db = await _getDb();
    if (db == null) return [];
    return await db.query(
      DeliveryTasksTable.tableName,
      where: '${DeliveryTasksTable.colStatus} = ?',
      whereArgs: ['pending'],
      orderBy: '${DeliveryTasksTable.colCreatedAt} ASC',
    );
  }

  /// Accept delivery task
  Future<void> acceptTask(String taskId, String riderId) async {
    final db = await _getDb();
    if (db == null) return;
    await db.update(
      DeliveryTasksTable.tableName,
      {
        DeliveryTasksTable.colRiderId: riderId,
        DeliveryTasksTable.colStatus: 'assigned',
        DeliveryTasksTable.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DeliveryTasksTable.colId} = ?',
      whereArgs: [taskId],
    );
    _streamManager.notifyTable(DeliveryTasksTable.tableName);
  }

  /// Complete task with OTP verification
  Future<bool> completeTaskWithOtp(String taskId, String otp) async {
    final db = await _getDb();
    if (db == null) return false;

    final results = await db.query(
      DeliveryTasksTable.tableName,
      where: '${DeliveryTasksTable.colId} = ?',
      whereArgs: [taskId],
      limit: 1,
    );

    if (results.isEmpty) return false;
    final expectedOtp = results.first[DeliveryTasksTable.colDeliveryOtp]?.toString();
    if (expectedOtp != null && expectedOtp.trim() == otp.trim()) {
      await db.update(
        DeliveryTasksTable.tableName,
        {
          DeliveryTasksTable.colStatus: 'delivered',
          DeliveryTasksTable.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DeliveryTasksTable.colId} = ?',
        whereArgs: [taskId],
      );
      _streamManager.notifyTable(DeliveryTasksTable.tableName);
      return true;
    }
    return false;
  }
}

