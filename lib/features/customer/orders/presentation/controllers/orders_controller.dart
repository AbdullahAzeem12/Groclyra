import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/customer/cart/domain/entities/cart_item_entity.dart';
import 'package:groclyra/features/customer/orders/data/repositories/order_repository.dart';
import 'package:groclyra/features/customer/orders/domain/entities/order_entity.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';

class OrdersState {
  final List<OrderEntity> orders;
  final bool isLoading;
  final String? errorMessage;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  OrdersState copyWith({
    List<OrderEntity>? orders,
    bool? isLoading,
    String? errorMessage,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class OrdersController extends StateNotifier<OrdersState> {
  final OrderRepository _repository;
  final String _customerId;

  OrdersController(this._repository, this._customerId)
      : super(const OrdersState()) {
    loadOrders();
  }

  Future<void> loadOrders() async {
    if (_customerId.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getOrders(customerId: _customerId);
      state = state.copyWith(orders: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<OrderEntity?> placeOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<CartItemEntity> items,
    required double discountAmount,
    required PaymentMethod paymentMethod,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final order = await _repository.createOrder(
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        deliveryAddress: deliveryAddress,
        items: items,
        discountAmount: discountAmount,
        paymentMethod: paymentMethod,
      );

      state = state.copyWith(
        orders: [order, ...state.orders],
        isLoading: false,
      );
      return order;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    await _repository.updateOrderStatus(orderId, status);
    await loadOrders();
  }
}

final ordersControllerProvider =
    StateNotifierProvider<OrdersController, OrdersState>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  // Bind to authenticated customer's UID for Firestore filtering
  final authState = ref.watch(authControllerProvider);
  final customerId = authState.user?.id ?? '';
  return OrdersController(repository, customerId);
});
