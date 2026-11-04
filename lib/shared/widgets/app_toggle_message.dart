import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_dimensions.dart';
import '../animations/spring_touch_scale.dart';

enum ToggleMessageType {
  success,
  info,
  warning,
  error,
  cart,
  wishlist,
}

/// A premium, 3D-styled floating toggle message / toast with spring physics,
/// rich gradient iconography, multi-layered elevation, and automatic timed dismissal.
class AppToggleMessage {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToggleMessageType type = ToggleMessageType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    HapticFeedback.lightImpact();

    // Clear any previous queued/stuck messages immediately
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        content: _ToggleMessageCard(
          title: title,
          message: message,
          type: type,
          actionLabel: actionLabel,
          onAction: onAction != null
              ? () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                }
              : null,
        ),
      ),
    );
  }

  // ── Convenience Helpers ───────────────────────────────────────────────────

  static void success(
    BuildContext context,
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToggleMessageType.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void cart(
    BuildContext context, {
    required String title,
    String? price,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    show(
      context,
      title: 'Added to Cart',
      message: price != null ? '$title • $price' : title,
      type: ToggleMessageType.cart,
      actionLabel: 'VIEW CART',
      onAction: onAction,
      duration: duration,
    );
  }

  static void wishlist(
    BuildContext context, {
    required String title,
    required bool isAdded,
    VoidCallback? onUndo,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    show(
      context,
      title: isAdded ? 'Saved to Wishlist' : 'Removed from Wishlist',
      message: title,
      type: ToggleMessageType.wishlist,
      actionLabel: onUndo != null ? 'UNDO' : null,
      onAction: onUndo,
      duration: duration,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    show(
      context,
      message: message,
      title: title ?? 'Action Failed',
      type: ToggleMessageType.error,
      duration: duration,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToggleMessageType.info,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToggleMessageType.warning,
      duration: duration,
    );
  }
}

class _ToggleMessageCard extends StatefulWidget {
  final String? title;
  final String message;
  final ToggleMessageType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToggleMessageCard({
    this.title,
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_ToggleMessageCard> createState() => _ToggleMessageCardState();
}

class _ToggleMessageCardState extends State<_ToggleMessageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  _TypeVisuals _getVisuals(bool isDark) {
    switch (widget.type) {
      case ToggleMessageType.success:
      case ToggleMessageType.cart:
        return _TypeVisuals(
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFF059669),
          accentBg: const Color(0xFF064E3B),
          icon: widget.type == ToggleMessageType.cart
              ? Icons.shopping_bag_rounded
              : Icons.check_circle_rounded,
        );
      case ToggleMessageType.wishlist:
        return const _TypeVisuals(
          primary: Color(0xFFEC4899),
          secondary: Color(0xFFDB2777),
          accentBg: Color(0xFF831843),
          icon: Icons.favorite_rounded,
        );
      case ToggleMessageType.warning:
        return const _TypeVisuals(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFFD97706),
          accentBg: Color(0xFF78350F),
          icon: Icons.warning_amber_rounded,
        );
      case ToggleMessageType.error:
        return const _TypeVisuals(
          primary: Color(0xFFEF4444),
          secondary: Color(0xFFDC2626),
          accentBg: Color(0xFF7F1D1D),
          icon: Icons.error_outline_rounded,
        );
      case ToggleMessageType.info:
        return const _TypeVisuals(
          primary: Color(0xFF007DFE),
          secondary: Color(0xFF0058C6),
          accentBg: Color(0xFF1E3A8A),
          icon: Icons.info_outline_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visuals = _getVisuals(isDark);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF182235),
                    const Color(0xFF101622),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF8FAFC),
                  ],
          ),
          border: Border.all(
            color: isDark
                ? visuals.primary.withValues(alpha: 0.35)
                : visuals.primary.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: visuals.primary.withValues(alpha: isDark ? 0.22 : 0.14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // 3D Elevated Icon Badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [visuals.primary, visuals.secondary],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: visuals.primary.withValues(alpha: 0.40),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  visuals.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Message Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.title != null) ...[
                    Text(
                      widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    widget.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: widget.title != null ? FontWeight.w500 : FontWeight.w600,
                      color: isDark
                          ? (widget.title != null
                              ? const Color(0xFF94A3B8)
                              : Colors.white)
                          : (widget.title != null
                              ? const Color(0xFF64748B)
                              : const Color(0xFF0F172A)),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),

            // Action Button
            if (widget.actionLabel != null && widget.onAction != null) ...[
              const SizedBox(width: 8),
              SpringTouchScale(
                onTap: widget.onAction!,
                navigationDelayMs: 0,
                scaleFactor: 0.92,
                pressDepth: 2.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: visuals.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: visuals.primary.withValues(alpha: 0.45),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    widget.actionLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: visuals.primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeVisuals {
  final Color primary;
  final Color secondary;
  final Color accentBg;
  final IconData icon;

  const _TypeVisuals({
    required this.primary,
    required this.secondary,
    required this.accentBg,
    required this.icon,
  });
}
