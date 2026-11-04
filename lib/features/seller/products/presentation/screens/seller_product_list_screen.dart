import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/base64_image.dart';
import 'package:groclyra/features/seller/presentation/controllers/seller_controller.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'dart:ui';

class SellerProductListScreen extends ConsumerStatefulWidget {
  const SellerProductListScreen({super.key});

  @override
  ConsumerState<SellerProductListScreen> createState() =>
      _SellerProductListScreenState();
}

class _SellerProductListScreenState
    extends ConsumerState<SellerProductListScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _filterStatus = 'All'; // All, Active, LowStock, OutOfStock
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  List<ProductEntity> _filtered(List<ProductEntity> all) {
    var list = all;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.categoryName.toLowerCase().contains(q) ||
              p.brand.toLowerCase().contains(q))
          .toList();
    }
    switch (_filterStatus) {
      case 'Active':
        list = list.where((p) => p.totalStock > 10).toList();
        break;
      case 'LowStock':
        list = list.where((p) => p.totalStock > 0 && p.totalStock <= 10).toList();
        break;
      case 'OutOfStock':
        list = list.where((p) => p.totalStock == 0).toList();
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final sellerState = ref.watch(sellerControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered(sellerState.products);
    final primary = themeState.palette.primaryColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RouteNames.sellerDashboard);
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        appBar: GradientAppBar(
          title: 'Manage Listings',
          subtitle: '${sellerState.products.length} Products in Catalog',
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
              onPressed: () => context.push(RouteNames.sellerAddProduct),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Search + Filter Bar ─────────────────────────────────────────
            _buildSearchBar(isDark, primary),
            _buildFilterChips(isDark, primary),

            // ── Stats Summary ───────────────────────────────────────────────
            _buildQuickStats(isDark, primary, sellerState.products),

            // ── Product List ────────────────────────────────────────────────
            Expanded(
              child: sellerState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? EmptyStateView(
                          title: _searchQuery.isNotEmpty
                              ? 'No Results Found'
                              : 'No Listings Yet',
                          description: _searchQuery.isNotEmpty
                              ? 'Try a different search keyword.'
                              : 'Start selling by creating your first product.',
                          icon: Icons.add_business_rounded,
                          actionButtonText: 'Add Product',
                          onAction: () =>
                              context.push(RouteNames.sellerAddProduct),
                        ).animate().fadeIn(duration: 400.ms)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildProductCard(
                              context,
                              filtered[index],
                              index,
                              isDark,
                              themeState,
                            );
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: SpringTouchScale(
          onTap: () => context.push(RouteNames.sellerAddProduct),
          child: FloatingActionButton.extended(
            backgroundColor: primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New Listing',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {},
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search products, brands...',
          hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: primary, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1A2035) : Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2D3748)
                    : const Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            borderSide: BorderSide(color: primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark, Color primary) {
    final filters = ['All', 'Active', 'LowStock', 'OutOfStock'];
    final labels = {
      'All': 'All',
      'Active': '✅ In Stock',
      'LowStock': '⚠️ Low Stock',
      'OutOfStock': '❌ Out of Stock',
    };
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _filterStatus == f;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _filterStatus = f);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF1A2035) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                labels[f]!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? primary
                      : (isDark ? Colors.white60 : Colors.black45),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStats(
      bool isDark, Color primary, List<ProductEntity> products) {
    final active = products.where((p) => p.totalStock > 10).length;
    final lowStock =
        products.where((p) => p.totalStock > 0 && p.totalStock <= 10).length;
    final outOfStock = products.where((p) => p.totalStock == 0).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          _statPill('$active Active', Colors.green, isDark),
          const SizedBox(width: 8),
          _statPill('$lowStock Low', Colors.orange, isDark),
          const SizedBox(width: 8),
          _statPill('$outOfStock Out', Colors.red, isDark),
        ],
      ),
    );
  }

  Widget _statPill(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductEntity p,
    int index,
    bool isDark,
    ThemeState themeState,
  ) {
    final isLowStock = p.totalStock > 0 && p.totalStock <= 10;
    final isOutOfStock = p.totalStock == 0;
    final stockColor = isOutOfStock
        ? Colors.red
        : isLowStock
            ? Colors.orange
            : Colors.green;
    final discount = p.basePrice > p.salePrice
        ? ((p.basePrice - p.salePrice) / p.basePrice * 100).toInt()
        : 0;

    return SpringTouchScale(
      onTap: () => _showProductDetails(context, p, isDark, themeState),
      enableRipple: true,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(
                color: isOutOfStock
                    ? Colors.red.withValues(alpha: 0.4)
                    : isLowStock
                        ? Colors.orange.withValues(alpha: 0.4)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.5)),
                width: isOutOfStock || isLowStock ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Base64Image(
                      imageUrl: p.primaryImage,
                      categoryType: p.categoryType,
                      productTitle: p.title,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (p.isCrockery
                                      ? Colors.purple
                                      : p.isFastFood
                                          ? Colors.orange
                                          : Colors.green)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.isCrockery
                                  ? '🍽️ ${p.categoryName}'
                                  : p.isFastFood
                                      ? '🍔 ${p.categoryName}'
                                      : '🛒 ${p.categoryName}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: p.isCrockery
                                    ? Colors.purple
                                    : p.isFastFood
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                            ),
                          ),
                          if (discount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-$discount%',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.brand.isNotEmpty ? p.brand : 'Generic',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            CurrencyFormatter.format(p.salePrice),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: themeState.palette.primaryColor,
                            ),
                          ),
                          if (p.basePrice > p.salePrice) ...[
                            const SizedBox(width: 6),
                            Text(
                              CurrencyFormatter.format(p.basePrice),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Stock Badge + Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOutOfStock
                            ? 'Out of Stock'
                            : '${p.totalStock} in stock',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: stockColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _iconBtn(Icons.edit_rounded, Colors.blue, () {
                          _showEditPriceDialog(context, p, isDark, themeState);
                        }),
                        const SizedBox(width: 4),
                        _iconBtn(Icons.delete_outline_rounded, Colors.red,
                            () {
                          _confirmDelete(context, p, isDark);
                        }),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (40 * index).ms)
        .slideX(begin: 0.05, duration: 280.ms);
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  // ── Product Detail Sheet ─────────────────────────────────────────────────

  void _showProductDetails(BuildContext context, ProductEntity p, bool isDark,
      ThemeState themeState) {
    final primary = themeState.palette.primaryColor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2035) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white24
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Base64Image(
                                imageUrl: p.primaryImage,
                                categoryType: p.categoryType,
                                productTitle: p.title,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color:
                                          isDark ? Colors.white : Colors.black87,
                                    )),
                                const SizedBox(height: 4),
                                Text(p.brand,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 8),
                                Text(
                                  CurrencyFormatter.format(p.salePrice),
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stats grid
                      Row(
                        children: [
                          _detailStat('⭐ Rating',
                              '${p.rating.toStringAsFixed(1)} (${p.reviewCount})',
                              isDark),
                          const SizedBox(width: 10),
                          _detailStat(
                              '📦 Sold', '${p.soldCount} units', isDark),
                          const SizedBox(width: 10),
                          _detailStat(
                              '🏷️ Stock', '${p.totalStock} left', isDark),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Description
                      Text('Description',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 6),
                      Text(p.description,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54)),
                      const SizedBox(height: 20),

                      // Specs if applicable
                      if (p.isCrockery) ...[
                        _specRow('Material', p.material ?? '—', isDark),
                        _specRow('Pieces', '${p.piecesCount ?? "—"}', isDark),
                        _specRow(
                            'Microwave Safe',
                            p.isMicrowaveSafe == true ? '✅ Yes' : '❌ No',
                            isDark),
                        _specRow(
                            'Dishwasher Safe',
                            p.isDishwasherSafe == true ? '✅ Yes' : '❌ No',
                            isDark),
                      ] else if (p.isGrocery) ...[
                        _specRow('Weight / Volume',
                            p.weightVolume ?? '—', isDark),
                        if (p.dietaryFlags?.isNotEmpty == true)
                          _specRow(
                              'Dietary',
                              p.dietaryFlags!.join(', '),
                              isDark),
                      ] else if (p.isFastFood) ...[
                        _specRow('Restaurant',
                            p.restaurantName ?? '—', isDark),
                        _specRow('Cuisine', p.cuisineType ?? '—', isDark),
                        _specRow(
                            'Prep Time',
                            '${p.preparationTimeMinutes ?? "—"} min',
                            isDark),
                      ],
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Edit Price'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showEditPriceDialog(
                                    context, p, isDark, themeState);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMedium)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.inventory_2_rounded,
                                  size: 16),
                              label: const Text('Adjust Stock'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showStockDialog(
                                    context, p, isDark, themeState);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMedium)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailStat(String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0D1117)
              : const Color(0xFFF8FAFC),
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusSmall),
          border: Border.all(
              color: isDark
                  ? const Color(0xFF2D3748)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _specRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  // ── Edit Price Dialog ───────────────────────────────────────────────────

  void _showEditPriceDialog(BuildContext context, ProductEntity p, bool isDark,
      ThemeState themeState) {
    final primary = themeState.palette.primaryColor;
    final basePriceController =
        TextEditingController(text: p.basePrice.toStringAsFixed(0));
    final salePriceController =
        TextEditingController(text: p.salePrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final base =
              double.tryParse(basePriceController.text) ?? p.basePrice;
          final sale =
              double.tryParse(salePriceController.text) ?? p.salePrice;
          final discount = base > sale && base > 0
              ? ((base - sale) / base * 100).toInt()
              : 0;

          return AlertDialog(
            backgroundColor:
                isDark ? const Color(0xFF1A2035) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLarge)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Pricing',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(p.title,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogTextField(
                  'MRP / Base Price (Rs.)',
                  basePriceController,
                  isDark,
                  primary,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 14),
                _dialogTextField(
                  'Sale / Discounted Price (Rs.)',
                  salePriceController,
                  isDark,
                  primary,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (discount > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer_rounded,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '$discount% discount — customer saves Rs. ${(base - sale).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final base = double.tryParse(basePriceController.text);
                  final sale = double.tryParse(salePriceController.text);
                  if (base == null || base <= 0) return;
                  final effectiveSale = sale ?? base;
                  await ref
                      .read(sellerControllerProvider.notifier)
                      .updateProduct(p.id, {
                    'basePrice': base,
                    'salePrice': effectiveSale,
                    'discountPercentage': base > effectiveSale
                        ? ((base - effectiveSale) / base * 100).toInt()
                        : 0,
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Price updated successfully ✓'),
                        backgroundColor: Colors.green.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMedium)),
                ),
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Adjust Stock Dialog ──────────────────────────────────────────────────

  void _showStockDialog(BuildContext context, ProductEntity p, bool isDark,
      ThemeState themeState) {
    final primary = themeState.palette.primaryColor;
    int newStock = p.totalStock;
    final stockController =
        TextEditingController(text: p.totalStock.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor:
                isDark ? const Color(0xFF1A2035) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLarge)),
            title: const Text('Adjust Stock',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.title,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black45),
                    maxLines: 2),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: newStock > 0
                          ? () => setDialogState(() {
                                newStock--;
                                stockController.text = '$newStock';
                              })
                          : null,
                      icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 32),
                      color: primary,
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : Colors.black87,
                        ),
                        onChanged: (v) {
                          final val = int.tryParse(v);
                          if (val != null) {
                            setDialogState(() => newStock = val);
                          }
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmall),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmall),
                            borderSide:
                                BorderSide(color: primary, width: 1.5),
                          ),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setDialogState(() {
                        newStock++;
                        stockController.text = '$newStock';
                      }),
                      icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 32),
                      color: primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  newStock == 0
                      ? '⚠️ This will mark product as out of stock'
                      : newStock <= 10
                          ? '⚠️ Low stock warning will be shown'
                          : '✅ Stock level is healthy',
                  style: TextStyle(
                    fontSize: 12,
                    color: newStock == 0
                        ? Colors.red
                        : newStock <= 10
                            ? Colors.orange
                            : Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(sellerControllerProvider.notifier)
                      .updateStock(
                        p.id,
                        p.variants.isNotEmpty
                            ? p.variants.first.id
                            : 'default',
                        newStock,
                      );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Stock updated to $newStock units ✓'),
                        backgroundColor: Colors.green.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMedium)),
                ),
                child: const Text('Update Stock'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Confirm Delete ───────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, ProductEntity p, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2035) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusLarge)),
        icon:
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 48),
        title: const Text('Delete Listing?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '"${p.title}" will be permanently removed from your catalog and will no longer be visible to customers.',
          style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Listing'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(sellerControllerProvider.notifier)
                  .updateProduct(p.id, {'isDeleted': true, 'isApproved': false});
              HapticFeedback.heavyImpact();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${p.title}" removed from catalog.'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _dialogTextField(
    String label,
    TextEditingController controller,
    bool isDark,
    Color primary, {
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black45)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
          ],
          onChanged: onChanged,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0D1117)
                : const Color(0xFFF8FAFC),
            prefixText: 'Rs. ',
            prefixStyle: TextStyle(color: primary, fontWeight: FontWeight.bold),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusSmall),
              borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF2D3748)
                      : const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusSmall),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
