import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/app_notification.dart';

/// Firestore-backed notification repository.
///
/// Everything is additive: the dispatcher below is called from existing
/// flows (`OrderRepository`, KYC review, delivery lifecycle) AFTER their
/// original logic completes — none of those paths were modified otherwise.
class NotificationsRepository {
  NotificationsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Real-time stream of this user's notifications, newest first.
  Stream<List<AppNotification>> streamNotifications(String recipientId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppNotification.fromDoc(d.id, d.data()))
            .toList())
        .handleError((e) {
      debugPrint('NotificationsRepository.streamNotifications error: $e');
      return <AppNotification>[];
    });
  }

  /// Unread count for the given user (real-time).
  Stream<int> streamUnreadCount(String recipientId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: recipientId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((e) {
      debugPrint('NotificationsRepository.streamUnreadCount error: $e');
      return 0;
    });
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('NotificationsRepository.markRead error: $e');
    }
  }

  Future<void> markAllRead(String recipientId) async {
    try {
      final batch = _firestore.batch();
      final snap = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: recipientId)
          .where('isRead', isEqualTo: false)
          .limit(400)
          .get();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('NotificationsRepository.markAllRead error: $e');
    }
  }

  Future<void> clearAll(String recipientId) async {
    try {
      final snap = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: recipientId)
          .limit(400)
          .get();
      if (snap.docs.isEmpty) return;
      // Batched delete in chunks of 400.
      for (var i = 0; i < snap.docs.length; i += 400) {
        final chunk = snap.docs.skip(i).take(400).toList();
        final batch = _firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('NotificationsRepository.clearAll error: $e');
    }
  }
}

/// Fire-and-forget dispatcher used by OTHER repositories to enqueue
/// notifications. Failures never propagate to the caller flow (best-effort,
/// never blocks order placement / KYC etc.).
class NotificationDispatcher {
  NotificationDispatcher(this._firestore);

  final FirebaseFirestore _firestore;

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
      await _firestore.collection('notifications').add({
        'recipientId': recipientId,
        'kind': kind,
        'title': title,
        'body': body,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('NotificationDispatcher.toUser notice: $e');
    }
  }

  /// Sends to every admin (admins are few; one cheap query).
  Future<void> toAllAdmins({
    required String kind,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final doc in snap.docs) {
        await toUser(
          recipientId: doc.id,
          kind: kind,
          title: title,
          body: body,
          data: data,
        );
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
  return NotificationDispatcher(FirebaseFirestore.instance);
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

