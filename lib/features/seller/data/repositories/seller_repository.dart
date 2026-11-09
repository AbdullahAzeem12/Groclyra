import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/seller_store_entity.dart';
import '../../../catalog/domain/entities/product_entity.dart';
import '../../../catalog/data/repositories/catalog_repository.dart';

/// SQL-backed SellerRepository (SQLite).
class SellerRepository {
  final AppDatabase _database;
  final CatalogRepository _catalogRepository;

  SellerRepository({
    dynamic firestore, // Kept dynamic for legacy test compatibility
    required CatalogRepository catalogRepository,
    AppDatabase? database,
  })  : _database = database ?? AppDatabase.instance,
        _catalogRepository = catalogRepository;

  // ──────────────────────────────────────────────────────────────
  // STORE PROFILE
  // ──────────────────────────────────────────────────────────────

  /// Fetches the seller's store profile by their UID (= sellerId) from SQLite.
  Future<SellerStoreEntity> getStoreProfile(String sellerId) async {
    try {
      final rows = await _database.query(
        'seller_profiles',
        where: 'sellerId = ?',
        whereArgs: [sellerId],
        limit: 1,
      );

      final userRows = await _database.query(
        'users',
        where: 'id = ?',
        whereArgs: [sellerId],
        limit: 1,
      );

      final mergedData = <String, dynamic>{};
      if (userRows.isNotEmpty) {
        mergedData.addAll(userRows.first);
      }
      if (rows.isNotEmpty) {
        mergedData.addAll(rows.first);
      }

      if (mergedData.isNotEmpty) {
        return _storeFromDoc(sellerId, mergedData);
      }

      return SellerStoreEntity(
        id: sellerId,
        sellerId: sellerId,
        storeName: 'My Store',
        rating: 4.5,
        totalProducts: 0,
        totalOrders: 0,
        todayRevenue: 0,
        totalRevenue: 0,
        pendingPayout: 0,
        lowStockCount: 0,
        isKycApproved: false,
      );
    } catch (e) {
      debugPrint('SellerRepository.getStoreProfile error: $e');
      return SellerStoreEntity(
        id: sellerId,
        sellerId: sellerId,
        storeName: 'My Store',
        rating: 4.5,
        totalProducts: 0,
        totalOrders: 0,
        todayRevenue: 0,
        totalRevenue: 0,
        pendingPayout: 0,
        lowStockCount: 0,
        isKycApproved: false,
      );
    }
  }

  /// Real-time stream of the seller's store profile from SQLite.
  Stream<SellerStoreEntity?> streamStoreProfile(String sellerId) async* {
    yield await getStoreProfile(sellerId);

    final controller = StreamController<SellerStoreEntity?>();

    final sub1 = _database.watchTable('seller_profiles').listen((_) async {
      if (!controller.isClosed) controller.add(await getStoreProfile(sellerId));
    });
    final sub2 = _database.watchTable('users').listen((_) async {
      if (!controller.isClosed) controller.add(await getStoreProfile(sellerId));
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    yield* controller.stream;
  }

  // ──────────────────────────────────────────────────────────────
  // SELLER ORDERS — aggregate stats
  // ──────────────────────────────────────────────────────────────

  /// Stream of seller order stats (revenue, order count) derived from SQLite.
  Stream<Map<String, dynamic>> streamSellerStats(String sellerId) async* {
    yield await _computeSellerStats(sellerId);

    yield* _database.watchTable('orders').asyncMap((_) async {
      return await _computeSellerStats(sellerId);
    });
  }

  Future<Map<String, dynamic>> _computeSellerStats(String sellerId) async {
    try {
      final rows = await _database.query(
        'orders',
        where: 'sellerIds LIKE ?',
        whereArgs: ['%$sellerId%'],
      );

      double todayRevenue = 0;
      double totalRevenue = 0;
      int totalOrders = rows.length;
      final today = DateTime.now();

      for (final row in rows) {
        final amount = (row['totalAmount'] as num?)?.toDouble() ?? 0;
        totalRevenue += amount;
        final createdStr = row['createdAt']?.toString();
        if (createdStr != null) {
          final dt = DateTime.tryParse(createdStr);
          if (dt != null &&
              dt.year == today.year &&
              dt.month == today.month &&
              dt.day == today.day) {
            todayRevenue += amount;
          }
        }
      }

      return {
        'totalOrders': totalOrders,
        'totalRevenue': totalRevenue,
        'todayRevenue': todayRevenue,
      };
    } catch (e) {
      debugPrint('SellerRepository.streamSellerStats error: $e');
      return <String, dynamic>{
        'totalOrders': 0,
        'totalRevenue': 0.0,
        'todayRevenue': 0.0,
      };
    }
  }

  // ──────────────────────────────────────────────────────────────
  // PRODUCTS
  // ──────────────────────────────────────────────────────────────

  Future<List<ProductEntity>> getSellerProducts(String sellerId) async {
    return _catalogRepository.getProducts(sellerId: sellerId);
  }

  Stream<List<ProductEntity>> streamSellerProducts(String sellerId) {
    return _catalogRepository.streamProducts(sellerId: sellerId);
  }

  Future<void> addNewProduct(ProductEntity product) async {
    await _catalogRepository.addProduct(product);

    try {
      final rows = await _database.query(
        'seller_profiles',
        where: 'sellerId = ?',
        whereArgs: [product.sellerId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final currentCount = (rows.first['totalProducts'] as num?)?.toInt() ?? 0;
        await _database.update(
          'seller_profiles',
          {
            'totalProducts': currentCount + 1,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'sellerId = ?',
          whereArgs: [product.sellerId],
        );
        _database.notifyTable('seller_profiles');
      }
    } catch (_) {}
  }

  Future<void> updateInventory(String productId, String variantId, int newStock) async {
    await _catalogRepository.updateProductStock(productId, variantId, newStock);
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> updates) async {
    await _catalogRepository.updateProduct(productId, updates);
  }

  // ──────────────────────────────────────────────────────────────
  // SELLER PROFILE UPDATE
  // ──────────────────────────────────────────────────────────────

  Future<void> updateStoreProfile(String sellerId, Map<String, dynamic> updates) async {
    if (sellerId.isEmpty) {
      throw ArgumentError('Seller ID cannot be empty.');
    }
    final now = DateTime.now().toIso8601String();
    final data = Map<String, dynamic>.from(updates);
    data['updatedAt'] = now;

    await _database.insertOrReplace('seller_profiles', {
      'sellerId': sellerId,
      ...data,
    });
    _database.notifyTable('seller_profiles');

    // Sync to users table in SQLite
    final userUpdates = <String, dynamic>{'updatedAt': now};
    if (updates.containsKey('storeName')) {
      userUpdates['storeName'] = updates['storeName'];
    }
    if (updates.containsKey('ownerName') || updates.containsKey('displayName')) {
      final nameVal = updates['ownerName'] ?? updates['displayName'];
      userUpdates['name'] = nameVal;
    }
    if (updates.containsKey('phone')) {
      userUpdates['phone'] = updates['phone'];
    }
    if (updates.containsKey('email')) {
      userUpdates['email'] = updates['email'];
    }
    if (updates.containsKey('businessCategory')) {
      userUpdates['businessCategory'] = updates['businessCategory'];
    }
    if (updates.containsKey('logoUrl')) {
      userUpdates['photoUrl'] = updates['logoUrl'];
    }

    try {
      await _database.update('users', userUpdates, where: 'id = ?', whereArgs: [sellerId]);
      _database.notifyTable('users');
    } catch (e) {
      debugPrint('SellerRepository.updateStoreProfile user sync warning: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // PARSING HELPERS
  // ──────────────────────────────────────────────────────────────

  SellerStoreEntity _storeFromDoc(String sellerId, Map<String, dynamic> data) {
    return SellerStoreEntity(
      id: sellerId,
      sellerId: sellerId,
      storeName: data['storeName'] as String? ??
          data['displayName'] as String? ??
          'My Store',
      ownerName: data['displayName'] as String? ??
          data['name'] as String? ??
          data['ownerName'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String? ?? data['contactPhone'] as String?,
      businessCategory:
          data['businessCategory'] as String? ?? data['category'] as String?,
      storeDescription:
          data['storeDescription'] as String? ?? data['description'] as String?,
      storeAddress:
          data['storeAddress'] as String? ?? data['address'] as String?,
      logoUrl: data['logoUrl'] as String? ??
          data['avatarUrl'] as String? ??
          data['photoUrl'] as String? ??
          data['profileImageBase64'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      totalProducts: (data['totalProducts'] as num?)?.toInt() ?? 0,
      totalOrders: (data['totalOrders'] as num?)?.toInt() ?? 0,
      todayRevenue: (data['todayRevenue'] as num?)?.toDouble() ?? 0,
      totalRevenue: (data['totalRevenue'] as num?)?.toDouble() ?? 0,
      pendingPayout: (data['pendingPayout'] as num?)?.toDouble() ?? 0,
      lowStockCount: (data['lowStockCount'] as num?)?.toInt() ?? 0,
      isKycApproved: (data['isKycApproved'] == 1 || data['isKycApproved'] == true) ||
          (data['accountStatus'] == 'active'),
      accountStatus: data['accountStatus'] as String? ?? 'active',
    );
  }
}

// ──────────────────────────────────────────────────────────────
// PROVIDERS
// ──────────────────────────────────────────────────────────────

final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  final catalogRepo = ref.watch(catalogRepositoryProvider);
  return SellerRepository(catalogRepository: catalogRepo);
});

/// Stream of a seller's store profile by their UID.
final sellerStoreProfileStreamProvider =
    StreamProvider.autoDispose.family<SellerStoreEntity?, String>(
        (ref, sellerId) {
  return ref.watch(sellerRepositoryProvider).streamStoreProfile(sellerId);
});
