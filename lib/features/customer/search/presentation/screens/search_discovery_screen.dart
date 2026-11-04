import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_colors.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/features/catalog/data/repositories/catalog_repository.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/product_card_item.dart';

/// Live search providers — auto-dispose when screen closes
final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final _searchCategoryFilterProvider =
    StateProvider.autoDispose<MainCategoryType?>((ref) => null);

final _searchResultsProvider =
    StreamProvider.autoDispose<List<ProductEntity>>((ref) {
  final query = ref.watch(_searchQueryProvider);
  final categoryFilter = ref.watch(_searchCategoryFilterProvider);

  // All products stream — real-time
  final allProductsStream = ref.watch(catalogRepositoryProvider).streamProducts(
        categoryType: categoryFilter,
      );

  return allProductsStream.map((products) {
    if (query.trim().isEmpty) return products;
    final q = query.toLowerCase().trim();
    return products.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.categoryName.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          (p.material?.toLowerCase().contains(q) ?? false) ||
          (p.restaurantName?.toLowerCase().contains(q) ?? false) ||
          (p.cuisineType?.toLowerCase().contains(q) ?? false) ||
          p.sellerName.toLowerCase().contains(q);
    }).toList();
  });
});

class SearchDiscoveryScreen extends ConsumerStatefulWidget {
  const SearchDiscoveryScreen({super.key});

  @override
  ConsumerState<SearchDiscoveryScreen> createState() =>
      _SearchDiscoveryScreenState();
}

class _SearchDiscoveryScreenState extends ConsumerState<SearchDiscoveryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final categoryFilter = ref.watch(_searchCategoryFilterProvider);
    final searchResultsAsync = ref.watch(_searchResultsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Compute cell aspect ratio from actual screen width
    final sw = MediaQuery.of(context).size.width;
    final cardW = (sw - 32.0 - 12.0) / 2.0;
    final gridAspectRatio = cardW / (cardW / 1.1 + 140.0);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1319) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF141923) : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              filled: false,
              fillColor: Colors.transparent,
              hoverColor: Colors.transparent,
              hintText: 'Search crockery, groceries, biryani, milk...',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: Colors.grey),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 18, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(_searchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
            ),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
            onChanged: (value) {
              ref.read(_searchQueryProvider.notifier).state = value;
            },
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Category Filter Chips ──────────────────────────────────────────
          Container(
            height: 50,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF141923)
                  : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E2532)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  label: '✨ All',
                  selected: categoryFilter == null,
                  onSelected: (_) => ref
                      .read(_searchCategoryFilterProvider.notifier)
                      .state = null,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: '🍽️ Crockery',
                  selected:
                      categoryFilter == MainCategoryType.crockery,
                  onSelected: (v) => ref
                      .read(_searchCategoryFilterProvider.notifier)
                      .state = v
                      ? MainCategoryType.crockery
                      : null,
                  activeColor: AppColors.crockeryPill,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: '🛒 Grocery',
                  selected:
                      categoryFilter == MainCategoryType.grocery,
                  onSelected: (v) => ref
                      .read(_searchCategoryFilterProvider.notifier)
                      .state = v
                      ? MainCategoryType.grocery
                      : null,
                  activeColor: AppColors.groceryPill,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: '🥛 Dairy & Bakery',
                  selected:
                      categoryFilter == MainCategoryType.dairyBakery,
                  onSelected: (v) => ref
                      .read(_searchCategoryFilterProvider.notifier)
                      .state = v
                      ? MainCategoryType.dairyBakery
                      : null,
                  activeColor: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: '🍔 Fast Food',
                  selected:
                      categoryFilter == MainCategoryType.fastFood,
                  onSelected: (v) => ref
                      .read(_searchCategoryFilterProvider.notifier)
                      .state = v
                      ? MainCategoryType.fastFood
                      : null,
                  activeColor: const Color(0xFFFF6B35),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Search Results ─────────────────────────────────────────────────
          Expanded(
            child: searchResultsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => EmptyStateView(
                title: 'Search Unavailable',
                description: 'Please try again in a moment.',
                icon: Icons.search_off_rounded,
                actionButtonText: 'Retry',
                onAction: () =>
                    ref.invalidate(_searchResultsProvider),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return EmptyStateView(
                    title: query.isEmpty
                        ? 'Start Typing to Search'
                        : 'No Results for "$query"',
                    description: query.isEmpty
                        ? 'Try searching crockery sets, basmati rice, biryani, milk, or any brand...'
                        : 'Try a different spelling or explore all categories.',
                    icon: Icons.search_rounded,
                    actionButtonText:
                        categoryFilter != null ? 'Clear Category Filter' : null,
                    onAction: categoryFilter != null
                        ? () => ref
                            .read(_searchCategoryFilterProvider.notifier)
                            .state = null
                        : null,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Results count header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text(
                        '${products.length} product${products.length == 1 ? '' : 's'} found${query.isNotEmpty ? ' for "$query"' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: gridAspectRatio,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCardItem(
                            product: product,
                            onTap: () => context.push(
                              '${RouteNames.customerProductDetails}/${product.id}',
                              extra: product,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    Color? activeColor,
    required bool isDark,
  }) {
    final color = activeColor ?? const Color(0xFF6366F1);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected
              ? Colors.white
              : (isDark ? Colors.white70 : const Color(0xFF374151)),
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor:
          isDark ? const Color(0xFF1E2532) : const Color(0xFFF1F5F9),
      selectedColor: color,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      side: BorderSide(
        color: selected ? color : (isDark ? const Color(0xFF2E3848) : const Color(0xFFE2E8F0)),
        width: 1.2,
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }
}
