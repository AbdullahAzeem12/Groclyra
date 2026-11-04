import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/core/utils/date_time_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/gradient_card.dart';
import 'package:groclyra/features/customer/orders/presentation/controllers/orders_controller.dart';

class OrdersHistoryScreen extends ConsumerWidget {
  const OrdersHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final ordersState = ref.watch(ordersControllerProvider);

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'My Orders & Purchases',
        subtitle: 'Track live status, milestones & delivery OTPs',
        showThemePicker: false,
      ),
      body: ordersState.orders.isEmpty
          ? EmptyStateView(
              title: 'No Orders Yet',
              description: 'You haven\'t placed any orders yet. Explore our marketplace to start shopping!',
              icon: Icons.receipt_long_outlined,
              actionButtonText: 'Browse Catalog',
              onAction: () => context.go(RouteNames.customerHome),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(ordersControllerProvider.notifier).loadOrders(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: ordersState.orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = ordersState.orders[index];
                  return GradientCard(
                    onTap: () => context.push('${RouteNames.customerTracking}/${order.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Order #${order.orderNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: order.status.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                              ),
                              child: Text(
                                order.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: order.status.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Date & Sub-order count
                        Text(
                          'Placed on ${DateTimeFormatter.formatFull(order.createdAt)} • ${order.subOrders.length} Vendors',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Divider(height: 16),

                        // Delivery OTP & Total Amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.pin_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Delivery OTP: ${order.customerOtp}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                CurrencyFormatter.format(order.totalAmount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: themeState.palette.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Track Order Action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Live GPS Tracking & Details',
                              style: TextStyle(
                                color: themeState.palette.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: themeState.palette.primaryColor),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
