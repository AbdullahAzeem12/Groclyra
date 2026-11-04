import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/notifications_repository.dart';
import '../../domain/entities/app_notification.dart';

/// Current-user notification focus: reads the authenticated user id from the
/// auth controller so every screen can consume the stream without plumbing.
final myNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(authControllerProvider).user?.id ?? '';
  if (uid.isEmpty) return const Stream.empty();
  return ref.watch(notificationsRepositoryProvider).streamNotifications(uid);
});

final myUnreadCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authControllerProvider).user?.id ?? '';
  if (uid.isEmpty) return const Stream.empty();
  return ref.watch(notificationsRepositoryProvider).streamUnreadCount(uid);
});

/// Imperative actions for the notification centre UI.
class NotificationsActions {
  NotificationsActions(this._ref);

  final Ref _ref;

  void markRead(String id) {
    _ref.read(notificationsRepositoryProvider).markRead(id);
  }

  void markAllMine() {
    final uid = _ref.read(authControllerProvider).user?.id ?? '';
    if (uid.isNotEmpty) {
      _ref.read(notificationsRepositoryProvider).markAllRead(uid);
    }
  }

  void clearAllMine() {
    final uid = _ref.read(authControllerProvider).user?.id ?? '';
    if (uid.isNotEmpty) {
      _ref.read(notificationsRepositoryProvider).clearAll(uid);
    }
  }
}

final notificationsActionsProvider = Provider<NotificationsActions>(
    (ref) => NotificationsActions(ref));
