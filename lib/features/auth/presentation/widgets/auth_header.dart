import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/gradient_palette.dart';
import '../../domain/entities/user_entity.dart';
import '../../../../shared/animations/spring_touch_scale.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final UserRole? role;
  final AppThemePalette palette;
  final bool isDark;

  final VoidCallback? onBackPressed;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.role,
    required this.palette,
    required this.isDark,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Systematic Brand and Navigation Header (In One Line)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (onBackPressed != null) ...[
              SpringTouchScale(
                onTap: onBackPressed,
                navigationDelayMs: 165,
                scaleFactor: 0.88,
                pressDepth: 3.5,
                enableRipple: false,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.p12),
            ],

            // GL Logo mark
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: palette.linearGradient,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: palette.startColor.withValues(alpha: 0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'GL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Role Portal Name Pill Badge
            if (role != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.p12,
                  vertical: AppDimensions.p8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? palette.startColor.withValues(alpha: 0.15)
                      : palette.startColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  border: Border.all(
                    color: palette.startColor.withValues(alpha: 0.28),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.startColor.withValues(alpha: isDark ? 0.12 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getRoleIcon(role!),
                      size: 14,
                      color: palette.startColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${role!.displayName} Portal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : palette.startColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.p20),

        // Title
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.15,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
        ),
        const SizedBox(height: AppDimensions.p8),

        // Subtitle
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                fontSize: 14,
                height: 1.4,
              ),
        ),
      ],
    );
  }

  IconData _getRoleIcon(UserRole r) {
    switch (r) {
      case UserRole.customer:
        return Icons.shopping_bag_rounded;
      case UserRole.seller:
        return Icons.storefront_rounded;
      case UserRole.rider:
        return Icons.delivery_dining_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }
}
