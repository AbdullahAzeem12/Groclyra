import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';
import '../../features/notifications/presentation/widgets/notification_center_sheet.dart';
import '../animations/spring_touch_scale.dart';
import 'theme_selector_bottom_sheet.dart';

class GradientAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showThemePicker;

  /// NEW (Phase 1B): shows a real-time notification bell with unread badge
  /// before the theme picker. Opt-in per screen so content screens keep
  /// their exact current header.
  final bool showNotificationBell;
  final bool showBack;

  const GradientAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.bottom,
    this.showThemePicker = true,
    this.showNotificationBell = false,
    this.showBack = true,
  });


  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: themeState.palette.linearGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else if (showBack && Navigator.canPop(context))
                    SpringTouchScale(
                      onTap: () => Navigator.pop(context),
                      navigationDelayMs: 165,
                      scaleFactor: 0.88,
                      pressDepth: 3.5,
                      enableRipple: false,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...?actions,
                  if (showNotificationBell) ...[
                    const NotificationBellIconButton(
                      iconColor: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (showThemePicker)
                    IconButton(
                      tooltip: 'Change Gradient Theme',
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.palette_outlined, color: Colors.white, size: 18),
                      ),
                      onPressed: () => ThemeSelectorBottomSheet.show(context),
                    ),
                ],
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}
