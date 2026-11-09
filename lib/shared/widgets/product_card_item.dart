// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'base64_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../features/catalog/domain/entities/product_entity.dart';
import '../../../features/customer/cart/presentation/controllers/cart_controller.dart';
import '../animations/spring_touch_scale.dart';
import 'shimmer_loading.dart';

import 'package:go_router/go_router.dart';
import '../../../routing/route_names.dart';
import 'app_toggle_message.dart';

class ProductCardItem extends ConsumerWidget {
  final ProductEntity product;
  final VoidCallback? onTap;

  const ProductCardItem({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accentColor = product.isFastFood
        ? (product.restaurantType == 'bakery'
            ? const Color(0xFFE91E8C)
            : const Color(0xFFFF6B35))
        : product.isDairyBakery
            ? const Color(0xFF10B981)
            : product.isCrockery
                ? const Color(0xFF8B5CF6)
                : themeState.palette.primaryColor;

    return SpringTouchScale(
      onTap: onTap ?? () => context.push('${RouteNames.customerProductDetails}/${product.id}', extra: product),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161C28) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section — Expanded lets the image fill the remaining
            // vertical space after the fixed-height content block, so the
            // card never overflows regardless of grid cell size or screen width.
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusMedium),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Base64Image(
                      imageUrl: product.primaryImage,
                      categoryType: product.categoryType,
                      productTitle: product.title,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),

                    // Responsive Badges Top Row (Never overlaps or overflows)
                    Positioned(
                      top: 6,
                      left: 6,
                      right: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Category Tag
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: (product.isDairyBakery
                                        ? const Color(0xFF10B981)
                                        : product.isFastFood
                                            ? (product.restaurantType == 'bakery' ? const Color(0xFFE91E8C) : const Color(0xFFFF6B35))
                                            : product.isCrockery
                                                ? AppColors.crockeryPill
                                                : AppColors.groceryPill)
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                product.isDairyBakery
                                    ? 'Dairy & Bakery'
                                    : product.isFastFood
                                        ? (product.restaurantType == 'bakery' ? 'Bakery' : 'Fast Food')
                                        : product.isCrockery
                                            ? 'Crockery'
                                            : 'Grocery',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          // Top-Right Badges: Vegetarian + Discount
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (product.isVegetarian == true) ...[
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                  ),
                                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 9),
                                ),
                                const SizedBox(width: 3),
                              ],
                              if (product.discountPercentage > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    gradient: themeState.palette.linearGradient,
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                  ),
                                  child: Text(
                                    '-${product.discountPercentage}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Area
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Specs Tag (e.g. Bone China, 5 kg, or Restaurant Name)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.isFastFood
                          ? (product.restaurantName ?? product.cuisineType ?? 'Fast Food')
                          : product.isDairyBakery
                              ? (product.subcategoryName ?? product.weightVolume ?? 'Dairy & Bakery')
                              : product.isCrockery
                                  ? (product.material ?? '${product.piecesCount ?? 1} Pcs')
                                  : (product.weightVolume ?? 'Food Staples'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Rating & Reviews / Preparation Time (Bounded to prevent right overflow)
                  Row(
                    children: [
                      if (product.preparationTimeMinutes != null && product.preparationTimeMinutes! > 0) ...[
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(
                          '${product.preparationTimeMinutes}m',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 5),
                      ],
                      if (product.rating > 0 && product.reviewCount > 0) ...[
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '(${product.reviewCount} rev)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ] else if (product.isLiveSynced) ...[
                        const Icon(Icons.sync_rounded, color: Color(0xFF00B4D8), size: 13),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            product.sourceType == 'open_food_facts' ? 'Verified Catalog' : 'Mart Synced',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF00B4D8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: Text(
                            product.soldCount > 0 ? '${product.soldCount} sold' : 'Direct Seller',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Price & Quick Add Button (Bounded to prevent right overflow)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                CurrencyFormatter.format(product.salePrice),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: themeState.palette.primaryColor,
                                ),
                              ),
                            ),
                            if (product.discountPercentage > 0)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(product.basePrice),
                                  style: TextStyle(
                                    fontSize: 10,
                                    decoration: TextDecoration.lineThrough,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Quick Add to Cart Button
                      SpringTouchScale(
                        onTap: () {
                          ref.read(cartControllerProvider.notifier).addItem(product: product);
                          AppToggleMessage.cart(
                            context,
                            title: product.title,
                            price: CurrencyFormatter.format(product.salePrice),
                            onAction: () => context.go(RouteNames.customerCart),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: themeState.palette.linearGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: themeState.palette.primaryColor.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 15),
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
