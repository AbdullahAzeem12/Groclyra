import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/theme_controller.dart';
import '../animations/spring_touch_scale.dart';
import 'dart:ui';
class GradientCard extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool showGradientBorder;
  final BorderRadius? borderRadius;

  const GradientCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16.0),
    this.showGradientBorder = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppDimensions.radiusMedium);

    final cardContent = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.05) 
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: radius,
            border: showGradientBorder
                ? Border.all(color: themeState.palette.primaryColor.withValues(alpha: 0.4), width: 1.5)
                : Border.all(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.1) 
                        : Colors.white.withValues(alpha: 0.5)
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return SpringTouchScale(
        onTap: onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
