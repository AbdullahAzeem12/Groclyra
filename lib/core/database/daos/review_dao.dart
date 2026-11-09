import 'package:sqflite/sqflite.dart' as sql;
import '../tables/database_tables.dart';
import '../realtime/sql_realtime_stream.dart';

/// Groclyra Reviews DAO
class ReviewDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  ReviewDao(this._getDb, this._streamManager);

  /// Get reviews for a product
  Future<List<Map<String, dynamic>>> getReviews(String productId) async {
    final db = await _getDb();
    if (db == null) return [];
    return await db.query(
      ReviewsTable.tableName,
      where: '${ReviewsTable.colProductId} = ?',
      whereArgs: [productId],
      orderBy: '${ReviewsTable.colCreatedAt} DESC',
    );
  }

  /// Realtime stream of product reviews
  Stream<List<Map<String, dynamic>>> watchReviews(String productId) {
    return _streamManager.createRealtimeQuery(
      watchTables: [ReviewsTable.tableName],
      query: () => getReviews(productId),
    );
  }

  /// Add review
  Future<void> insertReview(Map<String, dynamic> reviewRow) async {
    final db = await _getDb();
    if (db == null) return;
    await db.insert(
      ReviewsTable.tableName,
      reviewRow,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    _streamManager.notifyTable(ReviewsTable.tableName);
  }
}

