/// A single in-app notification delivered to a specific user.
///
/// Phase 1B: the notification centre works purely on Firestore (real-time
/// streams), so it functions across devices without needing FCM. The
/// `NotificationDispatcher` writes these docs from existing repository
/// flows. A future FCM push layer will simply enqueue the same shapes.
class AppNotification {
  final String id;
  final String recipientId;

  /// machine key: order | delivery | kyc | payment | system
  final String kind;

  final String title;
  final String body;

  /// Optional payload for deep navigation, e.g. {'orderId': 'ord_...', 'route': '/customer/tracking/ord_...'}
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.kind,
    required this.title,
    required this.body,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      kind: kind,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromDoc(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return AppNotification(
      id: id,
      recipientId: data['recipientId'] as String? ?? '',
      kind: data['kind'] as String? ?? 'system',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      data: data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : const {},
      isRead: data['isRead'] as bool? ?? false,
      createdAt: created is DateTime
          ? created
          : (created != null
              ? DateTime.tryParse(created.toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() => {
        'recipientId': recipientId,
        'kind': kind,
        'title': title,
        'body': body,
        'data': data,
        'isRead': isRead,
        'createdAt': createdAt,
      };
}
