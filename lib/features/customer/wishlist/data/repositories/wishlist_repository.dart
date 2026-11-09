import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/customer/wishlist/domain/entities/wishlist_item_entity.dart';

/// Groclyra SQL-backed WishlistRepository (SQLite).
class WishlistRepository {
  final AppDatabase _database;
  final List<WishlistItemEntity> _memoryCache = [];

  WishlistRepository({
    dynamic firestore, // Kept dynamic for legacy test compatibility
    AppDatabase? database,
  })  : _database = database ?? AppDatabase.instance {
    _seedDefaultItemsIfEmpty();
  }

  void _seedDefaultItemsIfEmpty() {
    if (_memoryCache.isEmpty) {
      _memoryCache.addAll([
        WishlistItemEntity(
          id: 'wish_crock_dinner_set',
          userId: 'usr_guest',
          productId: 'prod_crock_01',
          title: 'Royal Bone China 24-Piece Dinner Set',
          categoryType: MainCategoryType.crockery,
          categoryName: 'Dinner Sets',
          brand: 'Groclyra Luxury Tableware',
          imageUrl: 'https://images.unsplash.com/photo-1614735241165-6756e1df61ab?w=400',
          savedPrice: 14500.0,
          currentPrice: 13999.0,
          compareAtPrice: 16500.0,
          inStock: true,
          stockCount: 8,
          selectedVariantName: '24 pcs / Gold Rim',
          collectionName: 'Dinner Sets',
          savedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        WishlistItemEntity(
          id: 'wish_groc_basmati_rice',
          userId: 'usr_guest',
          productId: 'prod_groc_01',
          title: 'Pure Himalayan Extra Long Basmati Rice (5kg)',
          categoryType: MainCategoryType.grocery,
          categoryName: 'Pantry & Grains',
          brand: 'Groclyra Organics',
          imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400',
          savedPrice: 1850.0,
          currentPrice: 1850.0,
          compareAtPrice: 2100.0,
          inStock: true,
          stockCount: 45,
          selectedVariantName: '5kg Pack',
          collectionName: 'Daily Groceries',
          savedAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        WishlistItemEntity(
          id: 'wish_crock_tea_set',
          userId: 'usr_guest',
          productId: 'prod_crock_02',
          title: 'Handcrafted Ceramic Tea Set (6 Cups & Pot)',
          categoryType: MainCategoryType.crockery,
          categoryName: 'Tea & Coffee Sets',
          brand: 'Artisan Pottery PK',
          imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=400',
          savedPrice: 4200.0,
          currentPrice: 3850.0,
          compareAtPrice: 4800.0,
          inStock: true,
          stockCount: 12,
          selectedVariantName: 'Emerald Green',
          collectionName: 'Kitchen Essentials',
          savedAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ]);
    }
  }

  /// Real-time stream of all wishlist items for this user from SQLite.
  Stream<List<WishlistItemEntity>> streamWishlist(String userId) async* {
    yield await getWishlist(userId: userId);

    yield* _database.watchTable('wishlist').asyncMap((_) async {
      return await getWishlist(userId: userId);
    });
  }

  Future<void> addItem(WishlistItemEntity item) async {
    _memoryCache.removeWhere((w) => w.id == item.id || w.productId == item.productId);
    _memoryCache.insert(0, item);

    try {
      final row = <String, dynamic>{
        'id': item.id,
        'userId': item.userId,
        'productId': item.productId,
        'title': item.title,
        'brand': item.brand,
        'imageUrl': item.imageUrl,
        'savedPrice': item.savedPrice,
        'currentPrice': item.currentPrice,
        'collectionName': item.collectionName,
        'savedAt': item.savedAt.toIso8601String(),
        'fullDataJson': jsonEncode(item.toMap()),
      };
      await _database.insertOrReplace('wishlist', row);
      _database.notifyTable('wishlist');
    } catch (e) {
      debugPrint('WishlistRepository.addItem error: $e');
    }
  }

  Future<void> removeItem(String userId, String itemId) async {
    _memoryCache.removeWhere((w) => w.id == itemId || (w.userId == userId && w.productId == itemId));

    try {
      await _database.delete(
        'wishlist',
        where: 'id = ? OR (userId = ? AND productId = ?)',
        whereArgs: [itemId, userId, itemId],
      );
      _database.notifyTable('wishlist');
    } catch (e) {
      debugPrint('WishlistRepository.removeItem error: $e');
    }
  }

  Future<List<WishlistItemEntity>> getWishlist({required String userId}) async {
    if (userId.isEmpty || userId == 'usr_guest') {
      return List.unmodifiable(_memoryCache);
    }

    try {
      final rows = await _database.query(
        'wishlist',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'savedAt DESC',
      );

      if (rows.isEmpty) {
        return List.unmodifiable(_memoryCache);
      }

      final list = rows.map((r) {
        final full = r['fullDataJson'] as String?;
        if (full != null && full.isNotEmpty) {
          try {
            return WishlistItemEntity.fromMap(jsonDecode(full) as Map<String, dynamic>, r['id'] as String);
          } catch (_) {}
        }
        return WishlistItemEntity.fromMap(r, r['id'] as String);
      }).toList();

      _memoryCache.clear();
      _memoryCache.addAll(list);
      return List.unmodifiable(list);
    } catch (e) {
      debugPrint('WishlistRepository.getWishlist error: $e');
      return List.unmodifiable(_memoryCache);
    }
  }

  Future<void> addToWishlist(WishlistItemEntity item) => addItem(item);

  Future<void> removeFromWishlist({required String userId, required String itemId}) =>
      removeItem(userId, itemId);

  bool isProductWishlisted(String productId) {
    return _memoryCache.any((w) => w.productId == productId);
  }
}

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository();
});
