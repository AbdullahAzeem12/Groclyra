import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';
import '../../domain/entities/seller_store_entity.dart';
import '../../data/repositories/seller_repository.dart';
import '../../../catalog/domain/entities/product_entity.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class SellerState {
  final SellerStoreEntity? store;
  final List<ProductEntity> products;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic> stats;

  const SellerState({
    this.store,
    this.products = const [],
    this.isLoading = false,
    this.errorMessage,
    this.stats = const {},
  });

  SellerState copyWith({
    SellerStoreEntity? store,
    List<ProductEntity>? products,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? stats,
  }) {
    return SellerState(
      store: store ?? this.store,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      stats: stats ?? this.stats,
    );
  }
}

class SellerController extends StateNotifier<SellerState> {
  final SellerRepository _repository;
  final String _sellerId;
  StreamSubscription? _storeSub;
  StreamSubscription? _productsSub;
  StreamSubscription? _statsSub;

  SellerController(this._repository, this._sellerId)
      : super(const SellerState()) {
    _initStreams();
  }

  void _initStreams() {
    if (_sellerId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No seller account found. Please log in as a seller.',
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    
    _storeSub = _repository.streamStoreProfile(_sellerId).listen((store) {
      state = state.copyWith(store: store, isLoading: false);
    }, onError: (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    });

    _productsSub = _repository.streamSellerProducts(_sellerId).listen((products) {
      state = state.copyWith(products: products);
    }, onError: (e) {
      state = state.copyWith(errorMessage: e.toString());
    });

    _statsSub = _repository.streamSellerStats(_sellerId).listen((stats) {
      state = state.copyWith(stats: stats);
    }, onError: (e) {
      // Ignore stats error
    });
  }
  
  Future<void> loadSellerData() async {
    // Just re-init streams if requested to refresh
    _storeSub?.cancel();
    _productsSub?.cancel();
    _statsSub?.cancel();
    _initStreams();
  }

  @override
  void dispose() {
    _storeSub?.cancel();
    _productsSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  Future<bool> createProduct(ProductEntity product) async {
    try {
      await _repository.addNewProduct(product);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> updateStock(
      String productId, String variantId, int newStock) async {
    if (newStock < 0) return;
    await _repository.updateInventory(productId, variantId, newStock);
  }

  Future<void> updateProduct(
      String productId, Map<String, dynamic> updates) async {
    await _repository.updateProduct(productId, updates);
  }

  Future<void> updateStoreProfile(Map<String, dynamic> updates) async {
    final effectiveSellerId = _sellerId.isNotEmpty
        ? _sellerId
        : (AppDatabase.instance.activeSessionUserId ?? '');
    if (effectiveSellerId.isEmpty) {
      throw Exception('Seller account ID not found. Please log in as a seller.');
    }
    await _repository.updateStoreProfile(effectiveSellerId, updates);
  }
}

final sellerControllerProvider =
    StateNotifierProvider<SellerController, SellerState>((ref) {
  final repository = ref.watch(sellerRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final sellerId = authState.user?.id.isNotEmpty == true
      ? authState.user!.id
      : (AppDatabase.instance.activeSessionUserId ?? '');
  return SellerController(repository, sellerId);
});

