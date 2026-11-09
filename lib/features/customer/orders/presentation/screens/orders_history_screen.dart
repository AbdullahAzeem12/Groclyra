import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/services/pdf_invoice_generator.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/core/utils/date_time_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/gradient_card.dart';
import 'package:groclyra/features/customer/orders/presentation/controllers/orders_controller.dart';
import 'package:groclyra/features/customer/orders/domain/entities/order_entity.dart';

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

                        // Action Buttons: Invoice PDF & Live GPS Tracking
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => _showInvoiceOptions(context, order),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.picture_as_pdf_rounded, size: 14, color: themeState.palette.primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tax Invoice (PDF)',
                                      style: TextStyle(
                                        color: themeState.palette.primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Live GPS & Details',
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
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showInvoiceOptions(BuildContext context, OrderEntity order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice #${order.orderNumber}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Official tax receipt • PK-NTN-9482019-3',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: Color(0xFF4F46E5)),
                  title: const Text('Download & Share PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Share invoice via WhatsApp, Email, or Save to Device', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    PdfInvoiceGenerator.shareInvoice(order);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.print_rounded, color: Color(0xFF059669)),
                  title: const Text('Print Tax Invoice', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Send document directly to wireless or local printer', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    PdfInvoiceGenerator.printInvoice(order);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
