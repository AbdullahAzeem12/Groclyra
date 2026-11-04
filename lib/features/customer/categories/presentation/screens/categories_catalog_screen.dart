import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/product_card_item.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/catalog/data/repositories/catalog_repository.dart';
import 'package:groclyra/features/admin/vendors/data/repositories/vendor_catalog_repository.dart';

class CategoriesCatalogScreen extends ConsumerStatefulWidget {
  final MainCategoryType? initialCategory;
  const CategoriesCatalogScreen({super.key, this.initialCategory});

  @override
  ConsumerState<CategoriesCatalogScreen> createState() =>
      _CategoriesCatalogScreenState();
}

class _CategoriesCatalogScreenState extends ConsumerState<CategoriesCatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCategoryName;
  String? _selectedVendorId;

  final List<MainCategoryType> _pillarTypes = const [
    MainCategoryType.crockery,
    MainCategoryType.grocery,
    MainCategoryType.dairyBakery,
    MainCategoryType.fastFood,
  ];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialCategory != null) {
      initialIndex = _pillarTypes.indexOf(widget.initialCategory!).clamp(0, 3);
    }
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategoryName = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final allProductsAsync = ref.watch(allProductsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final integrationsAsync = ref.watch(vendorIntegrationsStreamProvider);

    final allProducts = allProductsAsync.value ?? [];
    final allCategories = categoriesAsync.value ?? [];
    final vendors = integrationsAsync.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final crockeryCats = allCategories
        .where((c) => c.parentType == MainCategoryType.crockery)
        .toList();
    final groceryCats = allCategories
        .where((c) => c.parentType == MainCategoryType.grocery)
        .toList();
    final dairyBakeryCats = allCategories
        .where((c) => c.parentType == MainCategoryType.dairyBakery)
        .toList();
    final fastFoodCats = allCategories
        .where((c) => c.parentType == MainCategoryType.fastFood)
        .toList();

    final crockeryProducts = allProducts
        .where((p) => p.categoryType == MainCategoryType.crockery)
        .toList();
    final groceryProducts = allProducts
        .where((p) => p.categoryType == MainCategoryType.grocery)
        .toList();
    final dairyBakeryProducts = allProducts
        .where((p) => p.categoryType == MainCategoryType.dairyBakery)
        .toList();
    final fastFoodProducts = allProducts
        .where((p) => p.categoryType == MainCategoryType.fastFood)
        .toList();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1319) : const Color(0xFFF8FAFC),
      appBar: GradientAppBar(
        title: 'Marketplace Catalog',
        subtitle: 'Verified Pakistani Marts & Direct Outlets',
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            tooltip: 'Search Catalog',
            onPressed: () => context.push(RouteNames.customerSearch),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '🍽️ Crockery'),
            Tab(text: '🛒 Grocery'),
            Tab(text: '🥛 Dairy & Bakery'),
            Tab(text: '🍔 Fast Food'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Real-Time Multi-Vendor Filter Strip ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            color: isDark ? const Color(0xFF141923) : const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildVendorChip(
                    label: 'All Marts & Stores',
                    emoji: '🏪',
                    isSelected: _selectedVendorId == null,
                    onTap: () => setState(() => _selectedVendorId = null),
                    themeState: themeState,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  ...vendors.map((vendor) {
                    final isSelected = _selectedVendorId == vendor.vendorId ||
                        _selectedVendorId == vendor.id;
                    final emoji = vendor.categoryType == MainCategoryType.crockery
                        ? '🍽️'
                        : vendor.categoryType == MainCategoryType.fastFood
                            ? '🍔'
                            : vendor.categoryType == MainCategoryType.dairyBakery
                                ? '🥖'
                                : '🛒';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildVendorChip(
                        label: vendor.vendorName
                            .replaceAll(RegExp(r'\s*\([^)]*\)'), ''),
                        emoji: emoji,
                        isSelected: isSelected,
                        onTap: () => setState(() {
                          _selectedVendorId =
                              isSelected ? null : vendor.vendorId;
                        }),
                        themeState: themeState,
                        isDark: isDark,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── Tab Views for Each Category ────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryBrowser(
                  categoryType: MainCategoryType.crockery,
                  categories: crockeryCats,
                  products: crockeryProducts,
                  isDark: isDark,
                  themeState: themeState,
                ),
                _buildCategoryBrowser(
                  categoryType: MainCategoryType.grocery,
                  categories: groceryCats,
                  products: groceryProducts,
                  isDark: isDark,
                  themeState: themeState,
                ),
                _buildCategoryBrowser(
                  categoryType: MainCategoryType.dairyBakery,
                  categories: dairyBakeryCats,
                  products: dairyBakeryProducts,
                  isDark: isDark,
                  themeState: themeState,
                ),
                _buildCategoryBrowser(
                  categoryType: MainCategoryType.fastFood,
                  categories: fastFoodCats,
                  products: fastFoodProducts,
                  isDark: isDark,
                  themeState: themeState,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorChip({
    required String label,
    required String emoji,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeState themeState,
    required bool isDark,
  }) {
    return SpringTouchScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? themeState.palette.primaryColor
              : (isDark ? const Color(0xFF1E2532) : Colors.white),
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(
            color: isSelected
                ? themeState.palette.primaryColor
                : (isDark ? const Color(0xFF2E3848) : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBrowser({
    required MainCategoryType categoryType,
    required List<CategoryEntity> categories,
    required List<ProductEntity> products,
    required bool isDark,
    required ThemeState themeState,
  }) {
    // 1. Filter by selected category (sidebar)
    List<ProductEntity> filtered = products;
    if (_selectedCategoryName != null) {
      final q = _selectedCategoryName!.toLowerCase().trim();
      final exactMatches = products.where((p) {
        return p.categoryName.toLowerCase().trim() == q ||
            (p.subcategoryName?.toLowerCase().trim() == q);
      }).toList();

      if (exactMatches.isNotEmpty) {
        filtered = exactMatches;
      } else {
        // Broad substring match so items are never hidden accidentally
        final subMatches = products.where((p) {
          return p.categoryName.toLowerCase().contains(q) ||
              p.title.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q);
        }).toList();
        filtered = subMatches.isNotEmpty ? subMatches : products;
      }
    }

    // 2. Filter by selected vendor (if any)
    if (_selectedVendorId != null) {
      final vendorMatches = filtered.where((p) {
        return p.sellerId == _selectedVendorId ||
            p.sourceVendorId == _selectedVendorId ||
            p.sellerName.toLowerCase().contains(_selectedVendorId!.toLowerCase());
      }).toList();
      if (vendorMatches.isNotEmpty) {
        filtered = vendorMatches;
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;
    final sidebarWidth = isNarrow ? 90.0 : 108.0;

    return Row(
      children: [
        // ── Left Subcategory Sidebar ──────────────────────────────────────────
        Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181E2B) : const Color(0xFFF1F3F9),
            border: Border(
              right: BorderSide(
                color: isDark
                    ? const Color(0xFF262E3D)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // All Items Option
              _buildSidebarItem(
                title: 'All Items',
                emoji: '✨',
                isSelected: _selectedCategoryName == null,
                onTap: () => setState(() => _selectedCategoryName = null),
                themeState: themeState,
              ),
              ...categories.map((cat) {
                final isSelected = _selectedCategoryName == cat.name;
                return _buildSidebarItem(
                  title: cat.name,
                  emoji: cat.iconEmoji,
                  isSelected: isSelected,
                  onTap: () =>
                      setState(() => _selectedCategoryName = cat.name),
                  themeState: themeState,
                );
              }),
            ],
          ),
        ),

        // ── Right Products Grid ──────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.store_mall_directory_outlined,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No products found in this category.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _selectedCategoryName = null;
                            _selectedVendorId = null;
                          }),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Reset All Filters'),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final gridPad = isNarrow ? 8.0 : 12.0;
                    final gap = isNarrow ? 8.0 : 10.0;
                    final cardW =
                        (constraints.maxWidth - (gridPad * 2) - gap) / 2.0;
                    final aspectRatio =
                        (cardW / (cardW / 1.05 + 148.0)).clamp(0.48, 0.65);
                    return GridView.builder(
                      padding: EdgeInsets.all(gridPad),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: aspectRatio,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        return ProductCardItem(
                          product: p,
                          onTap: () => context.push(
                            '${RouteNames.customerProductDetails}/${p.id}',
                            extra: p,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required String title,
    required String emoji,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeState themeState,
  }) {
    return SpringTouchScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? themeState.palette.primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          border: isSelected
              ? Border.all(
                  color: themeState.palette.primaryColor, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? themeState.palette.primaryColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
