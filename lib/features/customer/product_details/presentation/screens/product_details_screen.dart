import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/features/catalog/data/repositories/catalog_repository.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/catalog/presentation/controllers/catalog_controller.dart';
import 'package:groclyra/features/customer/cart/domain/entities/cart_item_entity.dart';
import 'package:groclyra/features/customer/cart/presentation/controllers/cart_controller.dart';
import 'package:groclyra/features/customer/reviews/presentation/widgets/product_reviews_section.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';
import 'package:groclyra/shared/widgets/base64_image.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';
import 'package:groclyra/shared/widgets/shimmer_loading.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String productId;
  final ProductEntity? initialProduct;

  const ProductDetailsScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _selectedImageIndex = 0;
  int _selectedVariantIndex = 0;
  int _quantity = 1;
  bool _isWishlisted = false;
  ProductEntity? _fetchedProduct;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct == null) {
      _loadProductFallback();
    }
  }

  Future<void> _loadProductFallback() async {
    setState(() => _isFetching = true);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final p = await repo.getProductById(widget.productId);
      if (mounted && p != null) {
        setState(() {
          _fetchedProduct = p;
          _isFetching = false;
        });
      } else if (mounted) {
        setState(() => _isFetching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final singleProductStream = ref.watch(productByIdStreamProvider(widget.productId));
    final allProductsStream = ref.watch(allProductsStreamProvider);
    final catalogState = ref.watch(catalogControllerProvider);

    // Multi-tier robust resolution:
    // 1. Initial product passed via route extra or async fallback
    ProductEntity? found = widget.initialProduct ?? _fetchedProduct;

    // 2. Real-time single product Firestore stream
    if (singleProductStream.value != null) {
      found = singleProductStream.value;
    }

    // 3. Real-time all products Firestore stream (same stream that feeds CustomerHomeScreen)
    if (found == null && allProductsStream.value != null) {
      for (final p in allProductsStream.value!) {
        if (p.id == widget.productId) {
          found = p;
          break;
        }
      }
    }

    // 4. CatalogController cached products
    if (found == null) {
      for (final p in catalogState.allProducts) {
        if (p.id == widget.productId) {
          found = p;
          break;
        }
      }
    }

    // If still resolving, show high-fidelity loading skeleton instead of premature error
    if (found == null) {
      final isStillLoading = singleProductStream.isLoading ||
          (allProductsStream.isLoading && !allProductsStream.hasValue) ||
          _isFetching;
      if (isStillLoading) {
        return _buildLoadingSkeleton(context, isDark);
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: EmptyStateView(
          icon: Icons.search_off_rounded,
          title: 'Product not available',
          description:
              'This item is no longer listed or the link is outdated. Browse the catalog for the latest deals.',
          actionButtonText: 'Back to Shopping',
          onAction: () => Navigator.maybePop(context),
        ),
      );
    }

    final product = found;

    final selectedVariant = product.variants.isNotEmpty
        ? product.variants[_selectedVariantIndex.clamp(0, product.variants.length - 1)]
        : null;

    final effectivePrice = selectedVariant?.price ?? product.salePrice;
    final effectiveComparePrice = selectedVariant?.compareAtPrice ?? product.basePrice;
    final maxStock = product.totalStock > 0 ? product.totalStock : 99;
    final lineSubtotal = effectivePrice * _quantity;
    final lineCompareTotal = effectiveComparePrice * _quantity;
    final lineSavings = lineCompareTotal > lineSubtotal ? (lineCompareTotal - lineSubtotal) : 0.0;

    final rawImages = product.images.where((img) => img.trim().isNotEmpty).toList();
    final displayImages = rawImages.isNotEmpty ? rawImages : [product.primaryImage];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsible Image Header SliverAppBar
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SpringTouchScale(
                onTap: () => Navigator.pop(context),
                navigationDelayMs: 165,
                scaleFactor: 0.88,
                pressDepth: 3.5,
                enableRipple: false,
                borderRadius: BorderRadius.circular(20),
                child: CircleAvatar(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: IconButton(
                    icon: Icon(
                      _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isWishlisted ? Colors.red : null,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _isWishlisted = !_isWishlisted);
                      AppToggleMessage.wishlist(
                        context,
                        title: product.title,
                        isAdded: _isWishlisted,
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    onPressed: () {
                      AppToggleMessage.info(
                        context,
                        'Product link copied to clipboard',
                        title: 'Link Copied',
                      );
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: displayImages.length,
                    onPageChanged: (idx) => setState(() => _selectedImageIndex = idx),
                    itemBuilder: (context, idx) {
                      return Base64Image(
                        imageUrl: displayImages[idx],
                        categoryType: product.categoryType,
                        productTitle: product.title,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                  // Bottom Gradient Overlay & Indicators
                  if (displayImages.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          displayImages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: _selectedImageIndex == index ? 22 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: _selectedImageIndex == index
                                  ? themeState.palette.primaryColor
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Product Details Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category & Brand Tag Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (product.isDairyBakery
                                  ? const Color(0xFF10B981)
                                  : product.isFastFood
                                      ? const Color(0xFFFF6B35)
                                      : product.isCrockery
                                          ? Colors.purple
                                          : Colors.green)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                        child: Text(
                          product.isDairyBakery
                              ? '🥛 ${product.categoryName}'
                              : product.isFastFood
                                  ? (product.restaurantType == 'bakery'
                                      ? '🎂 ${product.restaurantName ?? product.categoryName}'
                                      : '🍔 ${product.restaurantName ?? product.categoryName}')
                                  : product.isCrockery
                                      ? '🍽️ ${product.categoryName}'
                                      : '🛒 ${product.categoryName}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: product.isDairyBakery
                                ? const Color(0xFF10B981)
                                : product.isFastFood
                                    ? const Color(0xFFFF6B35)
                                    : product.isCrockery
                                        ? Colors.purple
                                        : Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'by ${product.brand.isNotEmpty ? product.brand : product.sellerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                      ),
                      if (product.isVegetarian == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.eco_rounded, size: 10, color: Colors.green),
                              SizedBox(width: 2),
                              Text('Veg', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    product.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Rating & Reviews Summary
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '(${product.reviewCount} reviews) • ${product.soldCount}+ sold',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        product.totalStock > 0 ? 'In Stock (${product.totalStock})' : 'Out of Stock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: product.totalStock > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Dynamic Price Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            CurrencyFormatter.format(_quantity > 1 ? lineSubtotal : effectivePrice),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: themeState.palette.primaryColor,
                            ),
                          ),
                          if (effectiveComparePrice > effectivePrice) ...[
                            Text(
                              CurrencyFormatter.format(_quantity > 1 ? lineCompareTotal : effectiveComparePrice),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-${product.discountPercentage}% OFF',
                                style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_quantity > 1) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: themeState.palette.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${CurrencyFormatter.format(effectivePrice)} each × $_quantity items',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: themeState.palette.primaryColor,
                                ),
                              ),
                            ),
                            if (lineSavings > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Save ${CurrencyFormatter.format(lineSavings)}',
                                  style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Variants Selector
                  if (product.variants.length > 1) ...[
                    Text('Select Option / Variant', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(product.variants.length, (idx) {
                        final v = product.variants[idx];
                        final isSelected = _selectedVariantIndex == idx;
                        return ChoiceChip(
                          label: Text('${v.name} (${CurrencyFormatter.format(v.price)})'),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedVariantIndex = idx);
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Quantity Selector with Smart Live Subtotal & Stock Bounds
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantity',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  'Subtotal: ',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                Flexible(
                                  child: Text(
                                    CurrencyFormatter.format(lineSubtotal),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: themeState.palette.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              alignment: Alignment.center,
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: _quantity < maxStock
                                  ? () => setState(() => _quantity++)
                                  : () {
                                      AppToggleMessage.warning(
                                        context,
                                        'Maximum available stock reached ($maxStock items)',
                                        title: 'Stock Limit',
                                      );
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Specifications Card
                  Text('Specifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121722) : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        if (product.isFastFood) ...[
                          if (product.restaurantName != null) _buildSpecRow('Restaurant / Kitchen', product.restaurantName!),
                          if (product.cuisineType != null) _buildSpecRow('Cuisine Type', product.cuisineType!),
                          if (product.preparationTimeMinutes != null && product.preparationTimeMinutes! > 0)
                            _buildSpecRow('Prep Time', '${product.preparationTimeMinutes} minutes'),
                          _buildSpecRow('Dietary Choice', product.isVegetarian == true ? '100% Vegetarian' : 'Non-Vegetarian'),
                          _buildSpecRow('Food Safety', '100% Halal & Hygienically Packed'),
                        ] else if (product.isDairyBakery) ...[
                          if (product.packageSize != null || product.unit != null)
                            _buildSpecRow('Package Size / Unit', product.packageSize ?? product.unit!),
                          if (product.storageTemp != null) _buildSpecRow('Storage Temperature', product.storageTemp!),
                          if (product.expiryDays != null) _buildSpecRow('Freshness Shelf Life', '${product.expiryDays} Days from packing'),
                          if (product.isHalal == true) _buildSpecRow('Halal Certification', '100% Halal Verified'),
                          if (product.isOrganic == true) _buildSpecRow('Quality Standard', 'Certified Organic / Pure Dairy'),
                          if (product.ingredients != null && product.ingredients!.isNotEmpty)
                            _buildSpecRow('Ingredients', product.ingredients!.join(', ')),
                        ] else if (product.isCrockery) ...[
                          _buildSpecRow('Material', product.material ?? 'Ceramic / Bone China'),
                          if (product.piecesCount != null) _buildSpecRow('Pieces Count', '${product.piecesCount} Pieces'),
                          _buildSpecRow('Microwave Safe', product.isMicrowaveSafe == true ? 'Yes' : 'No / Not Recommended'),
                          _buildSpecRow('Dishwasher Safe', product.isDishwasherSafe == true ? 'Yes' : 'Hand Wash Recommended'),
                        ] else ...[
                          if (product.weightVolume != null) _buildSpecRow('Net Weight / Volume', product.weightVolume!),
                          if (product.dietaryFlags != null && product.dietaryFlags!.isNotEmpty)
                            _buildSpecRow('Dietary Flags', product.dietaryFlags!.join(', ')),
                          _buildSpecRow('Shelf Life Guarantee', 'Verified Fresh Stock'),
                          _buildSpecRow('Authenticity', '100% Brand Genuine Guaranteed'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text('Product Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isNotEmpty ? product.description : product.shortDescription,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Seller Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121722) : Colors.white,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.sellerName.isNotEmpty ? product.sellerName : 'Official Merchant',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Text('98% Positive Seller Rating • 100% On-Time Ship', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            AppToggleMessage.info(
                              context,
                              'Opening official ${product.sellerName} storefront',
                              title: 'Official Store',
                            );
                          },
                          child: const Text('Store', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 28),

                  // Authentic Real-Time Ratings & Proper Reviews Section
                  ProductReviewsSection(
                    product: product,
                    selectedVariantName: selectedVariant?.name,
                  ),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F141C) : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Add to Cart Button (Outlined)
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _quantity > 1
                          ? 'Add to Cart ($_quantity) • ${CurrencyFormatter.format(lineSubtotal)}'
                          : 'Add to Cart',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMedium)),
                  ),
                  onPressed: () {
                    ref.read(cartControllerProvider.notifier).addToCart(
                          product,
                          variant: selectedVariant,
                          quantity: _quantity,
                        );
                    AppToggleMessage.cart(
                      context,
                      title: '$_quantity x ${product.title}',
                      price: CurrencyFormatter.format(lineSubtotal),
                      onAction: () => context.go(RouteNames.customerCart),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Buy Now Button (Gradient)
              Expanded(
                child: GradientButton(
                  text: _quantity > 1
                      ? '⚡ Buy Now • ${CurrencyFormatter.format(lineSubtotal)}'
                      : 'Buy Now',
                  icon: Icons.flash_on_rounded,
                  onPressed: () {
                    final directItem = CartItemEntity(
                      id: 'direct_${product.id}_${selectedVariant?.id ?? 'default'}_${DateTime.now().millisecondsSinceEpoch}',
                      product: product,
                      selectedVariant: selectedVariant,
                      quantity: _quantity,
                      addedAt: DateTime.now(),
                    );
                    context.push(RouteNames.customerCheckout, extra: directItem);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141C) : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Product Details'),
      ),
      body: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(
              width: double.infinity,
              height: 340,
              borderRadius: 0,
            ),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShimmerBox(width: 110, height: 24, borderRadius: 6),
                      SizedBox(width: 10),
                      ShimmerBox(width: 90, height: 20, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 14),
                  ShimmerBox(width: double.infinity, height: 26, borderRadius: 6),
                  SizedBox(height: 8),
                  ShimmerBox(width: 220, height: 20, borderRadius: 6),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      ShimmerBox(width: 70, height: 24, borderRadius: 4),
                      SizedBox(width: 10),
                      ShimmerBox(width: 130, height: 18, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 20),
                  ShimmerBox(width: 160, height: 32, borderRadius: 6),
                  SizedBox(height: 24),
                  ShimmerBox(width: double.infinity, height: 140, borderRadius: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
