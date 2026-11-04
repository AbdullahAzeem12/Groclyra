import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/theme_selector_bottom_sheet.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/customer/addresses/presentation/controllers/address_controller.dart';
import 'package:groclyra/features/customer/wishlist/presentation/controllers/wishlist_controller.dart';
import 'package:groclyra/features/notifications/data/notifications_repository.dart';
import '../widgets/quick_switch_portal_sheet.dart';
import '../widgets/logout_confirmation_dialog.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final addressState = ref.watch(addressControllerProvider);
    final wishlistState = ref.watch(wishlistControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState.user;

    final unreadAsync = ref.watch(unreadNotificationsCountProvider(user?.id ?? ''));
    final unreadCount = unreadAsync.asData?.value ?? 0;

    final defaultAddressText = addressState.defaultAddress != null
        ? '${addressState.defaultAddress!.shortDisplay} (Default)'
        : (user?.deliveryAddress?.isNotEmpty == true
            ? '${user!.deliveryAddress!} (Default)'
            : 'Clifton, Karachi (Default)');

    final wishlistCountText = '${wishlistState.totalCount} Crockery & Grocery items saved';

    final notifSubtitle = unreadCount > 0
        ? '$unreadCount unread • Order tracking & alerts'
        : 'Order tracking & flash sale alerts';

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'My Account',
        subtitle: 'Profile, Preferences & Settings',
        showThemePicker: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121722) : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundImage: _getProfileImage(user),
                          backgroundColor: isDark ? const Color(0xFF262E3D) : Colors.grey[200],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? const Color(0xFF121722) : Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Fatima Zahra',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'customer@groclyra.com',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Verified Customer',
                            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push(RouteNames.editProfile),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            ),
                            child: const Text('Edit Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Quick Switch Portal Banner (Interactive Gateway)
            SpringTouchScale(
              onTap: () => QuickSwitchPortalSheet.show(context),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: themeState.palette.subtleGradient,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(color: themeState.palette.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.swap_horiz_rounded, color: themeState.palette.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            const Text('Quick Switch Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const Icon(Icons.tune_rounded, size: 16, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (user?.authorizedRoles.contains(UserRole.seller) == true)
                          _buildRoleButton(
                            context,
                            ref,
                            role: UserRole.seller,
                            label: '🏪 Seller',
                            targetRoute: RouteNames.sellerDashboard,
                          ),
                        if (user?.authorizedRoles.contains(UserRole.rider) == true)
                          _buildRoleButton(
                            context,
                            ref,
                            role: UserRole.rider,
                            label: '🛵 Rider',
                            targetRoute: RouteNames.riderDashboard,
                          ),
                        if (user?.authorizedRoles.contains(UserRole.admin) == true)
                          _buildRoleButton(
                            context,
                            ref,
                            role: UserRole.admin,
                            label: '🛡️ Admin',
                            targetRoute: RouteNames.adminDashboard,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Change Gradient Theme Palette
            _buildSettingsTile(
              context: context,
              icon: Icons.palette_outlined,
              title: 'Change Gradient Theme Palette',
              subtitle: 'Active: ${themeState.palette.title}',
              onTap: () => ThemeSelectorBottomSheet.show(context),
            ),

            // 3. Saved Delivery Addresses
            _buildSettingsTile(
              context: context,
              icon: Icons.location_on_outlined,
              title: 'Saved Delivery Addresses',
              subtitle: defaultAddressText,
              onTap: () => context.push(RouteNames.customerAddresses),
            ),

            // 4. My Wishlist & Saved
            _buildSettingsTile(
              context: context,
              icon: Icons.favorite_border_rounded,
              title: 'My Wishlist & Saved',
              subtitle: wishlistCountText,
              onTap: () => context.push(RouteNames.customerWishlist),
            ),

            // 5. Push Notifications
            _buildSettingsTile(
              context: context,
              icon: Icons.notifications_none_rounded,
              title: 'Push Notifications',
              subtitle: notifSubtitle,
              badgeCount: unreadCount > 0 ? unreadCount : null,
              onTap: () => context.push(RouteNames.customerNotifications),
            ),

            // 6. Customer Support & Help Center
            _buildSettingsTile(
              context: context,
              icon: Icons.headset_mic_outlined,
              title: 'Customer Support & Help Center',
              subtitle: '24/7 Live chat & ticket support',
              onTap: () => context.push(RouteNames.customerSupport),
            ),

            // 7. Log Out
            _buildSettingsTile(
              context: context,
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Return to Role Selection Gateway',
              iconColor: Colors.red,
              textColor: Colors.red,
              onTap: () => LogoutConfirmationDialog.show(context),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  ImageProvider _getProfileImage(UserEntity? user) {
    if (user?.profileImageBase64 != null && user!.profileImageBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(user.profileImageBase64!));
      } catch (_) {}
    }
    if (user?.avatarUrl != null) {
      return NetworkImage(user!.avatarUrl!);
    }
    return const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200');
  }

  Widget _buildRoleButton(
    BuildContext context,
    WidgetRef ref, {
    required UserRole role,
    required String label,
    required String targetRoute,
  }) {
    return SpringTouchScale(
      onTap: () async {
        final res = await ref.read(authControllerProvider.notifier).requestRoleSwitch(role);
        if (res.isSuccess && context.mounted) {
          context.go(targetRoute);
        } else if (context.mounted) {
          AppToggleMessage.error(
            context,
            res.message ?? 'Access Denied',
            title: 'Role Switch',
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    int? badgeCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: iconColor ?? Theme.of(context).primaryColor),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badgeCount != null && badgeCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
