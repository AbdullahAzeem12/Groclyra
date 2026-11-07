import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/gradient_card.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';
import 'package:groclyra/shared/widgets/base64_image.dart';
import 'package:groclyra/features/seller/presentation/controllers/seller_controller.dart';
import 'package:groclyra/shared/animations/rotating_border_glow_card.dart';

class SellerDashboardScreen extends ConsumerStatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  ConsumerState<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends ConsumerState<SellerDashboardScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _glowRotateController;

  @override
  void initState() {
    super.initState();
    _glowRotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _glowRotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final sellerState = ref.watch(sellerControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final store = sellerState.store;
    
    final double todayRevenue = (sellerState.stats['todayRevenue'] as num?)?.toDouble() ?? store?.todayRevenue ?? 0.0;
    final int pendingOrders = (sellerState.stats['totalOrders'] as num?)?.toInt() ?? store?.totalOrders ?? 0;
    final int lowStockCount = sellerState.products.where((p) => p.totalStock <= 10).length;

    return Scaffold(
      appBar: GradientAppBar(
        title: store?.storeName ?? 'Seller Partner Center',
        subtitle: store?.isKycApproved == true
            ? 'KYC Verified Merchant • ${store?.rating.toStringAsFixed(1)} ★ Rating'
            : 'Unverified Merchant • ${store?.rating.toStringAsFixed(1)} ★ Rating',
        // Phase 1B: real-time notification centre
        showNotificationBell: true,
        actions: [
          IconButton(
            tooltip: 'Store Profile',
            icon: const Icon(Icons.storefront_rounded, color: Colors.white),
            onPressed: () => context.push(RouteNames.sellerStore),
          ),
          IconButton(
            tooltip: 'Switch Portal',
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            onPressed: () => context.push(RouteNames.login),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(sellerControllerProvider.notifier).loadSellerData(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Metric Cards Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: "Today's GMV",
                      value: CurrencyFormatter.format(todayRevenue),
                      icon: Icons.payments_rounded,
                      color: Colors.green,
                      isDark: isDark,
                      onTap: () => _showRevenueBreakdown(context, todayRevenue, isDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Pending Orders',
                      value: '$pendingOrders Orders',
                      icon: Icons.pending_actions_rounded,
                      color: Colors.orange,
                      isDark: isDark,
                      onTap: () => _showOrdersBreakdown(context, pendingOrders, isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Live Catalog',
                      value: '${sellerState.products.length} Items',
                      icon: Icons.inventory_2_rounded,
                      color: Colors.indigo,
                      isDark: isDark,
                      onTap: () => context.go(RouteNames.sellerProducts),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Low Stock Alert',
                      value: '$lowStockCount SKUs',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      isDark: isDark,
                      onTap: () => context.go(RouteNames.sellerInventory),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons
              SpringTouchScale(
                onTap: () => context.push(RouteNames.sellerAddProduct),
                child: GradientButton(
                  text: '+ Create New Product Listing',
                  icon: Icons.add_circle_outline_rounded,
                  onPressed: () {}, // Handled by SpringTouchScale
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
              const SizedBox(height: 24),

              // Payout Balance Card
              SpringTouchScale(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payout portal syncing real-time...')),
                  );
                },
                enableRipple: true,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                child: GradientCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: themeState.palette.subtleGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded, color: themeState.palette.primaryColor, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Available Payout Balance', style: TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                CurrencyFormatter.format(store?.pendingPayout ?? 0.0),
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeState.palette.primaryColor),
                              ),
                            ),
                            const Text('Next auto-settlement: Monday', style: TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payout requested successfully')),
                          );
                        },
                        child: const Text('Withdraw', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1).shimmer(duration: 2000.ms, delay: 1000.ms),
              const SizedBox(height: 24),

              // Quick Catalog Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('My Active Listings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => context.go(RouteNames.sellerProducts),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...sellerState.products.take(3).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final p = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121722) : Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Base64Image(imageUrl: p.primaryImage, categoryType: p.categoryType, productTitle: p.title, width: 50, height: 50, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(CurrencyFormatter.format(p.salePrice), style: TextStyle(color: themeState.palette.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.totalStock > 10 ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${p.totalStock} in stock',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: p.totalStock > 10 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (300 + (index * 100)).ms).slideX(begin: 0.1);
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return SpringTouchScale(
      onTap: onTap,
      enableRipple: true,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: RotatingBorderGlowCard(
        rotateController: _glowRotateController,
        color: color,
        secondaryColor: Colors.white,
        phaseOffset: 0.0,
        isDark: isDark,
        borderRadius: AppDimensions.radiusMedium,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121722) : Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack).fadeIn(duration: 300.ms),
    );
  }

  void _showRevenueBreakdown(BuildContext context, double todayRevenue, bool isDark) {
    final double commission = todayRevenue * 0.10; // 10% marketplace commission
    final double netRevenue = todayRevenue - commission;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.insights_rounded, size: 48, color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          'Seller Revenue Breakdown',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Based on real-time connected data sync.',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildBreakdownRow('Total Sales (GMV)', todayRevenue, isDark, isPositive: true),
                        _buildBreakdownRow('Marketplace Commission (10%)', commission, isDark, isPositive: false),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
                        _buildBreakdownRow('Net Payout Revenue', netRevenue, isDark, isTotal: true, color: Colors.greenAccent),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showOrdersBreakdown(BuildContext context, int pendingOrders, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 48, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text(
                          'Order Lifecycle & Sync',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Based on real-time connected data sync.',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pending Fulfillment',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '$pendingOrders',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                               Navigator.of(ctx).pop();
                               context.go(RouteNames.sellerOrders);
                            },
                            child: const Text('View All Orders', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBreakdownRow(String label, double value, bool isDark, {bool isPositive = true, bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            '${isPositive ? '' : '- '}PKR ${value.toStringAsFixed(0)}',
            style: TextStyle(
              color: color ?? (isTotal
                  ? Colors.greenAccent
                  : (isPositive ? (isDark ? Colors.white : Colors.black87) : Colors.redAccent)),
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
