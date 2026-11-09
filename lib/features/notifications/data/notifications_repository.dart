import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';
import '../domain/entities/app_notification.dart';

/// Groclyra SQL-backed notification repository (SQLite).
class NotificationsRepository {
  final AppDatabase _database;

  NotificationsRepository({
    dynamic firestore, // Kept dynamic for legacy test compatibility
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  /// Real-time stream of this user's notifications from SQLite, newest first.
  Stream<List<AppNotification>> streamNotifications(String recipientId) async* {
    yield await getNotifications(recipientId);

    yield* _database.watchTable('notifications').asyncMap((_) async {
      return await getNotifications(recipientId);
    });
  }

  Future<List<AppNotification>> getNotifications(String recipientId) async {
    try {
      final rows = await _database.query(
        'notifications',
        where: 'recipientId = ?',
        whereArgs: [recipientId],
        orderBy: 'createdAt DESC',
        limit: 50,
      );

      return rows.map((r) {
        Map<String, dynamic> data = const {};
        if (r['payloadJson'] != null && r['payloadJson'].toString().isNotEmpty) {
          try {
            data = jsonDecode(r['payloadJson'].toString()) as Map<String, dynamic>;
          } catch (_) {}
        }
        return AppNotification(
          id: r['id'].toString(),
          recipientId: r['recipientId']?.toString() ?? '',
          kind: r['type']?.toString() ?? 'system',
          title: r['title']?.toString() ?? '',
          body: r['body']?.toString() ?? '',
          data: data,
          isRead: (r['isRead'] as num?)?.toInt() == 1,
          createdAt: DateTime.tryParse(r['createdAt']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('NotificationsRepository.getNotifications error: $e');
      return <AppNotification>[];
    }
  }

  /// Unread count for the given user (real-time from SQLite).
  Stream<int> streamUnreadCount(String recipientId) async* {
    yield await getUnreadCount(recipientId);

    yield* _database.watchTable('notifications').asyncMap((_) async {
      return await getUnreadCount(recipientId);
    });
  }

  Future<int> getUnreadCount(String recipientId) async {
    try {
      final rows = await _database.query(
        'notifications',
        where: 'recipientId = ? AND isRead = ?',
        whereArgs: [recipientId, 0],
      );
      return rows.length;
    } catch (e) {
      debugPrint('NotificationsRepository.getUnreadCount error: $e');
      return 0;
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _database.update(
        'notifications',
        {'isRead': 1},
        where: 'id = ?',
        whereArgs: [notificationId],
      );
      _database.notifyTable('notifications');
    } catch (e) {
      debugPrint('NotificationsRepository.markRead error: $e');
    }
  }

  Future<void> markAllRead(String recipientId) async {
    try {
      await _database.update(
        'notifications',
        {'isRead': 1},
        where: 'recipientId = ? AND isRead = ?',
        whereArgs: [recipientId, 0],
      );
      _database.notifyTable('notifications');
    } catch (e) {
      debugPrint('NotificationsRepository.markAllRead error: $e');
    }
  }

  Future<void> clearAll(String recipientId) async {
    try {
      await _database.delete(
        'notifications',
        where: 'recipientId = ?',
        whereArgs: [recipientId],
      );
      _database.notifyTable('notifications');
    } catch (e) {
      debugPrint('NotificationsRepository.clearAll error: $e');
    }
  }
}

/// Fire-and-forget dispatcher used by repositories to enqueue notifications into SQLite.
class NotificationDispatcher {
  NotificationDispatcher([dynamic firestoreOrDb])
      : _database = firestoreOrDb is AppDatabase ? firestoreOrDb : AppDatabase.instance;

  final AppDatabase _database;

  /// Sends to one recipient id.
  Future<void> toUser({
    required String recipientId,
    required String kind,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    if (recipientId.isEmpty) return;
    try {
      final id = 'notif_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}';
      await _database.insertOrReplace('notifications', {
        'id': id,
        'recipientId': recipientId,
        'type': kind,
        'title': title,
        'body': body,
        'payloadJson': jsonEncode(data),
        'isRead': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _database.notifyTable('notifications');
    } catch (e) {
      debugPrint('NotificationDispatcher.toUser notice: $e');
    }
  }

  /// Sends to every admin in SQLite.
  Future<void> toAllAdmins({
    required String kind,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final rows = await _database.query(
        'users',
        where: 'role = ?',
        whereArgs: ['admin'],
      );
      for (final r in rows) {
        final id = r['id']?.toString();
        if (id != null && id.isNotEmpty) {
          await toUser(
            recipientId: id,
            kind: kind,
            title: title,
            body: body,
            data: data,
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationDispatcher.toAllAdmins notice: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository());

final notificationDispatcherProvider = Provider<NotificationDispatcher>((ref) {
  return NotificationDispatcher();
});

/// Real-time full inbox for a user id.
final notificationsStreamProvider =
    StreamProvider.autoDispose.family<List<AppNotification>, String>(
        (ref, recipientId) {
  return ref
      .watch(notificationsRepositoryProvider)
      .streamNotifications(recipientId);
});

/// Real-time unread badge count for a user id.
final unreadNotificationsCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, recipientId) {
  return ref
      .watch(notificationsRepositoryProvider)
      .streamUnreadCount(recipientId);
});
