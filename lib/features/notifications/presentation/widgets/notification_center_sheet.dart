import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../shared/animations/spring_touch_scale.dart';
import '../controllers/notifications_controller.dart';

/// Badge-counting bell button. Watching it anywhere instantaneously shows
/// the real-time unread count from Firestore.
class NotificationBellIconButton extends ConsumerWidget {
  const NotificationBellIconButton({super.key, this.iconColor, this.size = 20});

  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(myUnreadCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread = unreadAsync.maybeWhen(data: (c) => c, orElse: () => 0);

    return SpringTouchScale(
      onTap: () => showNotificationCenter(context, ref),
      scaleFactor: 0.88,
      navigationDelayMs: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: iconColor ?? (isDark ? Colors.white : const Color(0xFF111827)),
            size: size > 20 ? size : size + 4,
          ),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the real-time notification centre as a bottom sheet.
void showNotificationCenter(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _NotificationCenterSheet(),
  );
}

class _NotificationCenterSheet extends ConsumerWidget {
  const _NotificationCenterSheet();

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'delivery':
        return Icons.local_shipping_rounded;
      case 'kyc':
        return Icons.verified_user_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'system':
        return Icons.settings_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _tintFor(String kind) {
    switch (kind) {
      case 'order':
        return const Color(0xFF10B981);
      case 'delivery':
        return const Color(0xFF06B6D4);
      case 'kyc':
        return const Color(0xFF8B5CF6);
      case 'payment':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF1B6BFF);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color surface = isDark ? const Color(0xFF131A26) : Colors.white;
    Color tileBg = isDark ? const Color(0xFF1A2333) : const Color(0xFFF6F8FC);
    Color textMain = isDark ? Colors.white : const Color(0xFF111827);
    Color textSub = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.55);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: textSub.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                  ),
                  SpringTouchScale(
                    onTap: () =>
                        ref.read(notificationsActionsProvider).markAllMine(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _tintFor('order'),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear all',
                    icon: Icon(Icons.delete_sweep_rounded, color: textSub),
                    onPressed: () =>
                        ref.read(notificationsActionsProvider).clearAllMine(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notificationsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load notifications',
                    style: TextStyle(color: textSub),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 56, color: textSub.withValues(alpha: 0.4)),
                            const SizedBox(height: 10),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textMain),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order updates, earnings and KYC results appear here in real time.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 12, color: textSub),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      final tint = _tintFor(n.kind);
                      return Container(
                        decoration: BoxDecoration(
                          color: n.isRead ? tileBg : tint.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: tint.withValues(
                                alpha: n.isRead ? 0.06 : 0.25),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tint.withValues(alpha: 0.15),
                            child: Icon(_iconFor(n.kind),
                                color: tint, size: 20),
                          ),
                          title: Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: textMain,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(fontSize: 12, color: textSub),
                            ),
                          ),
                          trailing: Text(
                            DateTimeFormatter.formatRelativeTime(n.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: textSub,
                            ),
                          ),
                          onTap: () {
                            if (!n.isRead) {
                              ref.read(notificationsActionsProvider)
                                  .markRead(n.id);
                            }
                            final route = n.data['route'] as String?;
                            if (route != null && route.startsWith('/')) {
                              Navigator.pop(context);
                              try {
                                context.push(route);
                              } catch (_) {
                                // navigation may be unavailable off-shell — ignore
                              }
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
