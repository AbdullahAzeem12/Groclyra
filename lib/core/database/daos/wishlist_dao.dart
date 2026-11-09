import 'package:sqflite/sqflite.dart' as sql;
import '../tables/database_tables.dart';
import '../realtime/sql_realtime_stream.dart';

/// Groclyra Customer Wishlist DAO
class WishlistDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  WishlistDao(this._getDb, this._streamManager);

  /// Fetch wishlist items for user
  Future<List<Map<String, dynamic>>> getWishlist(String userId) async {
    final db = await _getDb();
    if (db == null) return [];
    return await db.query(
      WishlistTable.tableName,
      where: '${WishlistTable.colUserId} = ?',
      whereArgs: [userId],
      orderBy: '${WishlistTable.colAddedAt} DESC',
    );
  }

  /// Realtime stream of customer wishlist
  Stream<List<Map<String, dynamic>>> watchWishlist(String userId) {
    return _streamManager.createRealtimeQuery(
      watchTables: [WishlistTable.tableName],
      query: () => getWishlist(userId),
    );
  }

  /// Add item to wishlist
  Future<void> addToWishlist(Map<String, dynamic> itemRow) async {
    final db = await _getDb();
    if (db == null) return;
    await db.insert(
      WishlistTable.tableName,
      itemRow,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    _streamManager.notifyTable(WishlistTable.tableName);
  }

  /// Remove item from wishlist
  Future<void> removeFromWishlist(String userId, String productId) async {
    final db = await _getDb();
    if (db == null) return;
    await db.delete(
      WishlistTable.tableName,
      where: '${WishlistTable.colUserId} = ? AND ${WishlistTable.colProductId} = ?',
      whereArgs: [userId, productId],
    );
    _streamManager.notifyTable(WishlistTable.tableName);
  }
}

