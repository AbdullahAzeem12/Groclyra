import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';
import 'package:groclyra/features/customer/cart/presentation/controllers/cart_controller.dart';
import 'package:groclyra/features/customer/wishlist/domain/entities/wishlist_item_entity.dart';
import 'package:groclyra/features/customer/wishlist/presentation/controllers/wishlist_controller.dart';


class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final wishlistState = ref.watch(wishlistControllerProvider);
    final wishlistCtrl = ref.read(wishlistControllerProvider.notifier);
    final cartCtrl = ref.read(cartControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = themeState.palette.primaryColor;

    final filteredItems = wishlistState.filteredItems;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'My Wishlist & Saved',
        subtitle: '${wishlistState.totalCount} Crockery & Grocery items saved',
        showBack: true,
        showThemePicker: false,
      ),
      body: Column(
        children: [
          // 1. Search and Sort Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: isDark ? const Color(0xFF10141D) : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: wishlistCtrl.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: 'Search saved items...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF181E2B) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<WishlistSort>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181E2B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                    child: Icon(Icons.sort_rounded, color: primaryColor, size: 20),
                  ),
                  tooltip: 'Sort Wishlist',
                  onSelected: wishlistCtrl.setSort,
                  itemBuilder: (ctx) => WishlistSort.values
                      .map((s) => PopupMenuItem(
                            value: s,
                            child: Text(s.label),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

          // 2. Category Filter Tabs (All, Grocery, Crockery)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: isDark ? const Color(0xFF10141D) : Colors.white,
            child: Row(
              children: [
                _buildCategoryChip(
                  context: context,
                  label: 'All Items',
                  isSelected: wishlistState.selectedCategory == null,
                  onTap: () => wishlistCtrl.setCategoryFilter(null),
                  primaryColor: primaryColor,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context: context,
                  label: '🥬 Grocery',
                  isSelected: wishlistState.selectedCategory == MainCategoryType.grocery,
                  onTap: () => wishlistCtrl.setCategoryFilter(MainCategoryType.grocery),
                  primaryColor: primaryColor,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context: context,
                  label: '🍽️ Crockery',
                  isSelected: wishlistState.selectedCategory == MainCategoryType.crockery,
                  onTap: () => wishlistCtrl.setCategoryFilter(MainCategoryType.crockery),
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ),

          // 3. Collection Filter Chips
          if (wishlistState.availableCollections.length > 1)
            Container(
              height: 40,
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: wishlistState.availableCollections.length,
                itemBuilder: (context, idx) {
                  final col = wishlistState.availableCollections[idx];
                  final isSelected = wishlistState.selectedCollection == col;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(col, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selectedColor: primaryColor.withValues(alpha: 0.2),
                      checkmarkColor: primaryColor,
                      onSelected: (val) => wishlistCtrl.setCollectionFilter(col),
                    ),
                  );
                },
              ),
            ),

          const Divider(height: 1),

          // 4. Wishlist Items List
          Expanded(
            child: wishlistState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                    ? _buildEmptyState(context, primaryColor)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildWishlistCard(
                            context,
                            ref,
                            item,
                            isDark,
                            primaryColor,
                            wishlistCtrl,
                            cartCtrl,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return SpringTouchScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: Icon(Icons.favorite_border_rounded, size: 64, color: primaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Saved Products Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse Groclyra grocery and fine crockery collections, and tap the heart icon to save items with live price tracking.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
              label: const Text('Explore Catalog', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => context.go(RouteNames.customerCategories),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistCard(
    BuildContext context,
    WidgetRef ref,
    WishlistItemEntity item,
    bool isDark,
    Color primaryColor,
    WishlistController wishlistCtrl,
    CartController cartCtrl,
  ) {
    final themeState = ref.watch(themeControllerProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141923) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              child: SizedBox(
                width: 84,
                height: 84,
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: isDark ? const Color(0xFF1F2937) : Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? const Color(0xFF1F2937) : Colors.grey[200],
                    child: Icon(
                      item.categoryType == MainCategoryType.crockery
                          ? Icons.table_bar_rounded
                          : Icons.eco_rounded,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand & Collection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.brand.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                        tooltip: 'Remove from Saved',
                        onPressed: () {
                          wishlistCtrl.removeItem(item.id);
                          AppToggleMessage.wishlist(
                            context,
                            title: item.title,
                            isAdded: false,
                            onUndo: () => wishlistCtrl.undoRemove(item),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Title
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),

                  // Price & Price Drop Badge
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        CurrencyFormatter.format(item.currentPrice),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: primaryColor,
                        ),
                      ),
                      if (item.hasPriceDrop)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🔻 Rs. ${item.priceDropAmount.toInt()} Drop',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Stock indicator + Move to Cart Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.inStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 13,
                            color: item.inStock ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.inStock ? 'In Stock' : 'Out of Stock',
                            style: TextStyle(
                              fontSize: 11,
                              color: item.inStock ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SpringTouchScale(
                        onTap: () async {
                          final success = await wishlistCtrl.moveToCart(item, cartCtrl);
                          if (context.mounted) {
                            if (success) {
                              AppToggleMessage.cart(
                                context,
                                title: item.title,
                                price: CurrencyFormatter.format(item.currentPrice),
                                onAction: () => context.go(RouteNames.customerCart),
                              );
                            } else {
                              AppToggleMessage.error(
                                context,
                                'Item is currently out of stock.',
                                title: 'Out of Stock',
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: themeState.palette.linearGradient,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_shopping_cart_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Move to Cart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
