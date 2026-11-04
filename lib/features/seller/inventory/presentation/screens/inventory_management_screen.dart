import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/base64_image.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/seller/presentation/controllers/seller_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/routing/route_names.dart';

class InventoryManagementScreen extends ConsumerStatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  ConsumerState<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState
    extends ConsumerState<InventoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, bool> _savingMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final sellerState = ref.watch(sellerControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = themeState.palette.primaryColor;
    final products = sellerState.products;

    final critical = products.where((p) => p.totalStock == 0).toList();
    final low = products
        .where((p) => p.totalStock > 0 && p.totalStock <= 10)
        .toList();
    final healthy = products.where((p) => p.totalStock > 10).toList();

    // Inventory value
    final totalValue = products.fold<double>(
        0, (sum, p) => sum + (p.salePrice * p.totalStock));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RouteNames.sellerDashboard);
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        appBar: GradientAppBar(
          title: 'Inventory Control',
          subtitle: '${products.length} SKUs • ${CurrencyFormatter.format(totalValue)} Value',
          showThemePicker: false,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
            tabs: [
              Tab(
                  child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('❌ '),
                  Text('Out (${critical.length})'),
                ],
              )),
              Tab(
                  child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚠️ '),
                  Text('Low (${low.length})'),
                ],
              )),
              Tab(
                  child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✅ '),
                  Text('OK (${healthy.length})'),
                ],
              )),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Summary Banner ────────────────────────────────────────────
            _buildSummaryBanner(isDark, primary, critical.length, low.length,
                healthy.length, totalValue),

            // ── Tab Content ───────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInventoryList(critical, isDark, primary,
                      emptyMsg: 'No out-of-stock products! 🎉',
                      highlightColor: Colors.red),
                  _buildInventoryList(low, isDark, primary,
                      emptyMsg: 'No low-stock products!',
                      highlightColor: Colors.orange),
                  _buildInventoryList(healthy, isDark, primary,
                      emptyMsg: 'No healthy-stock products found.',
                      highlightColor: Colors.green),
                ],
              ),
            ),
          ],
        ),
        // Bulk restock FAB for critical
        floatingActionButton: critical.isNotEmpty
            ? FloatingActionButton.extended(
                backgroundColor: Colors.red.shade700,
                icon: const Icon(Icons.replay_rounded, color: Colors.white),
                label: const Text('Bulk Restock Out-of-Stock',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () =>
                    _showBulkRestockDialog(context, critical, isDark, primary),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.4)
            : null,
      ),
    );
  }

  Widget _buildSummaryBanner(bool isDark, Color primary, int critical, int low,
      int healthy, double totalValue) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.08),
            primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
            color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bannerStat('Total Value', CurrencyFormatter.format(totalValue),
              primary),
          Container(
              width: 1,
              height: 36,
              color: primary.withValues(alpha: 0.2)),
          _bannerStat('Critical', '$critical SKUs', Colors.red),
          Container(
              width: 1,
              height: 36,
              color: primary.withValues(alpha: 0.2)),
          _bannerStat('Low Stock', '$low SKUs', Colors.orange),
        ],
      ),
    );
  }

  Widget _bannerStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _buildInventoryList(
    List<ProductEntity> products,
    bool isDark,
    Color primary, {
    required String emptyMsg,
    required Color highlightColor,
  }) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 56,
                color: highlightColor.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(emptyMsg,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _buildInventoryCard(products[index], index, isDark, primary,
              highlightColor),
    );
  }

  Widget _buildInventoryCard(
    ProductEntity p,
    int index,
    bool isDark,
    Color primary,
    Color highlightColor,
  ) {
    final isSaving = _savingMap[p.id] == true;
    final grossValue = p.salePrice * p.totalStock;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: highlightColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: highlightColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Base64Image(
                    imageUrl: p.primaryImage,
                    categoryType: p.categoryType,
                    productTitle: p.title,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover),
              ),
              if (p.totalStock == 0)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Center(
                        child: Text('OUT',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  p.isCrockery
                      ? 'Material: ${p.material ?? "Ceramic"}'
                      : p.isFastFood
                          ? 'Cuisine: ${p.cuisineType ?? "—"}'
                          : 'Weight: ${p.weightVolume ?? "1 kg"}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  'Inventory Value: ${CurrencyFormatter.format(grossValue)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: highlightColor,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Counter
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: highlightColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${p.totalStock} units',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: highlightColor),
                ),
              ),
              const SizedBox(height: 8),
              if (isSaving)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Row(
                  children: [
                    _counterBtn(
                      Icons.remove_rounded,
                      p.totalStock > 0
                          ? () => _adjustStock(p, p.totalStock - 1)
                          : null,
                      highlightColor,
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showQuickStockInput(context, p, isDark,
                          primary),
                      child: Container(
                        width: 32,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A2035)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${p.totalStock}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _counterBtn(
                      Icons.add_rounded,
                      () => _adjustStock(p, p.totalStock + 1),
                      highlightColor,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (40 * index).ms).slideX(begin: 0.05, duration: 250.ms);
  }

  Widget _counterBtn(IconData icon, VoidCallback? onTap, Color color) {
    return SpringTouchScale(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 14, color: onTap != null ? color : Colors.grey),
      ),
    );
  }

  Future<void> _adjustStock(ProductEntity p, int newStock) async {
    if (newStock < 0) return;
    HapticFeedback.selectionClick();
    setState(() => _savingMap[p.id] = true);
    await ref.read(sellerControllerProvider.notifier).updateStock(
          p.id,
          p.variants.isNotEmpty ? p.variants.first.id : 'default',
          newStock,
        );
    if (mounted) setState(() => _savingMap.remove(p.id));
  }

  void _showQuickStockInput(BuildContext context, ProductEntity p, bool isDark,
      Color primary) {
    final controller =
        TextEditingController(text: p.totalStock.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2035) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusLarge)),
        title: Text('Set Stock — ${p.title}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            suffixText: 'units',
            border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusSmall)),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusSmall),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(controller.text);
              if (val != null) {
                Navigator.pop(ctx);
                await _adjustStock(p, val);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock set to $val units ✓'),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium)),
            ),
            child: const Text('Set Stock'),
          ),
        ],
      ),
    );
  }

  void _showBulkRestockDialog(BuildContext context, List<ProductEntity> items,
      bool isDark, Color primary) {
    final controller = TextEditingController(text: '50');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2035) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusLarge)),
        icon: const Icon(Icons.replay_rounded, color: Colors.red, size: 36),
        title: Text('Bulk Restock ${items.length} Products',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set a uniform stock quantity for all ${items.length} out-of-stock products at once.',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                label: const Text('Units per product'),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSmall)),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(controller.text);
              if (qty == null || qty <= 0) return;
              Navigator.pop(ctx);
              for (final p in items) {
                await ref
                    .read(sellerControllerProvider.notifier)
                    .updateStock(
                      p.id,
                      p.variants.isNotEmpty ? p.variants.first.id : 'default',
                      qty,
                    );
              }
              HapticFeedback.heavyImpact();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${items.length} products restocked to $qty units each ✓'),
                    backgroundColor: Colors.green.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium)),
            ),
            child: const Text('Restock All'),
          ),
        ],
      ),
    );
  }
}
