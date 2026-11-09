import 'package:sqflite/sqflite.dart' as sql;
import '../tables/database_tables.dart';
import '../realtime/sql_realtime_stream.dart';

/// Groclyra User, Seller & Rider Profile DAO
class UserDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  UserDao(this._getDb, this._streamManager);

  /// Fetch user by ID
  Future<Map<String, dynamic>?> getUserById(String id) async {
    final db = await _getDb();
    if (db == null) return null;
    final results = await db.query(
      UsersTable.tableName,
      where: '${UsersTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Fetch user by Email (case-insensitive)
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await _getDb();
    if (db == null) return null;
    final results = await db.query(
      UsersTable.tableName,
      where: 'LOWER(${UsersTable.colEmail}) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Fetch user by Phone Number
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    final db = await _getDb();
    if (db == null) return null;
    final results = await db.query(
      UsersTable.tableName,
      where: '${UsersTable.colPhone} = ?',
      whereArgs: [phone.trim()],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Realtime stream of user profile
  Stream<Map<String, dynamic>?> watchUser(String id) {
    return _streamManager.createRealtimeQuery(
      watchTables: [UsersTable.tableName],
      query: () => getUserById(id),
    );
  }

  /// Insert or update user
  Future<void> upsertUser(Map<String, dynamic> userRow) async {
    final db = await _getDb();
    if (db == null) return;
    await db.insert(
      UsersTable.tableName,
      userRow,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    _streamManager.notifyTable(UsersTable.tableName);
  }

  /// Fetch seller profile
  Future<Map<String, dynamic>?> getSellerProfile(String sellerId) async {
    final db = await _getDb();
    if (db == null) return null;
    final results = await db.query(
      SellerProfilesTable.tableName,
      where: '${SellerProfilesTable.colSellerId} = ?',
      whereArgs: [sellerId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Upsert seller profile
  Future<void> upsertSellerProfile(Map<String, dynamic> profileRow) async {
    final db = await _getDb();
    if (db == null) return;
    await db.insert(
      SellerProfilesTable.tableName,
      profileRow,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    _streamManager.notifyTable(SellerProfilesTable.tableName);
  }

  /// Fetch rider profile
  Future<Map<String, dynamic>?> getRiderProfile(String riderId) async {
    final db = await _getDb();
    if (db == null) return null;
    final results = await db.query(
      RiderProfilesTable.tableName,
      where: '${RiderProfilesTable.colRiderId} = ?',
      whereArgs: [riderId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Upsert rider profile
  Future<void> upsertRiderProfile(Map<String, dynamic> riderRow) async {
    final db = await _getDb();
    if (db == null) return;
    await db.insert(
      RiderProfilesTable.tableName,
      riderRow,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    _streamManager.notifyTable(RiderProfilesTable.tableName);
  }
}

