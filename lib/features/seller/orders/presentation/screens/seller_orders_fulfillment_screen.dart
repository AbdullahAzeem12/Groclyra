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
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/features/customer/orders/data/repositories/order_repository.dart';
import 'package:groclyra/features/customer/orders/domain/entities/order_entity.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';

class SellerOrdersFulfillmentScreen extends ConsumerStatefulWidget {
  const SellerOrdersFulfillmentScreen({super.key});

  @override
  ConsumerState<SellerOrdersFulfillmentScreen> createState() =>
      _SellerOrdersFulfillmentScreenState();
}

class _SellerOrdersFulfillmentScreenState
    extends ConsumerState<SellerOrdersFulfillmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, bool> _loadingMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = themeState.palette.primaryColor;
    final sellerId = ref.watch(authControllerProvider).user?.id ?? '';

    final ordersAsync = ref.watch(sellerOrdersStreamProvider(sellerId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RouteNames.sellerDashboard);
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        appBar: GradientAppBar(
          title: 'Order Fulfillment',
          subtitle: 'Accept → Pack → Handover → Track',
          showThemePicker: false,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
            tabs: const [
              Tab(text: '🔔 New'),
              Tab(text: '📦 Packing'),
              Tab(text: '🚀 Ready'),
              Tab(text: '✅ Done'),
            ],
          ),
        ),
        body: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('Error loading orders',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text('$err',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          data: (orders) {
            final List<_SellerOrderWrapper> all = [];
            for (final order in orders) {
              for (final sub in order.subOrders) {
                if (sub.sellerId == sellerId) {
                  all.add(_SellerOrderWrapper(order: order, subOrder: sub));
                }
              }
            }

            final newOrders = all
                .where((o) => o.subOrder.status == OrderStatus.paid)
                .toList();
            final packing = all
                .where((o) =>
                    o.subOrder.status == OrderStatus.sellerProcessing)
                .toList();
            final ready = all
                .where((o) =>
                    o.subOrder.status == OrderStatus.readyForPickup)
                .toList();
            final done = all
                .where((o) => [
                      OrderStatus.riderAssigned,
                      OrderStatus.inTransit,
                      OrderStatus.outForDelivery,
                      OrderStatus.delivered,
                    ].contains(o.subOrder.status))
                .toList();

            // Stats
            final todayRevenue = all
                .where((o) =>
                    o.subOrder.status == OrderStatus.delivered &&
                    _isToday(o.order.createdAt))
                .fold<double>(0, (s, o) => s + o.subOrder.subtotal);

            return Column(
              children: [
                // Revenue banner
                _buildRevenueBanner(isDark, primary, todayRevenue,
                    newOrders.length, all.length),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrderList(context, newOrders, isDark, primary,
                          themeState, 'new'),
                      _buildOrderList(context, packing, isDark, primary,
                          themeState, 'packing'),
                      _buildOrderList(context, ready, isDark, primary,
                          themeState, 'ready'),
                      _buildOrderList(context, done, isDark, primary,
                          themeState, 'done'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildRevenueBanner(bool isDark, Color primary, double todayRevenue,
      int newCount, int totalOrders) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.08),
            primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Revenue",
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  CurrencyFormatter.format(todayRevenue),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primary),
                ),
              ],
            ),
          ),
          Container(
              width: 1,
              height: 40,
              color: primary.withValues(alpha: 0.2)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('$newCount',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange)),
              const Text('New Orders',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 16),
          Container(
              width: 1,
              height: 40,
              color: primary.withValues(alpha: 0.2)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('$totalOrders',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primary)),
              const Text('Total',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(
    BuildContext context,
    List<_SellerOrderWrapper> wrappers,
    bool isDark,
    Color primary,
    ThemeState themeState,
    String tab,
  ) {
    if (wrappers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded,
                size: 56,
                color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 12),
            const Text('No orders in this stage',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      itemCount: wrappers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildOrderCard(
            context, wrappers[index], index, isDark, primary, themeState, tab);
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    _SellerOrderWrapper wrapper,
    int index,
    bool isDark,
    Color primary,
    ThemeState themeState,
    String tab,
  ) {
    final order = wrapper.order;
    final sub = wrapper.subOrder;
    final isLoading = _loadingMap[sub.id] == true;

    final totalQty = sub.items.fold<int>(0, (s, i) => s + i.quantity);
    final itemsText = sub.items.isEmpty
        ? 'No items'
        : sub.items.length == 1
            ? '${sub.items.first.quantity}× ${sub.items.first.product.title}'
            : '${sub.items.first.quantity}× ${sub.items.first.product.title} + ${sub.items.length - 1} more';

    final statusColor = sub.status.color;

    return SpringTouchScale(
      onTap: () =>
          _showOrderDetail(context, wrapper, isDark, primary, themeState),
      enableRipple: true,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121722) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: tab == 'new'
                ? Colors.orange.withValues(alpha: 0.5)
                : (isDark
                    ? const Color(0xFF262E3D)
                    : const Color(0xFFE2E8F0)),
            width: tab == 'new' ? 1.5 : 1,
          ),
          boxShadow: tab == 'new'
              ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${order.orderNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sub.status.label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.customerName,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalQty item${totalQty > 1 ? "s" : ""} — $itemsText',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Divider + action row
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Text(
                    CurrencyFormatter.format(sub.subtotal),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: primary),
                  ),
                  const Spacer(),
                  if (isLoading)
                    const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    _buildActionButton(
                        context, wrapper, isDark, primary, tab),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (40 * index).ms).slideY(begin: 0.05, duration: 250.ms);
  }

  Widget _buildActionButton(BuildContext context, _SellerOrderWrapper wrapper,
      bool isDark, Color primary, String tab) {
    final order = wrapper.order;
    final sub = wrapper.subOrder;

    if (tab == 'new') {
      return Row(
        children: [
          OutlinedButton(
            onPressed: () => _showRejectDialog(context, wrapper, isDark),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall)),
            ),
            child: const Text('Reject', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              setState(() => _loadingMap[sub.id] = true);
              await ref.read(orderRepositoryProvider).updateSubOrderStatus(
                    orderId: order.id,
                    subOrderId: sub.id,
                    newStatus: OrderStatus.sellerProcessing,
                  );
              if (mounted && context.mounted) {
                setState(() => _loadingMap.remove(sub.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Order #${order.orderNumber} accepted ✓'),
                    backgroundColor: Colors.green.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall)),
            ),
            child: const Text('✅ Accept', style: TextStyle(fontSize: 12)),
          ),
        ],
      );
    } else if (tab == 'packing') {
      return ElevatedButton.icon(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          setState(() => _loadingMap[sub.id] = true);
          await ref.read(orderRepositoryProvider).updateSubOrderStatus(
                orderId: order.id,
                subOrderId: sub.id,
                newStatus: OrderStatus.readyForPickup,
              );
          if (mounted && context.mounted) {
            setState(() => _loadingMap.remove(sub.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order #${order.orderNumber} ready for pickup ✓'),
                backgroundColor: Colors.blue.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
        label: const Text('Mark Ready', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 34),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusSmall)),
        ),
      );
    } else if (tab == 'ready') {
      return ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Awaiting rider scan for #${order.orderNumber}...'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
        label: const Text('Scan Handover', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 34),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusSmall)),
        ),
      );
    } else {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          sub.status.label,
          style: const TextStyle(
              fontSize: 11,
              color: Colors.green,
              fontWeight: FontWeight.bold),
        ),
      );
    }
  }

  // ── Order Detail Bottom Sheet ────────────────────────────────────────────

  void _showOrderDetail(BuildContext context, _SellerOrderWrapper wrapper,
      bool isDark, Color primary, ThemeState themeState) {
    final order = wrapper.order;
    final sub = wrapper.subOrder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2035) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order #${order.orderNumber}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: sub.status.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sub.status.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: sub.status.color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Customer info
                      _detailSection(isDark, 'Customer Details', [
                        _detailRow(
                            isDark, '👤 Name', order.customerName),
                        _detailRow(isDark, '📍 Address',
                            order.deliveryAddress),
                        _detailRow(
                            isDark, '📞 Phone',
                            order.customerPhone),
                      ]),
                      const SizedBox(height: 14),

                      // Items
                      _detailSection(isDark, 'Items Ordered',
                          sub.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantity}× ${item.product.title}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                    item.product.salePrice * item.quantity),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: primary),
                              ),
                            ],
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 14),

                      // Financial summary
                      _detailSection(isDark, 'Payment Summary', [
                        _detailRow(isDark, 'Sub-total',
                            CurrencyFormatter.format(sub.subtotal)),
                        _detailRow(
                            isDark,
                            'Platform Commission (10%)',
                            '- ${CurrencyFormatter.format(sub.subtotal * 0.1)}'),
                        const Divider(height: 12),
                        _detailRow(
                          isDark,
                          'Your Net Payout',
                          CurrencyFormatter.format(sub.subtotal * 0.9),
                          bold: true,
                          color: Colors.green,
                        ),
                      ]),
                      const SizedBox(height: 20),
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

  Widget _detailSection(
      bool isDark, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black45)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            border: Border.all(
                color: isDark
                    ? const Color(0xFF2D3748)
                    : const Color(0xFFE2E8F0)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _detailRow(bool isDark, String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color ??
                  (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reject Dialog ───────────────────────────────────────────────────────

  void _showRejectDialog(BuildContext context, _SellerOrderWrapper wrapper,
      bool isDark) {
    final reasons = [
      'Product out of stock',
      'Cannot fulfill at this time',
      'Product preparation unavailable',
      'Delivery area not covered',
      'Other reason',
    ];
    String selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A2035) : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusLarge)),
          icon:
              const Icon(Icons.cancel_outlined, color: Colors.red, size: 36),
          title: const Text('Reject Order',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a reason for rejecting order #${wrapper.order.orderNumber}:',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedReason = v);
                  }
                },
                child: Column(
                  children: reasons.map((r) => ListTile(
                        leading: Radio<String>(
                          value: r,
                          activeColor: Colors.red,
                        ),
                        title: Text(r,
                            style: TextStyle(
                                fontSize: 13,
                                color:
                                    isDark ? Colors.white : Colors.black87)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () =>
                            setDialogState(() => selectedReason = r),
                      )).toList(),
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
                Navigator.pop(ctx);
                HapticFeedback.heavyImpact();
                setState(() => _loadingMap[wrapper.subOrder.id] = true);
                await ref
                    .read(orderRepositoryProvider)
                    .updateSubOrderStatus(
                      orderId: wrapper.order.id,
                      subOrderId: wrapper.subOrder.id,
                      newStatus: OrderStatus.cancelledBySeller,
                    );
                if (mounted && context.mounted) {
                  setState(
                      () => _loadingMap.remove(wrapper.subOrder.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Order #${wrapper.order.orderNumber} rejected. Reason: $selectedReason'),
                      backgroundColor: Colors.red.shade700,
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
                    borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMedium)),
              ),
              child: const Text('Confirm Reject'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerOrderWrapper {
  final OrderEntity order;
  final SubOrderEntity subOrder;
  _SellerOrderWrapper({required this.order, required this.subOrder});
}
