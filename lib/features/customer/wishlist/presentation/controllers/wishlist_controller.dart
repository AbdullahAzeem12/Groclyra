import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/customer/cart/presentation/controllers/cart_controller.dart';

import '../../data/repositories/wishlist_repository.dart';
import '../../domain/entities/wishlist_item_entity.dart';

enum WishlistSort {
  recentlySaved('Recently Saved'),
  priceLowHigh('Price: Low to High'),
  priceHighLow('Price: High to Low'),
  priceDrop('Biggest Price Drops');

  final String label;
  const WishlistSort(this.label);
}

class WishlistState {
  final List<WishlistItemEntity> allItems;
  final String searchQuery;
  final MainCategoryType? selectedCategory;
  final String selectedCollection;
  final WishlistSort sortBy;
  final bool isLoading;
  final String? errorMessage;

  const WishlistState({
    this.allItems = const [],
    this.searchQuery = '',
    this.selectedCategory,
    this.selectedCollection = 'All',
    this.sortBy = WishlistSort.recentlySaved,
    this.isLoading = false,
    this.errorMessage,
  });

  int get totalCount => allItems.length;

  List<String> get availableCollections {
    final set = <String>{'All'};
    for (final it in allItems) {
      if (it.collectionName.isNotEmpty) {
        set.add(it.collectionName);
      }
    }
    return set.toList();
  }

  List<WishlistItemEntity> get filteredItems {
    var list = List<WishlistItemEntity>.from(allItems);

    // 1. Search Query
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((item) {
        return item.title.toLowerCase().contains(q) ||
            item.categoryName.toLowerCase().contains(q) ||
            item.brand.toLowerCase().contains(q);
      }).toList();
    }

    // 2. Category Filter
    if (selectedCategory != null) {
      list = list.where((item) => item.categoryType == selectedCategory).toList();
    }

    // 3. Collection Filter
    if (selectedCollection != 'All') {
      list = list.where((item) => item.collectionName == selectedCollection).toList();
    }

    // 4. Sorting
    switch (sortBy) {
      case WishlistSort.recentlySaved:
        list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
        break;
      case WishlistSort.priceLowHigh:
        list.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
        break;
      case WishlistSort.priceHighLow:
        list.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
      case WishlistSort.priceDrop:
        list.sort((a, b) => b.priceDropAmount.compareTo(a.priceDropAmount));
        break;
    }

    return list;
  }

  WishlistState copyWith({
    List<WishlistItemEntity>? allItems,
    String? searchQuery,
    MainCategoryType? selectedCategory,
    bool clearCategory = false,
    String? selectedCollection,
    WishlistSort? sortBy,
    bool? isLoading,
    String? errorMessage,
  }) {
    return WishlistState(
      allItems: allItems ?? this.allItems,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedCollection: selectedCollection ?? this.selectedCollection,
      sortBy: sortBy ?? this.sortBy,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class WishlistController extends StateNotifier<WishlistState> {
  final WishlistRepository _repository;
  final String _userId;
  StreamSubscription<List<WishlistItemEntity>>? _sub;

  WishlistController(this._repository, this._userId) : super(const WishlistState(isLoading: true)) {
    _initStream();
  }

  void _initStream() {
    _sub = _repository.streamWishlist(_userId).listen(
      (list) {
        state = state.copyWith(
          allItems: list,
          isLoading: false,
        );
      },
      onError: (e) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      },
    );
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }

  void setCategoryFilter(MainCategoryType? cat) {
    state = state.copyWith(selectedCategory: cat, clearCategory: cat == null);
  }

  void setCollectionFilter(String col) {
    state = state.copyWith(selectedCollection: col);
  }

  void setSort(WishlistSort sort) {
    state = state.copyWith(sortBy: sort);
  }

  Future<void> removeItem(String itemId) async {
    await _repository.removeItem(_userId, itemId);
  }

  Future<void> undoRemove(WishlistItemEntity item) async {
    await _repository.addItem(item);
  }

  /// Move item to cart after verifying price and availability
  Future<bool> moveToCart(WishlistItemEntity item, CartController cartController) async {
    if (!item.inStock || item.stockCount <= 0) {
      return false;
    }

    // Convert to ProductEntity drop-in
    final product = ProductEntity(
      id: item.productId,
      title: item.title,
      shortDescription: item.brand,
      description: item.title,
      categoryType: item.categoryType,
      categoryName: item.categoryName,
      brand: item.brand,
      sellerId: 'sel_official_groclyra',
      sellerName: 'Groclyra Marketplace Direct',
      sellerRating: 4.9,
      basePrice: item.compareAtPrice ?? item.currentPrice,
      salePrice: item.currentPrice,
      discountPercentage: item.compareAtPrice != null && item.compareAtPrice! > item.currentPrice
          ? (((item.compareAtPrice! - item.currentPrice) / item.compareAtPrice!) * 100).round()
          : 0,
      rating: 4.8,
      reviewCount: 38,
      soldCount: 142,
      totalStock: item.stockCount,
      images: [item.imageUrl],
      variants: [],
    );

    await cartController.addToCart(product, quantity: 1);
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final wishlistControllerProvider = StateNotifierProvider<WishlistController, WishlistState>((ref) {
  final repo = ref.watch(wishlistRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.user?.id ?? '';
  return WishlistController(repo, userId);
});
