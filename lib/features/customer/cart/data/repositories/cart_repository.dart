import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/storage/local_cache_service.dart';
import 'package:groclyra/features/customer/cart/domain/entities/cart_item_entity.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';

class CartRepository {
  final LocalCacheService? _cacheService;
  List<CartItemEntity> _cartItems = [];

  CartRepository(this._cacheService) {
    _loadFromCache();
  }

  void _loadFromCache() {
    final cached = _cacheService?.getCartJson();
    if (cached != null) {
      try {
        _cartItems = cached.map((e) => CartItemEntity.fromJson(e)).toList();
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    await _cacheService?.saveCartJson(_cartItems.map((e) => e.toJson()).toList());
  }

  List<CartItemEntity> getItems() => List.unmodifiable(_cartItems);

  Future<List<CartItemEntity>> addItem({
    required ProductEntity product,
    ProductVariant? variant,
    int quantity = 1,
  }) async {
    final existingIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id && item.selectedVariant?.id == variant?.id,
    );

    if (existingIndex >= 0) {
      final existing = _cartItems[existingIndex];
      _cartItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      _cartItems.add(
        CartItemEntity(
          id: 'cart_${DateTime.now().millisecondsSinceEpoch}_${product.id}',
          product: product,
          selectedVariant: variant ?? (product.variants.isNotEmpty ? product.variants.first : null),
          quantity: quantity,
          addedAt: DateTime.now(),
        ),
      );
    }

    await _persist();
    return List.unmodifiable(_cartItems);
  }

  Future<List<CartItemEntity>> updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity <= 0) {
      return removeItem(cartItemId);
    }
    final index = _cartItems.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      _cartItems[index] = _cartItems[index].copyWith(quantity: newQuantity);
      await _persist();
    }
    return List.unmodifiable(_cartItems);
  }

  Future<List<CartItemEntity>> removeItem(String cartItemId) async {
    _cartItems.removeWhere((item) => item.id == cartItemId);
    await _persist();
    return List.unmodifiable(_cartItems);
  }

  Future<void> clearCart() async {
    _cartItems.clear();
    await _persist();
  }
}

// FIX: previously this provider always returned null (a latent bug), which
// disabled the LocalCacheService entirely — the shopping cart was memory-only
// and evaporated on every app restart. It now constructs the real cache
// service on top of the shared PreferencesService storage pipeline.
final localCacheServiceProvider = Provider<LocalCacheService?>((ref) {
  return LocalCacheService();
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  final cache = ref.watch(localCacheServiceProvider);
  return CartRepository(cache);
});
