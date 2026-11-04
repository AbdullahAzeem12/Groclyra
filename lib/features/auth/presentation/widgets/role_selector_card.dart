import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/gradient_palette.dart';
import '../../../../shared/animations/spring_touch_scale.dart';
import '../../../../shared/animations/rotating_border_glow_card.dart';
import '../../domain/entities/user_entity.dart';

class RoleSelectorCard extends StatelessWidget {
  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleSelected;
  final AppThemePalette palette;
  final bool isDark;
  final bool disableAdmin;
  final VoidCallback? onLockedAdminTap;

  const RoleSelectorCard({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
    required this.palette,
    required this.isDark,
    this.disableAdmin = false,
    this.onLockedAdminTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'SELECT PORTAL ROLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Selected: ${selectedRole.displayName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.startColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.p12),

        // 2x2 Symmetric Equal-Sized Grid (All boxes have identical dimensions)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildRoleCard(UserRole.customer)),
              const SizedBox(width: AppDimensions.p12),
              Expanded(child: _buildRoleCard(UserRole.seller)),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.p12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildRoleCard(UserRole.rider)),
              const SizedBox(width: AppDimensions.p12),
              Expanded(child: _buildRoleCard(UserRole.admin)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard(UserRole role) {
    final isSelected = selectedRole == role;
    final isDisabled = disableAdmin && role == UserRole.admin;

    return _RoleCardItem(
      role: role,
      isSelected: isSelected,
      isDisabled: isDisabled,
      palette: palette,
      isDark: isDark,
      onTap: () {
        if (!isDisabled) {
          onRoleSelected(role);
        } else if (role == UserRole.admin && onLockedAdminTap != null) {
          onLockedAdminTap!();
        }
      },
    );
  }
}

class _RoleCardItem extends StatefulWidget {
  final UserRole role;
  final bool isSelected;
  final bool isDisabled;
  final AppThemePalette palette;
  final bool isDark;
  final VoidCallback onTap;

  const _RoleCardItem({
    required this.role,
    required this.isSelected,
    required this.isDisabled,
    required this.palette,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_RoleCardItem> createState() => _RoleCardItemState();
}

class _RoleCardItemState extends State<_RoleCardItem> with SingleTickerProviderStateMixin {
  late AnimationController _glowRotateController;

  @override
  void initState() {
    super.initState();
    _glowRotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (widget.isSelected) {
      _glowRotateController.repeat();
    }
  }

  @override
  void didUpdateWidget(_RoleCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _glowRotateController.repeat();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _glowRotateController.stop();
    }
  }

  @override
  void dispose() {
    _glowRotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeBgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: widget.isDark
          ? [
              widget.palette.startColor.withValues(alpha: 0.18),
              const Color(0xFF161E2E),
            ]
          : [
              widget.palette.startColor.withValues(alpha: 0.08),
              Colors.white,
            ],
    );

    final inactiveBg = widget.isDark
        ? const Color(0xFF131A29).withValues(alpha: 0.75)
        : const Color(0xFFF8FAFC);

    final borderColor = widget.isSelected
        ? widget.palette.startColor
        : (widget.isDark ? const Color(0xFF242F42) : const Color(0xFFE2E8F0));

    final boxShadow = widget.isSelected
        ? [
            BoxShadow(
              color: widget.palette.startColor.withValues(alpha: widget.isDark ? 0.32 : 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: widget.palette.startColor.withValues(alpha: widget.isDark ? 0.15 : 0.08),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.15 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ];

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: 130.0,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.p12,
        vertical: 10.0,
      ),
      decoration: BoxDecoration(
        gradient: widget.isSelected ? activeBgGradient : null,
        color: widget.isSelected ? null : inactiveBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: widget.isSelected ? Border.all(color: Colors.transparent, width: 0.0) : Border.all(
          color: borderColor,
          width: 1.0,
        ),
        boxShadow: boxShadow,
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon circle + Radio / Status Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Animated Icon circle with glowing effect when selected
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: widget.isSelected ? widget.palette.linearGradient : null,
                    color: widget.isSelected
                        ? null
                        : (widget.isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEDF2F7)),
                    shape: BoxShape.circle,
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: widget.palette.startColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      _roleIcon(widget.role),
                      size: 18,
                      color: widget.isSelected
                          ? Colors.white
                          : (widget.isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                ),

                // Radio check pill or lock indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isSelected ? widget.palette.linearGradient : null,
                    color: widget.isSelected ? null : Colors.transparent,
                    border: Border.all(
                      color: widget.isSelected
                          ? Colors.transparent
                          : (widget.isDisabled
                              ? (widget.isDark
                                  ? const Color(0xFF3B4861)
                                  : const Color(0xFFCBD5E1))
                              : (widget.isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFCBD5E1))),
                      width: 1.5,
                    ),
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: widget.palette.startColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: widget.isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          )
                        : widget.isDisabled
                            ? Icon(
                                Icons.lock_outline_rounded,
                                size: 11,
                                color: widget.isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              )
                            : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Middle: Role Title & Subtitle (Consistent positioning across all cards)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.role.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.isSelected
                        ? (widget.isDark ? Colors.white : const Color(0xFF0F172A))
                        : (widget.isDark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF334155)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _roleSubtitle(widget.role),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: widget.isSelected
                        ? (widget.isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B))
                        : (widget.isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Bottom Slot: Standardized 20px height across all cards for absolute symmetry
            SizedBox(
              height: 20,
              child: Align(
                alignment: Alignment.centerLeft,
                child: widget.isDisabled
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 10, color: Colors.amber),
                            SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'Provisioned Only',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : widget.isSelected
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.palette.startColor
                                  .withValues(alpha: widget.isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: widget.palette.startColor
                                    .withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4.5,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: widget.palette.startColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Selected',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: widget.isDark
                                          ? Colors.white
                                          : widget.palette.startColor,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      );

    if (widget.isSelected) {
      content = RotatingBorderGlowCard(
        rotateController: _glowRotateController,
        color: widget.palette.startColor,
        secondaryColor: widget.palette.endColor,
        phaseOffset: 0.0,
        isDark: widget.isDark,
        borderRadius: AppDimensions.radiusMedium,
        child: content,
      );
    }

    return SpringTouchScale(
      onTap: widget.onTap,
      scaleFactor: 0.95,
      pressDepth: 2.5,
      enableRipple: true,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      splashColor: widget.palette.startColor.withValues(alpha: 0.16),
      highlightColor: widget.palette.startColor.withValues(alpha: 0.06),
      child: content,
    );
  }

  IconData _roleIcon(UserRole r) {
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

  String _roleSubtitle(UserRole r) {
    switch (r) {
      case UserRole.customer:
        return 'Groceries & Crockery';
      case UserRole.seller:
        return 'Store & Catalog';
      case UserRole.rider:
        return 'Fulfillment & GPS';
      case UserRole.admin:
        return 'Control & Audit';
    }
  }
}
