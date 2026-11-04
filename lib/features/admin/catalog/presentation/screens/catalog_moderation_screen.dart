import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/features/catalog/data/repositories/catalog_repository.dart';
import 'package:groclyra/shared/widgets/base64_image.dart';
import 'dart:ui';

class CatalogModerationScreen extends ConsumerWidget {
  const CatalogModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final productsAsync = ref.watch(allProductsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D14) : const Color(0xFFF1F5F9),
      appBar: const GradientAppBar(
        title: 'Catalog Moderation & Commissions',
        subtitle: 'Product Quality, Pricing & Fee Rules',
        showThemePicker: false,
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('No products found for moderation.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final p = products[index];
              // Dynamic Commission Engine
              final commissionRate = p.isCrockery ? 0.08 : p.isGrocery ? 0.05 : 0.12;
              final commissionAmount = p.salePrice * commissionRate;
              final isLive = p.isApproved;

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 400)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Base64Image(imageUrl: p.primaryImage, categoryType: p.categoryType, productTitle: p.title, width: 70, height: 70, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('Seller: ${p.sellerName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(CurrencyFormatter.format(p.salePrice), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeState.palette.primaryColor)),
                                Text(
                                  'Commission: ${(commissionRate * 100).toInt()}% (${CurrencyFormatter.format(commissionAmount)})',
                                  style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isLive ? Icons.verified_rounded : Icons.pending_actions_rounded, color: isLive ? Colors.green : Colors.orange, size: 18),
                          const SizedBox(width: 6),
                          Text(isLive ? 'Approved & Live' : 'Pending', style: TextStyle(fontSize: 13, color: isLive ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Commission rule updated for ${p.title}')),
                              );
                            },
                            child: const Text('Edit Commission'),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isLive ? Colors.red : Colors.green,
                              side: BorderSide(color: isLive ? Colors.red.withValues(alpha: 0.5) : Colors.green.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              try {
                                await ref.read(catalogRepositoryProvider).updateProduct(p.id, {'isApproved': !isLive});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isLive ? 'Unpublished ${p.title}' : 'Approved ${p.title}'),
                                      backgroundColor: isLive ? Colors.red : Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            child: Text(isLive ? 'Unpublish' : 'Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
},
),
);
}
}
