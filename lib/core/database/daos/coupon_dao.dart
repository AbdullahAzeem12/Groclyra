import 'package:sqflite/sqflite.dart' as sql;
import '../realtime/sql_realtime_stream.dart';

/// Groclyra Coupon & Promo Code DAO
class CouponDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  CouponDao(this._getDb, this._streamManager);

  /// Fetch all active coupons
  Future<List<Map<String, dynamic>>> getActiveCoupons() async {
    final db = await _getDb();
    if (db == null) return [];
    return await db.query(
      'coupons',
      where: 'isActive = 1',
      orderBy: 'discountPercentage DESC',
    );
  }

  /// Realtime stream of active promotional coupons
  Stream<List<Map<String, dynamic>>> watchActiveCoupons() {
    return _streamManager.createRealtimeQuery(
      watchTables: ['coupons'],
      query: getActiveCoupons,
    );
  }

  /// Validate coupon code and check minimum order amount
  Future<Map<String, dynamic>?> validateCoupon(String code, double orderSubtotal) async {
    final db = await _getDb();
    if (db == null) return null;
    final results = await db.query(
      'coupons',
      where: 'code = ? AND isActive = 1',
      whereArgs: [code.trim().toUpperCase()],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final coupon = results.first;
    final minAmount = (coupon['minOrderAmount'] as num?)?.toDouble() ?? 0.0;
    if (orderSubtotal < minAmount) {
      return null; // Does not meet minimum order threshold
    }
    return coupon;
  }

  /// Increment coupon usage count
  Future<void> recordCouponUse(String code) async {
    final db = await _getDb();
    if (db == null) return;
    await db.rawUpdate('''
      UPDATE coupons
      SET usageCount = usageCount + 1
      WHERE code = ?
    ''', [code.trim().toUpperCase()]);
    _streamManager.notifyTable('coupons');
  }
}

