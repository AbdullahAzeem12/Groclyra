class NotificationPreferencesEntity {
  final String userId;
  final bool orderUpdates;
  final bool deliveryTracking;
  final bool priceDropAlerts;
  final bool restockAlerts;
  final bool supportReplies;
  final bool promotions;
  final bool securityAlerts;
  final bool quietHoursEnabled;
  final bool pushChannelEnabled;
  final bool inAppChannelEnabled;
  final bool smsChannelEnabled;
  final DateTime? updatedAt;

  const NotificationPreferencesEntity({
    this.userId = '',
    this.orderUpdates = true,
    bool? deliveryTracking,
    bool? deliveryAlerts,
    bool? priceDropAlerts,
    bool? priceDrops,
    bool? restockAlerts,
    bool? backInStock,
    this.supportReplies = true,
    bool? promotions,
    bool? promotionsAndOffers,
    this.securityAlerts = true,
    this.quietHoursEnabled = false,
    this.pushChannelEnabled = true,
    this.inAppChannelEnabled = true,
    this.smsChannelEnabled = false,
    this.updatedAt,
  })  : deliveryTracking = deliveryTracking ?? deliveryAlerts ?? true,
        priceDropAlerts = priceDropAlerts ?? priceDrops ?? true,
        restockAlerts = restockAlerts ?? backInStock ?? true,
        promotions = promotions ?? promotionsAndOffers ?? false;

  bool get deliveryAlerts => deliveryTracking;
  bool get priceDrops => priceDropAlerts;
  bool get backInStock => restockAlerts;
  bool get promotionsAndOffers => promotions;

  static NotificationPreferencesEntity defaultPreferences(String userId) {
    return NotificationPreferencesEntity(userId: userId);
  }

  NotificationPreferencesEntity copyWith({
    String? userId,
    bool? orderUpdates,
    bool? deliveryTracking,
    bool? deliveryAlerts,
    bool? priceDropAlerts,
    bool? priceDrops,
    bool? restockAlerts,
    bool? backInStock,
    bool? supportReplies,
    bool? promotions,
    bool? promotionsAndOffers,
    bool? securityAlerts,
    bool? quietHoursEnabled,
    bool? pushChannelEnabled,
    bool? inAppChannelEnabled,
    bool? smsChannelEnabled,
    DateTime? updatedAt,
  }) {
    return NotificationPreferencesEntity(
      userId: userId ?? this.userId,
      orderUpdates: orderUpdates ?? this.orderUpdates,
      deliveryTracking: deliveryTracking ?? deliveryAlerts ?? this.deliveryTracking,
      priceDropAlerts: priceDropAlerts ?? priceDrops ?? this.priceDropAlerts,
      restockAlerts: restockAlerts ?? backInStock ?? this.restockAlerts,
      supportReplies: supportReplies ?? this.supportReplies,
      promotions: promotions ?? promotionsAndOffers ?? this.promotions,
      securityAlerts: securityAlerts ?? this.securityAlerts,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      pushChannelEnabled: pushChannelEnabled ?? this.pushChannelEnabled,
      inAppChannelEnabled: inAppChannelEnabled ?? this.inAppChannelEnabled,
      smsChannelEnabled: smsChannelEnabled ?? this.smsChannelEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'orderUpdates': orderUpdates,
        'deliveryTracking': deliveryTracking,
        'deliveryAlerts': deliveryTracking,
        'priceDropAlerts': priceDropAlerts,
        'priceDrops': priceDropAlerts,
        'restockAlerts': restockAlerts,
        'backInStock': restockAlerts,
        'supportReplies': supportReplies,
        'promotions': promotions,
        'promotionsAndOffers': promotions,
        'securityAlerts': securityAlerts,
        'quietHoursEnabled': quietHoursEnabled,
        'pushChannelEnabled': pushChannelEnabled,
        'inAppChannelEnabled': inAppChannelEnabled,
        'smsChannelEnabled': smsChannelEnabled,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory NotificationPreferencesEntity.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime? parseDate(dynamic val) {
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return NotificationPreferencesEntity(
      userId: docId ?? map['userId'] as String? ?? '',
      orderUpdates: map['orderUpdates'] as bool? ?? true,
      deliveryTracking: map['deliveryTracking'] as bool? ?? map['deliveryAlerts'] as bool? ?? true,
      priceDropAlerts: map['priceDropAlerts'] as bool? ?? map['priceDrops'] as bool? ?? true,
      restockAlerts: map['restockAlerts'] as bool? ?? map['backInStock'] as bool? ?? true,
      supportReplies: map['supportReplies'] as bool? ?? true,
      promotions: map['promotions'] as bool? ?? map['promotionsAndOffers'] as bool? ?? false,
      securityAlerts: map['securityAlerts'] as bool? ?? true,
      quietHoursEnabled: map['quietHoursEnabled'] as bool? ?? false,
      pushChannelEnabled: map['pushChannelEnabled'] as bool? ?? true,
      inAppChannelEnabled: map['inAppChannelEnabled'] as bool? ?? true,
      smsChannelEnabled: map['smsChannelEnabled'] as bool? ?? false,
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
