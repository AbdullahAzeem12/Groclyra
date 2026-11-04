import 'dart:convert';

import 'package:flutter/material.dart';

import '../../features/catalog/domain/entities/category_entity.dart';
import '../../features/catalog/domain/entities/product_entity.dart';

class Base64Image extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final MainCategoryType? categoryType;
  final String? productTitle;
  final String? fallbackUrl;

  const Base64Image({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.categoryType,
    this.productTitle,
    this.fallbackUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();

    // 1. Data URI (Base64)
    if (cleanUrl.startsWith('data:image')) {
      try {
        final commaIndex = cleanUrl.indexOf(',');
        if (commaIndex != -1) {
          final base64String = cleanUrl.substring(commaIndex + 1);
          final bytes = base64Decode(base64String);
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            errorBuilder: (context, error, stackTrace) =>
                _buildStyledPlaceholder(context),
          );
        }
      } catch (e) {
        return _buildStyledPlaceholder(context);
      }
    }

    // 2. Resolve target and smart fallback
    final smartFallback = ProductEntity.getSmartFallbackImageUrl(
      title: productTitle,
      categoryType: categoryType,
    );

    final effectiveUrl = cleanUrl.isNotEmpty
        ? cleanUrl
        : (fallbackUrl?.trim().isNotEmpty == true
              ? fallbackUrl!.trim()
              : smartFallback);

    if (effectiveUrl.isEmpty) {
      return _buildStyledPlaceholder(context);
    }

    // 3. Multi-tier resilient network image
    return Image.network(
      effectiveUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) {
        // Try fallback if primary URL failed
        if (smartFallback.isNotEmpty && smartFallback != effectiveUrl) {
          return Image.network(
            smartFallback,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            errorBuilder: (context, error2, stackTrace2) {
              return _buildStyledPlaceholder(context);
            },
          );
        }
        return _buildStyledPlaceholder(context);
      },
    );
  }

  Widget _buildStyledPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color gradientStart;
    final Color gradientEnd;
    final IconData iconData;

    switch (categoryType) {
      case MainCategoryType.crockery:
        gradientStart = const Color(0xFF8B5CF6);
        gradientEnd = const Color(0xFFEC4899);
        iconData = Icons.dinner_dining_rounded;
        break;
      case MainCategoryType.grocery:
        gradientStart = const Color(0xFFF59E0B);
        gradientEnd = const Color(0xFFEF4444);
        iconData = Icons.shopping_basket_rounded;
        break;
      case MainCategoryType.dairyBakery:
        gradientStart = const Color(0xFF06B6D4);
        gradientEnd = const Color(0xFF3B82F6);
        iconData = Icons.breakfast_dining_rounded;
        break;
      case MainCategoryType.fastFood:
        gradientStart = const Color(0xFFF97316);
        gradientEnd = const Color(0xFFDC2626);
        iconData = Icons.fastfood_rounded;
        break;
      default:
        gradientStart = const Color(0xFF6366F1);
        gradientEnd = const Color(0xFFA855F7);
        iconData = Icons.shopping_bag_rounded;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (height ?? double.infinity);
        final isCompact = availableHeight < 75;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      gradientStart.withValues(alpha: 0.28),
                      gradientEnd.withValues(alpha: 0.16),
                    ]
                  : [
                      gradientStart.withValues(alpha: 0.16),
                      gradientEnd.withValues(alpha: 0.08),
                    ],
            ),
          ),
          child: Center(
            child: isCompact
                ? Icon(
                    iconData,
                    color: isDark ? Colors.white70 : gradientStart,
                    size: availableHeight < 50 ? 18 : 22,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gradientStart.withValues(
                            alpha: isDark ? 0.25 : 0.15,
                          ),
                          border: Border.all(
                            color: gradientStart.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          iconData,
                          color: isDark ? Colors.white70 : gradientStart,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: gradientStart.withValues(
                            alpha: isDark ? 0.3 : 0.15,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          categoryType == MainCategoryType.crockery
                              ? 'Crockery'
                              : categoryType == MainCategoryType.fastFood
                              ? 'Fast Food'
                              : categoryType == MainCategoryType.dairyBakery
                              ? 'Dairy & Bakery'
                              : 'Groclyra',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : gradientStart,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
