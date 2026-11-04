import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../data/repositories/catalog_repository.dart';

class CatalogState {
  final List<CategoryEntity> categories;
  final List<ProductEntity> allProducts;
  final List<ProductEntity> filteredProducts;
  final List<ProductEntity> flashDeals;
  final MainCategoryType? selectedMainCategory;
  final String? selectedCategoryName;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  const CatalogState({
    this.categories = const [],
    this.allProducts = const [],
    this.filteredProducts = const [],
    this.flashDeals = const [],
    this.selectedMainCategory,
    this.selectedCategoryName,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  MainCategoryType? get selectedPillarFilter => selectedMainCategory;

  List<ProductEntity> get crockeryProducts =>
      allProducts.where((p) => p.categoryType == MainCategoryType.crockery).toList();

  List<ProductEntity> get groceryProducts => allProducts
      .where((p) =>
          p.categoryType == MainCategoryType.grocery ||
          p.categoryType == MainCategoryType.dairyBakery)
      .toList();

  List<ProductEntity> get fastFoodProducts =>
      allProducts.where((p) => p.categoryType == MainCategoryType.fastFood).toList();

  List<ProductEntity> get restaurantProducts =>
      allProducts.where((p) => p.isFastFood && p.restaurantType == 'restaurant').toList();

  List<ProductEntity> get bakeryProducts =>
      allProducts.where((p) => p.isFastFood && p.restaurantType == 'bakery').toList();

  /// Unique restaurant names for the restaurant strip
  List<String> get uniqueRestaurantNames {
    final names = fastFoodProducts
        .where((p) => p.restaurantName != null)
        .map((p) => p.restaurantName!)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  CatalogState copyWith({
    List<CategoryEntity>? categories,
    List<ProductEntity>? allProducts,
    List<ProductEntity>? filteredProducts,
    List<ProductEntity>? flashDeals,
    MainCategoryType? selectedMainCategory,
    String? selectedCategoryName,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearCategoryFilter = false,
  }) {
    return CatalogState(
      categories: categories ?? this.categories,
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      flashDeals: flashDeals ?? this.flashDeals,
      selectedMainCategory: clearCategoryFilter ? null : (selectedMainCategory ?? this.selectedMainCategory),
      selectedCategoryName: clearCategoryFilter ? null : (selectedCategoryName ?? this.selectedCategoryName),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CatalogController extends StateNotifier<CatalogState> {
  final CatalogRepository _repository;

  CatalogController(this._repository) : super(const CatalogState()) {
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    state = state.copyWith(isLoading: true);
    try {
      final categories = await _repository.getCategories();
      final products = await _repository.getProducts();
      final flashDeals = await _repository.getProducts(isFlashDeal: true);

      state = state.copyWith(
        categories: categories,
        allProducts: products,
        filteredProducts: products,
        flashDeals: flashDeals,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void filterByMainCategory(MainCategoryType? type) {
    if (type == null) {
      state = state.copyWith(
        clearCategoryFilter: true,
        filteredProducts: state.allProducts,
      );
    } else {
      final list = state.allProducts.where((p) => p.categoryType == type).toList();
      state = state.copyWith(
        selectedMainCategory: type,
        filteredProducts: list,
      );
    }
  }

  void filterByPillar(MainCategoryType? type) => filterByMainCategory(type);

  void filterByRestaurant(String? restaurantName) {
    if (restaurantName == null || restaurantName.isEmpty) {
      state = state.copyWith(
        selectedMainCategory: MainCategoryType.fastFood,
        filteredProducts: state.allProducts
            .where((p) => p.categoryType == MainCategoryType.fastFood)
            .toList(),
      );
    } else {
      final list = state.allProducts
          .where((p) => p.restaurantName == restaurantName)
          .toList();
      state = state.copyWith(
        selectedMainCategory: MainCategoryType.fastFood,
        filteredProducts: list,
      );
    }
  }

  void search(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      state = state.copyWith(
        searchQuery: '',
        filteredProducts: state.selectedMainCategory != null
            ? state.allProducts.where((p) => p.categoryType == state.selectedMainCategory).toList()
            : state.allProducts,
      );
      return;
    }

    final filtered = state.allProducts.where((p) {
      final matchTitle = p.title.toLowerCase().contains(clean);
      final matchBrand = p.brand.toLowerCase().contains(clean);
      final matchCategory = p.categoryName.toLowerCase().contains(clean);
      final matchMaterial = p.material?.toLowerCase().contains(clean) ?? false;
      return matchTitle || matchBrand || matchCategory || matchMaterial;
    }).toList();

    state = state.copyWith(searchQuery: query, filteredProducts: filtered);
  }

  void setSearchQuery(String query) => search(query);

  void resetFilters() {
    state = state.copyWith(
      clearCategoryFilter: true,
      searchQuery: '',
      filteredProducts: state.allProducts,
    );
  }
}

final catalogControllerProvider = StateNotifierProvider<CatalogController, CatalogState>((ref) {
  final repository = ref.watch(catalogRepositoryProvider);
  return CatalogController(repository);
});
