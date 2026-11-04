import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';

import '../../domain/entities/notification_preferences_entity.dart';

class NotificationPreferencesSheet extends ConsumerStatefulWidget {
  const NotificationPreferencesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLarge)),
      ),
      builder: (ctx) => const NotificationPreferencesSheet(),
    );
  }

  @override
  ConsumerState<NotificationPreferencesSheet> createState() => _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState extends ConsumerState<NotificationPreferencesSheet> {
  NotificationPreferencesEntity _prefs = const NotificationPreferencesEntity();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final auth = ref.read(authControllerProvider);
    final uid = auth.user?.id;
    if (uid != null && uid.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notificationPreferences')
            .doc('settings')
            .get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _prefs = NotificationPreferencesEntity.fromMap(doc.data()!);
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}
    }
    setState(() => _isLoading = false);
  }

  Future<void> _update(NotificationPreferencesEntity updated) async {
    setState(() => _prefs = updated);
    final auth = ref.read(authControllerProvider);
    final uid = auth.user?.id;
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notificationPreferences')
            .doc('settings')
            .set(updated.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final primaryColor = themeState.palette.primaryColor;


    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Push Notification Channels',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Customize what alert categories Groclyra delivers to your device',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else
            Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Order Status & Confirmation',
                  subtitle: 'Real-time updates on order placed, seller packed and dispatched',
                  value: _prefs.orderUpdates,
                  activeColor: primaryColor,
                  onChanged: (v) => _update(_prefs.copyWith(orderUpdates: v)),
                ),
                _buildSwitchTile(
                  icon: Icons.two_wheeler_rounded,
                  title: 'Live Rider & Delivery Tracking',
                  subtitle: 'Rider assigned, out for delivery and OTP verification alerts',
                  value: _prefs.deliveryTracking,
                  activeColor: primaryColor,
                  onChanged: (v) => _update(_prefs.copyWith(deliveryTracking: v)),
                ),
                _buildSwitchTile(
                  icon: Icons.trending_down_rounded,
                  title: 'Saved Products Price Drop Alerts',
                  subtitle: 'Alerts when wishlist grocery and crockery drop in verified price',
                  value: _prefs.priceDropAlerts,
                  activeColor: primaryColor,
                  onChanged: (v) => _update(_prefs.copyWith(priceDropAlerts: v)),
                ),
                _buildSwitchTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Back-in-Stock Notifications',
                  subtitle: 'Instant alert when out-of-stock crockery or grocery returns to inventory',
                  value: _prefs.restockAlerts,
                  activeColor: primaryColor,
                  onChanged: (v) => _update(_prefs.copyWith(restockAlerts: v)),
                ),
                _buildSwitchTile(
                  icon: Icons.support_agent_rounded,
                  title: 'AI Agent & Customer Support Replies',
                  subtitle: 'Responses to your open tickets, return requests and inquiries',
                  value: _prefs.supportReplies,
                  activeColor: primaryColor,
                  onChanged: (v) => _update(_prefs.copyWith(supportReplies: v)),
                ),
                _buildSwitchTile(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Flash Sales & Promotional Campaigns',
                  subtitle: 'Approved seasonal discounts and exclusive weekend deals',
                  value: _prefs.promotions,
                  activeColor: primaryColor,
                  onChanged: (v) => _update(_prefs.copyWith(promotions: v)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: activeColor, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      value: value,
      activeThumbColor: activeColor,
      onChanged: onChanged,
    );
  }
}

