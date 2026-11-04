import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/gradient_palette.dart';
import '../../../../shared/animations/spring_touch_scale.dart';

class AuthGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingText;
  final AppThemePalette palette;
  final IconData? icon;

  const AuthGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.loadingText,
    required this.palette,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return SpringTouchScale(
      onTap: isEnabled ? onPressed : null,
      scaleFactor: 0.96,
      pressDepth: 2.5,
      enableRipple: true,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      splashColor: Colors.white.withValues(alpha: 0.22),
      highlightColor: Colors.white.withValues(alpha: 0.10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isEnabled ? palette.linearGradient : null,
          color: isEnabled ? null : Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: palette.startColor.withValues(alpha: 0.38),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: palette.endColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.p12),
                    Text(
                      loadingText ?? 'Please wait...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: AppDimensions.p8),
                    ],
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
