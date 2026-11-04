import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/customer/cart/domain/entities/cart_item_entity.dart';
import 'package:groclyra/features/customer/cart/data/repositories/cart_repository.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';

class CartState {
  final List<CartItemEntity> items;
  final String? appliedVoucher;
  final double discountAmount;
  final bool isLoading;

  const CartState({
    this.items = const [],
    this.appliedVoucher,
    this.discountAmount = 0.0,
    this.isLoading = false,
  });

  int get totalItemCount => items.fold(0, (sum, it) => sum + it.quantity);
  
  double get subtotal => items.fold(0.0, (sum, it) => sum + it.totalPrice);
  
  // Calculate shipping fee: Rs. 150 flat per unique seller
  double get totalShippingFee {
    if (items.isEmpty) return 0.0;
    final uniqueSellers = items.map((e) => e.sellerId).toSet().length;
    return uniqueSellers * 150.0;
  }

  double get grandTotal => (subtotal + totalShippingFee - discountAmount).clamp(0.0, double.infinity);

  // Group items by Seller for multi-vendor checkout presentation
  Map<String, List<CartItemEntity>> get itemsBySeller {
    final map = <String, List<CartItemEntity>>{};
    for (final item in items) {
      map.putIfAbsent(item.sellerName, () => []).add(item);
    }
    return map;
  }

  CartState copyWith({
    List<CartItemEntity>? items,
    String? appliedVoucher,
    double? discountAmount,
    bool? isLoading,
    bool clearVoucher = false,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedVoucher: clearVoucher ? null : (appliedVoucher ?? this.appliedVoucher),
      discountAmount: clearVoucher ? 0.0 : (discountAmount ?? this.discountAmount),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CartController extends StateNotifier<CartState> {
  final CartRepository _repository;

  CartController(this._repository) : super(CartState(items: _repository.getItems()));

  Future<void> addItem({
    required ProductEntity product,
    ProductVariant? variant,
    int quantity = 1,
  }) async {
    final updated = await _repository.addItem(
      product: product,
      variant: variant,
      quantity: quantity,
    );
    state = state.copyWith(items: updated);
  }

  Future<void> addToCart(
    ProductEntity product, {
    ProductVariant? variant,
    int quantity = 1,
  }) async {
    await addItem(product: product, variant: variant, quantity: quantity);
  }

  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    final updated = await _repository.updateQuantity(cartItemId, newQuantity);
    state = state.copyWith(items: updated);
  }

  Future<void> removeItem(String cartItemId) async {
    final updated = await _repository.removeItem(cartItemId);
    state = state.copyWith(items: updated);
  }

  bool applyVoucher(String code) {
    final clean = code.trim().toUpperCase();
    if (clean == 'GROCLYRA10') {
      final discount = state.subtotal * 0.10;
      state = state.copyWith(appliedVoucher: clean, discountAmount: discount);
      return true;
    } else if (clean == 'WELCOME500') {
      state = state.copyWith(appliedVoucher: clean, discountAmount: 500.0);
      return true;
    }
    return false;
  }

  void removeVoucher() {
    state = state.copyWith(clearVoucher: true);
  }

  Future<void> clearCart() async {
    await _repository.clearCart();
    state = const CartState();
  }
}

final cartControllerProvider = StateNotifierProvider<CartController, CartState>((ref) {
  final repository = ref.watch(cartRepositoryProvider);
  return CartController(repository);
});
