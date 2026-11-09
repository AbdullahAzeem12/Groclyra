import 'package:sqflite/sqflite.dart' as sql;
import '../tables/database_tables.dart';
import '../realtime/sql_realtime_stream.dart';

/// Groclyra Order & Checkout DAO
/// Executes relational SQL transactions for orders and line items.
class OrderDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  OrderDao(this._getDb, this._streamManager);

  /// Fetch orders for a user ordered by newest first
  Future<List<Map<String, dynamic>>> getOrdersForUser(String userId) async {
    final db = await _getDb();
    if (db == null) return [];
    return await db.query(
      OrdersTable.tableName,
      where: '${OrdersTable.colUserId} = ?',
      whereArgs: [userId],
      orderBy: '${OrdersTable.colCreatedAt} DESC',
    );
  }

  /// Realtime stream of customer orders
  Stream<List<Map<String, dynamic>>> watchOrdersForUser(String userId) {
    return _streamManager.createRealtimeQuery(
      watchTables: [OrdersTable.tableName],
      query: () => getOrdersForUser(userId),
    );
  }

  /// Fetch order items for a specific order
  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final db = await _getDb();
    if (db == null) return [];
    return await db.query(
      OrderItemsTable.tableName,
      where: '${OrderItemsTable.colOrderId} = ?',
      whereArgs: [orderId],
    );
  }

  /// Atomic SQL Transaction: Insert Order, Line Items and Express Delivery Task
  Future<void> createOrderTransaction({
    required Map<String, dynamic> orderRow,
    required List<Map<String, dynamic>> itemRows,
    Map<String, dynamic>? deliveryTaskRow,
  }) async {
    final db = await _getDb();
    if (db == null) return;

    await db.transaction((txn) async {
      // 1. Insert Order Master
      await txn.insert(
        OrdersTable.tableName,
        orderRow,
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );

      // 2. Insert Line Items
      for (final item in itemRows) {
        await txn.insert(
          OrderItemsTable.tableName,
          item,
          conflictAlgorithm: sql.ConflictAlgorithm.replace,
        );
      }

      // 3. Insert Delivery Task if provided
      if (deliveryTaskRow != null) {
        await txn.insert(
          DeliveryTasksTable.tableName,
          deliveryTaskRow,
          conflictAlgorithm: sql.ConflictAlgorithm.replace,
        );
      }
    });

    _streamManager.notifyTable(OrdersTable.tableName);
    _streamManager.notifyTable(OrderItemsTable.tableName);
    if (deliveryTaskRow != null) {
      _streamManager.notifyTable(DeliveryTasksTable.tableName);
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    final db = await _getDb();
    if (db == null) return;
    await db.update(
      OrdersTable.tableName,
      {
        OrdersTable.colStatus: status,
        OrdersTable.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${OrdersTable.colId} = ?',
      whereArgs: [orderId],
    );
    _streamManager.notifyTable(OrdersTable.tableName);
  }
}

