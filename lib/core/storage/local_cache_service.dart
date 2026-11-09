import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

/// SQL-backed Local Cache Service.
///
/// Completely replaces file-based local caches and SharedPreferences
/// with SQLite relational tables:
/// - `cart_cache` for shopping cart items
/// - `offline_mutations` for queued mutations
/// - `app_preferences` for cached products and wishlist identifiers
class LocalCacheService {
  static const String _keyCachedProducts = 'groclyra_cached_products';
  static const String _keyCachedWishlist = 'groclyra_cached_wishlist';
  static const String _keyCachedCart = 'groclyra_cached_cart';
  static const String _keyOfflineMutationQueue = 'groclyra_mutation_queue';

  final AppDatabase _db;
  final Map<String, dynamic> _memoryCache = {};

  LocalCacheService([dynamic legacyPrefs, AppDatabase? db])
      : _db = db ?? AppDatabase.instance;

  Future<void> cacheProducts(List<Map<String, dynamic>> productsJson) async {
    _memoryCache[_keyCachedProducts] = productsJson;
    try {
      await _db.insertOrReplace('app_preferences', {
        'key': _keyCachedProducts,
        'value': jsonEncode(productsJson),
        'type': 'json',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      _db.notifyTable('app_preferences');
    } catch (e) {
      debugPrint('[LocalCacheService] cacheProducts error: $e');
    }
  }

  List<Map<String, dynamic>>? getCachedProducts() {
    final cached = _memoryCache[_keyCachedProducts];
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return null;
  }

  Future<void> saveWishlistIds(List<String> productIds) async {
    _memoryCache[_keyCachedWishlist] = productIds;
    try {
      await _db.insertOrReplace('app_preferences', {
        'key': _keyCachedWishlist,
        'value': jsonEncode(productIds),
        'type': 'json',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      _db.notifyTable('app_preferences');
    } catch (e) {
      debugPrint('[LocalCacheService] saveWishlistIds error: $e');
    }
  }

  List<String> getWishlistIds() {
    final cached = _memoryCache[_keyCachedWishlist];
    if (cached is List) {
      return cached.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> saveCartJson(List<Map<String, dynamic>> cartItemsJson) async {
    _memoryCache[_keyCachedCart] = cartItemsJson;
    try {
      // Clear previous cart cache
      await _db.delete('cart_cache');
      final now = DateTime.now().toIso8601String();
      for (final item in cartItemsJson) {
        final productId = item['productId']?.toString() ?? item['id']?.toString() ?? '';
        if (productId.isNotEmpty) {
          await _db.insertOrReplace('cart_cache', {
            'userId': item['userId']?.toString() ?? 'guest',
            'productId': productId,
            'quantity': item['quantity'] is int
                ? item['quantity']
                : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1,
            'variantName': item['variantName']?.toString() ?? item['variant']?.toString(),
            'unitPrice': (item['price'] is num
                    ? item['price']
                    : double.tryParse(item['price']?.toString() ?? '0'))
                ?.toDouble() ??
                0.0,
            'fullDataJson': jsonEncode(item),
            'updatedAt': now,
          });
        }
      }
      _db.notifyTable('cart_cache');
    } catch (e) {
      debugPrint('[LocalCacheService] saveCartJson error: $e');
    }
  }

  List<Map<String, dynamic>>? getCartJson() {
    final cached = _memoryCache[_keyCachedCart];
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return null;
  }

  Future<void> enqueueOfflineMutation(Map<String, dynamic> mutation) async {
    final queue = getOfflineMutationQueue();
    queue.add(mutation);
    _memoryCache[_keyOfflineMutationQueue] = queue;

    try {
      final now = DateTime.now().toIso8601String();
      final id = mutation['id']?.toString() ?? 'mut_${DateTime.now().millisecondsSinceEpoch}';
      await _db.insertOrReplace('offline_mutations', {
        'id': id,
        'mutationType': mutation['type']?.toString() ?? 'generic',
        'payloadJson': jsonEncode(mutation),
        'status': 'pending',
        'createdAt': now,
      });
      _db.notifyTable('offline_mutations');
    } catch (e) {
      debugPrint('[LocalCacheService] enqueueOfflineMutation error: $e');
    }
  }

  List<Map<String, dynamic>> getOfflineMutationQueue() {
    final cached = _memoryCache[_keyOfflineMutationQueue];
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> clearOfflineMutationQueue() async {
    _memoryCache.remove(_keyOfflineMutationQueue);
    try {
      await _db.delete('offline_mutations');
      _db.notifyTable('offline_mutations');
    } catch (e) {
      debugPrint('[LocalCacheService] clearOfflineMutationQueue error: $e');
    }
  }
}
