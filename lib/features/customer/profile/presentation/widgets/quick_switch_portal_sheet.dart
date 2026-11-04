import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';


class QuickSwitchPortalSheet extends ConsumerWidget {
  const QuickSwitchPortalSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLarge)),
      ),
      builder: (ctx) => const QuickSwitchPortalSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = themeState.palette.primaryColor;

    final currentRole = user?.role ?? UserRole.customer;
    final authorized = user?.authorizedRoles ?? [UserRole.customer];

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
                    'Quick Switch Portal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Authorized Role Gateway • Session Preserved',
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

          // Role options
          _buildRoleCard(
            context: context,
            ref: ref,
            role: UserRole.customer,
            icon: Icons.shopping_basket_rounded,
            title: 'Customer Marketplace',
            description: 'Shop groceries, premium dinner sets & live tracking',
            isActive: currentRole == UserRole.customer,
            isAuthorized: authorized.contains(UserRole.customer),
            isDark: isDark,
            primaryColor: primaryColor,
            targetRoute: RouteNames.customerHome,
          ),
          const SizedBox(height: 10),

          _buildRoleCard(
            context: context,
            ref: ref,
            role: UserRole.seller,
            icon: Icons.storefront_rounded,
            title: 'Seller Partner Portal',
            description: 'Manage store catalog, inventory stock & dispatch sub-orders',
            isActive: currentRole == UserRole.seller,
            isAuthorized: authorized.contains(UserRole.seller),
            isDark: isDark,
            primaryColor: primaryColor,
            targetRoute: RouteNames.sellerDashboard,
          ),
          const SizedBox(height: 10),

          _buildRoleCard(
            context: context,
            ref: ref,
            role: UserRole.rider,
            icon: Icons.two_wheeler_rounded,
            title: 'Delivery Partner (Rider)',
            description: 'Accept delivery queues, turn-by-turn route & OTP verification',
            isActive: currentRole == UserRole.rider,
            isAuthorized: authorized.contains(UserRole.rider),
            isDark: isDark,
            primaryColor: primaryColor,
            targetRoute: RouteNames.riderDashboard,
          ),
          const SizedBox(height: 10),

          _buildRoleCard(
            context: context,
            ref: ref,
            role: UserRole.admin,
            icon: Icons.admin_panel_settings_rounded,
            title: 'Administrator Console',
            description: 'Platform telemetry, catalog moderation & seller/rider KYC',
            isActive: currentRole == UserRole.admin,
            isAuthorized: authorized.contains(UserRole.admin),
            isDark: isDark,
            primaryColor: primaryColor,
            targetRoute: RouteNames.adminDashboard,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required WidgetRef ref,
    required UserRole role,
    required IconData icon,
    required String title,
    required String description,
    required bool isActive,
    required bool isAuthorized,
    required bool isDark,
    required Color primaryColor,
    required String targetRoute,
  }) {
    return SpringTouchScale(
      onTap: () async {
        if (!isAuthorized) {
          AppToggleMessage.error(
            context,
            'Access Denied: Your account is not authorized for the ${role.displayName} portal.',
            title: 'Portal Locked',
          );
          return;
        }

        Navigator.pop(context);
        final res = await ref.read(authControllerProvider.notifier).requestRoleSwitch(role);
        if (res.isSuccess && context.mounted) {
          context.go(targetRoute);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF141923) : Colors.white),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isActive
                ? primaryColor
                : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
            width: isActive ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isAuthorized ? primaryColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isAuthorized ? primaryColor : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isAuthorized ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        )
                      else if (!isAuthorized)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LOCKED',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(
              isActive ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isActive ? primaryColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
