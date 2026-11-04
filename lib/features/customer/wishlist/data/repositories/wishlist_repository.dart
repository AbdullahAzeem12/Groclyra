import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/customer/wishlist/domain/entities/wishlist_item_entity.dart';


class WishlistRepository {
  final FirebaseFirestore? _explicitFirestore;
  final List<WishlistItemEntity> _memoryCache = [];

  WishlistRepository({FirebaseFirestore? firestore})
      : _explicitFirestore = firestore {
    _seedDefaultItemsIfEmpty();
  }

  FirebaseFirestore? get _firestore {
    if (_explicitFirestore != null) return _explicitFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
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

  /// Real-time stream of all wishlist items for this user
  Stream<List<WishlistItemEntity>> streamWishlist(String userId) {
    if (userId.isEmpty) {
      return Stream.value(List.unmodifiable(_memoryCache));
    }

    final fs = _firestore;
    if (fs == null) {
      return Stream.value(List.unmodifiable(_memoryCache));
    }

    try {
      return fs
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .orderBy('savedAt', descending: true)
          .snapshots()
          .map<List<WishlistItemEntity>>((snap) {
        if (snap.docs.isEmpty) {
          return List.unmodifiable(_memoryCache);
        }
        final list = snap.docs
            .map((doc) => WishlistItemEntity.fromMap(doc.data(), doc.id))
            .toList();
        _memoryCache.clear();
        _memoryCache.addAll(list);
        return list;
      });

    } catch (_) {
      return Stream.value(List.unmodifiable(_memoryCache));
    }
  }

  Future<void> addItem(WishlistItemEntity item) async {
    _memoryCache.removeWhere((w) => w.id == item.id || w.productId == item.productId);
    _memoryCache.insert(0, item);

    final fs = _firestore;
    if (item.userId.isNotEmpty && fs != null) {
      try {
        await fs
            .collection('users')
            .doc(item.userId)
            .collection('wishlist')
            .doc(item.id)
            .set(item.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('WishlistRepository.addItem error: $e');
      }
    }
  }

  Future<void> removeItem(String userId, String itemId) async {
    _memoryCache.removeWhere((w) => w.id == itemId);

    final fs = _firestore;
    if (userId.isNotEmpty && fs != null) {
      try {
        await fs
            .collection('users')
            .doc(userId)
            .collection('wishlist')
            .doc(itemId)
            .delete();
      } catch (e) {
        debugPrint('WishlistRepository.removeItem error: $e');
      }
    }
  }


  Future<List<WishlistItemEntity>> getWishlist({required String userId}) async {
    return List.unmodifiable(_memoryCache);
  }

  Future<void> addToWishlist(WishlistItemEntity item) => addItem(item);

  Future<void> removeFromWishlist({required String userId, required String itemId}) => removeItem(userId, itemId);

  bool isProductWishlisted(String productId) {
    return _memoryCache.any((w) => w.productId == productId);
  }
}


final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository();
});
