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
import '../animations/rotating_border_glow_card.dart';

class ProductCardItem extends ConsumerStatefulWidget {
  final ProductEntity product;
  final VoidCallback? onTap;

  const ProductCardItem({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  ConsumerState<ProductCardItem> createState() => _ProductCardItemState();
}

class _ProductCardItemState extends ConsumerState<ProductCardItem> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoryGlowColor = widget.product.isFastFood
        ? (widget.product.restaurantType == 'bakery'
            ? const Color(0xFFE91E8C)
            : const Color(0xFFFF6B35))
        : widget.product.isDairyBakery
            ? const Color(0xFF10B981)
            : widget.product.isCrockery
                ? const Color(0xFF8B5CF6)
                : themeState.palette.primaryColor;

    final categoryGlowSecondary = widget.product.isFastFood
        ? (widget.product.restaurantType == 'bakery'
            ? const Color(0xFFFF60A8)
            : const Color(0xFFFFB03A))
        : widget.product.isDairyBakery
            ? const Color(0xFF34D399)
            : widget.product.isCrockery
                ? const Color(0xFFEC4899)
                : themeState.palette.secondaryColor;

    return SpringTouchScale(
      onTap: widget.onTap ?? () => context.push('${RouteNames.customerProductDetails}/${widget.product.id}', extra: widget.product),
      child: RotatingBorderGlowCard(
        rotateController: _glowController,
        color: categoryGlowColor.withValues(alpha: 0.65),
        secondaryColor: categoryGlowSecondary,
        phaseOffset: (widget.product.hashCode % 100) / 100.0,
        isDark: isDark,
        borderRadius: AppDimensions.radiusMedium,
        child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121722) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
                      imageUrl: widget.product.primaryImage,
                      categoryType: widget.product.categoryType,
                      productTitle: widget.product.title,
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
                                color: (widget.product.isDairyBakery
                                        ? const Color(0xFF10B981)
                                        : widget.product.isFastFood
                                            ? (widget.product.restaurantType == 'bakery' ? const Color(0xFFE91E8C) : const Color(0xFFFF6B35))
                                            : widget.product.isCrockery
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
                                widget.product.isDairyBakery
                                    ? '🥛 Dairy & Bakery'
                                    : widget.product.isFastFood
                                        ? (widget.product.restaurantType == 'bakery' ? '🧁 Bakery' : '🍔 Fast Food')
                                        : widget.product.isCrockery
                                            ? '🍽️ Crockery'
                                            : '🛒 Grocery',
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
                              if (widget.product.isVegetarian == true) ...[
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
                              if (widget.product.discountPercentage > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    gradient: themeState.palette.linearGradient,
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                  ),
                                  child: Text(
                                    '-${widget.product.discountPercentage}%',
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
                      color: categoryGlowColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.product.isFastFood
                          ? (widget.product.restaurantName ?? widget.product.cuisineType ?? 'Fast Food')
                          : widget.product.isDairyBakery
                              ? (widget.product.subcategoryName ?? widget.product.weightVolume ?? 'Dairy & Bakery')
                              : widget.product.isCrockery
                                  ? (widget.product.material ?? '${widget.product.piecesCount ?? 1} Pcs')
                                  : (widget.product.weightVolume ?? 'Food Staples'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: categoryGlowColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    widget.product.title,
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
                      if (widget.product.preparationTimeMinutes != null && widget.product.preparationTimeMinutes! > 0) ...[
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.product.preparationTimeMinutes}m',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 5),
                      ],
                      if (widget.product.rating > 0 && widget.product.reviewCount > 0) ...[
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          widget.product.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '(${widget.product.reviewCount} rev)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ] else if (widget.product.isLiveSynced) ...[
                        const Icon(Icons.sync_rounded, color: Color(0xFF00B4D8), size: 13),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            widget.product.sourceType == 'open_food_facts' ? 'Verified Catalog' : 'Mart Synced',
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
                            widget.product.soldCount > 0 ? '${widget.product.soldCount} sold' : 'Direct Seller',
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
                                CurrencyFormatter.format(widget.product.salePrice),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: themeState.palette.primaryColor,
                                ),
                              ),
                            ),
                            if (widget.product.discountPercentage > 0)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(widget.product.basePrice),
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
                          ref.read(cartControllerProvider.notifier).addItem(product: widget.product);
                          AppToggleMessage.cart(
                            context,
                            title: widget.product.title,
                            price: CurrencyFormatter.format(widget.product.salePrice),
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
    ),
    );
  }
}
