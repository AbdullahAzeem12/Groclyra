import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/gradient_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../animations/spring_touch_scale.dart';

class ThemeSelectorBottomSheet extends ConsumerWidget {
  const ThemeSelectorBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLarge)),
      ),
      builder: (ctx) => const ThemeSelectorBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
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
                      'Customize UI Theme',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose your favorite vibrant gradient palette',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                SpringTouchScale(
                  navigationDelayMs: 165,
                  scaleFactor: 0.88,
                  pressDepth: 3.5,
                  enableRipple: false,
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Surface Theme Mode (System, Light, Dark)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181E2B) : const Color(0xFFF1F3F9),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(
                  color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  _buildModeChip(
                    context: context,
                    ref: ref,
                    title: 'System',
                    icon: Icons.brightness_auto_rounded,
                    isSelected: themeState.mode == ThemeMode.system,
                    onTap: () => ref.read(themeControllerProvider.notifier).setThemeMode(ThemeMode.system),
                    activeColor: themeState.palette.primaryColor,
                  ),
                  _buildModeChip(
                    context: context,
                    ref: ref,
                    title: 'Light',
                    icon: Icons.light_mode_rounded,
                    isSelected: themeState.mode == ThemeMode.light,
                    onTap: () => ref.read(themeControllerProvider.notifier).setThemeMode(ThemeMode.light),
                    activeColor: themeState.palette.primaryColor,
                  ),
                  _buildModeChip(
                    context: context,
                    ref: ref,
                    title: 'Dark',
                    icon: Icons.dark_mode_rounded,
                    isSelected: themeState.mode == ThemeMode.dark,
                    onTap: () => ref.read(themeControllerProvider.notifier).setThemeMode(ThemeMode.dark),
                    activeColor: themeState.palette.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Signature Gradient Palettes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Palettes List
            ...AppThemePalette.values.map((palette) {
              final isSelected = themeState.palette == palette;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SpringTouchScale(
                  onTap: () {
                    ref.read(themeControllerProvider.notifier).setPalette(palette);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181E2B) : Colors.white,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(
                        color: isSelected ? palette.primaryColor : Colors.grey.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Gradient Preview Swatch
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: palette.linearGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: palette.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                palette.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isSelected ? palette.primaryColor : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                palette.subtitle,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: palette.subtleGradient,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                color: palette.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: SpringTouchScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? activeColor.withValues(alpha: 0.2) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? activeColor : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

