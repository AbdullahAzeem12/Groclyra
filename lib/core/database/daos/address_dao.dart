import 'package:sqflite/sqflite.dart' as sql;
import '../tables/database_tables.dart';
import '../realtime/sql_realtime_stream.dart';

/// Groclyra Delivery Address DAO
/// Executes SQL queries and transactions for delivery addresses and geocoding.
class AddressDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  AddressDao(this._getDb, this._streamManager);

  /// Fetch addresses for user sorted by isDefault DESC, createdAt DESC
  Future<List<Map<String, dynamic>>> getAddresses(String userId) async {
    final db = await _getDb();
    if (db == null) return [];
    return await db.query(
      AddressesTable.tableName,
      where: '${AddressesTable.colUserId} = ?',
      whereArgs: [userId],
      orderBy: '${AddressesTable.colIsDefault} DESC, ${AddressesTable.colCreatedAt} DESC',
    );
  }

  /// Realtime stream of addresses
  Stream<List<Map<String, dynamic>>> watchAddresses(String userId) {
    return _streamManager.createRealtimeQuery(
      watchTables: [AddressesTable.tableName],
      query: () => getAddresses(userId),
    );
  }

  /// Atomic SQL Save Address: If marked default, resets all other addresses for user
  Future<void> saveAddress({
    required Map<String, dynamic> addressRow,
    required bool isDefault,
    required String userId,
  }) async {
    final db = await _getDb();
    if (db == null) return;

    await db.transaction((txn) async {
      if (isDefault) {
        await txn.update(
          AddressesTable.tableName,
          {AddressesTable.colIsDefault: 0},
          where: '${AddressesTable.colUserId} = ?',
          whereArgs: [userId],
        );
      }

      await txn.insert(
        AddressesTable.tableName,
        addressRow,
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );

      // If default, also update deliveryAddress on users table
      if (isDefault) {
        final formatted = addressRow[AddressesTable.colFormattedAddress];
        final city = addressRow[AddressesTable.colCity];
        if (formatted != null && city != null) {
          await txn.update(
            UsersTable.tableName,
            {
              UsersTable.colDeliveryAddress: formatted,
              UsersTable.colDeliveryZone: city,
              UsersTable.colUpdatedAt: DateTime.now().toIso8601String(),
            },
            where: '${UsersTable.colId} = ?',
            whereArgs: [userId],
          );
        }
      }
    });

    _streamManager.notifyTable(AddressesTable.tableName);
    if (isDefault) {
      _streamManager.notifyTable(UsersTable.tableName);
    }
  }

  /// Set default address
  Future<void> setDefaultAddress(String userId, String addressId) async {
    final db = await _getDb();
    if (db == null) return;

    await db.transaction((txn) async {
      await txn.update(
        AddressesTable.tableName,
        {AddressesTable.colIsDefault: 0},
        where: '${AddressesTable.colUserId} = ?',
        whereArgs: [userId],
      );

      await txn.update(
        AddressesTable.tableName,
        {AddressesTable.colIsDefault: 1},
        where: '${AddressesTable.colId} = ? AND ${AddressesTable.colUserId} = ?',
        whereArgs: [addressId, userId],
      );

      // Lookup address to sync to users table
      final results = await txn.query(
        AddressesTable.tableName,
        where: '${AddressesTable.colId} = ?',
        whereArgs: [addressId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final formatted = results.first[AddressesTable.colFormattedAddress];
        final city = results.first[AddressesTable.colCity];
        await txn.update(
          UsersTable.tableName,
          {
            UsersTable.colDeliveryAddress: formatted,
            UsersTable.colDeliveryZone: city,
            UsersTable.colUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '${UsersTable.colId} = ?',
          whereArgs: [userId],
        );
      }
    });

    _streamManager.notifyTable(AddressesTable.tableName);
    _streamManager.notifyTable(UsersTable.tableName);
  }

  /// Delete address
  Future<void> deleteAddress(String userId, String addressId) async {
    final db = await _getDb();
    if (db == null) return;
    await db.delete(
      AddressesTable.tableName,
      where: '${AddressesTable.colId} = ? AND ${AddressesTable.colUserId} = ?',
      whereArgs: [addressId, userId],
    );
    _streamManager.notifyTable(AddressesTable.tableName);
  }
}

