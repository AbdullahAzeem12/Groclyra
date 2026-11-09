import 'package:sqflite/sqflite.dart' as sql;
import '../tables/database_tables.dart';
import '../realtime/sql_realtime_stream.dart';

/// Groclyra Catalog DAO (Data Access Object)
/// Executes SQL queries for categories, products, inventory and flash deals.
class CatalogDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  CatalogDao(this._getDb, this._streamManager);

  /// Fetch all active categories ordered by sortOrder
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await _getDb();
    if (db != null) {
      return await db.query(
        CategoriesTable.tableName,
        orderBy: '${CategoriesTable.colSortOrder} ASC',
      );
    }
    return [];
  }

  /// Realtime stream of categories
  Stream<List<Map<String, dynamic>>> watchCategories() {
    return _streamManager.createRealtimeQuery(
      watchTables: [CategoriesTable.tableName],
      query: getCategories,
    );
  }

  /// Query products with flexible SQL filtering
  Future<List<Map<String, dynamic>>> getProducts({
    String? categoryId,
    String? parentCategory,
    bool? isFlashDeal,
    String? vendorId,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final db = await _getDb();
    if (db == null) return [];

    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (categoryId != null && categoryId.isNotEmpty) {
      whereClauses.add('${ProductsTable.colCategoryId} = ?');
      whereArgs.add(categoryId);
    }
    if (parentCategory != null && parentCategory.isNotEmpty) {
      whereClauses.add('${ProductsTable.colParentCategory} = ?');
      whereArgs.add(parentCategory);
    }
    if (isFlashDeal != null) {
      whereClauses.add('${ProductsTable.colIsFlashDeal} = ?');
      whereArgs.add(isFlashDeal ? 1 : 0);
    }
    if (vendorId != null && vendorId.isNotEmpty) {
      whereClauses.add('${ProductsTable.colVendorId} = ?');
      whereArgs.add(vendorId);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      whereClauses.add('(${ProductsTable.colTitle} LIKE ? OR ${ProductsTable.colBrand} LIKE ? OR ${ProductsTable.colSubcategory} LIKE ?)');
      whereArgs.addAll([term, term, term]);
    }

    final whereStr = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    return await db.query(
      ProductsTable.tableName,
      where: whereStr,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '${ProductsTable.colCreatedAt} DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Realtime stream of products
  Stream<List<Map<String, dynamic>>> watchProducts({
    String? categoryId,
    String? parentCategory,
    bool? isFlashDeal,
    String? vendorId,
  }) {
    return _streamManager.createRealtimeQuery(
      watchTables: [ProductsTable.tableName],
      query: () => getProducts(
        categoryId: categoryId,
        parentCategory: parentCategory,
        isFlashDeal: isFlashDeal,
        vendorId: vendorId,
      ),
    );
  }

  /// Get single product by primary key
  Future<Map<String, dynamic>?> getProductById(String id) async {
    final db = await _getDb();
    if (db == null) return null;
    final results = await db.query(
      ProductsTable.tableName,
      where: '${ProductsTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Insert or update product in SQLite
  Future<void> upsertProduct(Map<String, dynamic> productRow) async {
    final db = await _getDb();
    if (db == null) return;
    await db.insert(
      ProductsTable.tableName,
      productRow,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    _streamManager.notifyTable(ProductsTable.tableName);
  }

  /// Atomic SQL Stock adjustment
  Future<void> updateStock(String productId, int quantityDelta) async {
    final db = await _getDb();
    if (db == null) return;
    await db.rawUpdate('''
      UPDATE ${ProductsTable.tableName}
      SET ${ProductsTable.colStockQuantity} = MAX(0, ${ProductsTable.colStockQuantity} + ?),
          ${ProductsTable.colUpdatedAt} = ?
      WHERE ${ProductsTable.colId} = ?
    ''', [quantityDelta, DateTime.now().toIso8601String(), productId]);
    _streamManager.notifyTable(ProductsTable.tableName);
  }
}
