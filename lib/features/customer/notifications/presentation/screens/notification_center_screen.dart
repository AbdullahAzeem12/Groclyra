import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/notifications/data/notifications_repository.dart';
import 'package:groclyra/features/notifications/domain/entities/app_notification.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';

import '../widgets/notification_preferences_sheet.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  String _selectedCategory = 'all';

  final List<AppNotification> _sampleFallbackNotifications = [
    AppNotification(
      id: 'notif_sample_order_dispatched',
      recipientId: 'usr_guest',
      kind: 'delivery',
      title: '🛵 Rider Assigned & On The Way',
      body: 'Rider Muhammad Tariq is on his way with your Groclyra order #GL-49281. Expected arrival in 25 mins.',
      data: {'orderId': 'ord_sample_9021', 'route': '/customer/tracking/ord_sample_9021'},
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
    AppNotification(
      id: 'notif_sample_price_drop',
      recipientId: 'usr_guest',
      kind: 'price_drop',
      title: '🔻 Price Drop on Saved Crockery!',
      body: 'Royal Bone China 24-Piece Dinner Set in your wishlist just dropped from Rs. 14,500 to Rs. 13,999!',
      data: {'route': '/customer/wishlist'},
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'notif_sample_order_confirmed',
      recipientId: 'usr_guest',
      kind: 'order',
      title: '✅ Order #GL-49281 Confirmed',
      body: 'Payment received via JazzCash. Seller Groclyra Marketplace is packing your grocery & dinner set.',
      data: {'orderId': 'ord_sample_9021', 'route': '/customer/orders'},
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    AppNotification(
      id: 'notif_sample_support_reply',
      recipientId: 'usr_guest',
      kind: 'support',
      title: '🎧 AI Support: Ticket #TKT-8419 Resolved',
      body: 'Your crockery breakage replacement ticket has been approved. A free replacement dinner plate is dispatched.',
      data: {'route': '/customer/support'},
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: 'notif_sample_promo_flash',
      recipientId: 'usr_guest',
      kind: 'promo',
      title: '🔥 Midnight Aurora Flash Sale: Flat 20% Off',
      body: 'Use code SYNTH20 on all imported porcelain and organic groceries before midnight tonight.',
      data: {'route': '/customer'},
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final notifsRepo = ref.watch(notificationsRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = themeState.palette.primaryColor;
    final userId = authState.user?.id ?? '';

    final liveStream = ref.watch(notificationsStreamProvider(userId));

    final rawList = liveStream.asData?.value ?? [];
    final notifications = rawList.isNotEmpty ? rawList : _sampleFallbackNotifications;

    final filtered = _selectedCategory == 'all'
        ? notifications
        : notifications.where((n) => n.kind == _selectedCategory).toList();

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Push Notifications',
        subtitle: 'Order tracking & flash sale alerts',
        showBack: true,
        showThemePicker: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.white),
            tooltip: 'Mark all as read',
            onPressed: () {
              if (userId.isNotEmpty) {
                notifsRepo.markAllRead(userId);
              }
              AppToggleMessage.info(
                context,
                'All notifications marked as read.',
                title: 'Notifications Cleared',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            tooltip: 'Notification Channels',
            onPressed: () => NotificationPreferencesSheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF10141D) : Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Alerts', primaryColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('order', '📦 Orders', primaryColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('delivery', '🛵 Deliveries', primaryColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('price_drop', '🔻 Price Drops', primaryColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('support', '🎧 Support', primaryColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('promo', '🔥 Flash Deals', primaryColor),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Notifications List
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(primaryColor)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final notif = filtered[idx];
                      return _buildNotificationCard(
                        context,
                        notif,
                        isDark,
                        primaryColor,
                        notifsRepo,
                        userId,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String kind, String label, Color primaryColor) {
    final isSelected = _selectedCategory == kind;
    return SpringTouchScale(
      onTap: () => setState(() => _selectedCategory = kind),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotification notif,
    bool isDark,
    Color primaryColor,
    NotificationsRepository repo,
    String userId,
  ) {
    IconData icon;
    Color iconColor;

    switch (notif.kind) {
      case 'order':
        icon = Icons.receipt_long_rounded;
        iconColor = Colors.blue;
        break;
      case 'delivery':
        icon = Icons.two_wheeler_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case 'price_drop':
        icon = Icons.trending_down_rounded;
        iconColor = Colors.amber;
        break;
      case 'support':
        icon = Icons.support_agent_rounded;
        iconColor = Colors.purpleAccent;
        break;
      case 'promo':
        icon = Icons.local_fire_department_rounded;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.notifications_active_rounded;
        iconColor = primaryColor;
    }

    final timeStr = _formatTimestamp(notif.createdAt);

    return SpringTouchScale(
      onTap: () {
        if (!notif.isRead && userId.isNotEmpty) {
          repo.markRead(notif.id);
        }
        _handleDeepLink(context, notif);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141923) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: notif.isRead
                ? (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0))
                : primaryColor.withValues(alpha: 0.6),
            width: notif.isRead ? 1.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDeepLink(BuildContext context, AppNotification notif) {
    if (notif.kind == 'order') {
      context.go(RouteNames.customerOrders);
    } else if (notif.kind == 'delivery') {
      final orderId = notif.data['orderId'] as String? ?? 'ord_sample_9021';
      context.push('${RouteNames.customerTracking}/$orderId');
    } else if (notif.kind == 'price_drop') {
      context.push(RouteNames.customerWishlist);
    } else if (notif.kind == 'support') {
      context.push(RouteNames.customerSupport);
    } else if (notif.kind == 'promo') {
      context.go(RouteNames.customerHome);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes <= 0 ? 1 : diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(dt);
    }
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: Icon(Icons.notifications_none_rounded, size: 64, color: primaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are all caught up! Order tracking, delivery updates, and price drop alerts will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
