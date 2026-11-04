import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static const String _keyCachedProducts = 'groclyra_cached_products';
  static const String _keyCachedWishlist = 'groclyra_cached_wishlist';
  static const String _keyCachedCart = 'groclyra_cached_cart';
  static const String _keyOfflineMutationQueue = 'groclyra_mutation_queue';

  final SharedPreferences _prefs;

  LocalCacheService(this._prefs);

  Future<void> cacheProducts(List<Map<String, dynamic>> productsJson) async {
    await _prefs.setString(_keyCachedProducts, jsonEncode(productsJson));
  }

  List<Map<String, dynamic>>? getCachedProducts() {
    final raw = _prefs.getString(_keyCachedProducts);
    if (raw == null) return null;
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWishlistIds(List<String> productIds) async {
    await _prefs.setStringList(_keyCachedWishlist, productIds);
  }

  List<String> getWishlistIds() {
    return _prefs.getStringList(_keyCachedWishlist) ?? [];
  }

  Future<void> saveCartJson(List<Map<String, dynamic>> cartItemsJson) async {
    await _prefs.setString(_keyCachedCart, jsonEncode(cartItemsJson));
  }

  List<Map<String, dynamic>>? getCartJson() {
    final raw = _prefs.getString(_keyCachedCart);
    if (raw == null) return null;
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> enqueueOfflineMutation(Map<String, dynamic> mutation) async {
    final current = getOfflineMutationQueue();
    current.add(mutation);
    await _prefs.setString(_keyOfflineMutationQueue, jsonEncode(current));
  }

  List<Map<String, dynamic>> getOfflineMutationQueue() {
    final raw = _prefs.getString(_keyOfflineMutationQueue);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearOfflineMutationQueue() async {
    await _prefs.remove(_keyOfflineMutationQueue);
  }
}
