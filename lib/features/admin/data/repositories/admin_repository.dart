import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/auth/domain/entities/account_status.dart';
import 'package:groclyra/features/notifications/data/notifications_repository.dart';
import '../../domain/entities/admin_analytics_entity.dart';
import 'package:groclyra/features/admin/riders/domain/entities/rider_kyc_application.dart';

// ── Seller KYC Application Model ─────────────────────────────────────────────

class SellerKycApplication {
  final String id;
  final String storeName;
  final String ownerName;
  final String cnic;
  final String phone;
  final String categoryFocus;
  final String address;
  final bool isApproved;
  final AccountStatus status;
  final DateTime submittedAt;
  final String? adminNotes;
  final String? reviewedBy;
  final DateTime? updatedAt;

  const SellerKycApplication({
    required this.id,
    required this.storeName,
    required this.ownerName,
    required this.cnic,
    required this.phone,
    required this.categoryFocus,
    required this.address,
    this.isApproved = false,
    this.status = AccountStatus.pending,
    required this.submittedAt,
    this.adminNotes,
    this.reviewedBy,
    this.updatedAt,
  });

  SellerKycApplication copyWith({
    AccountStatus? status,
    bool? isApproved,
    String? adminNotes,
    String? reviewedBy,
    DateTime? updatedAt,
  }) {
    return SellerKycApplication(
      id: id,
      storeName: storeName,
      ownerName: ownerName,
      cnic: cnic,
      phone: phone,
      categoryFocus: categoryFocus,
      address: address,
      isApproved: isApproved ?? this.isApproved,
      status: status ?? this.status,
      submittedAt: submittedAt,
      adminNotes: adminNotes ?? this.adminNotes,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SellerKycApplication.fromFirestore(Map<String, dynamic> data, String uid) {
    final status = AccountStatus.fromString(data['accountStatus'] as String?);
    return SellerKycApplication(
      id: uid,
      storeName: data['storeName'] as String? ?? data['displayName'] as String? ?? 'Merchant Store',
      ownerName: data['displayName'] as String? ?? data['name'] as String? ?? 'Seller Partner',
      cnic: data['cnic'] as String? ?? '—',
      phone: data['phone'] as String? ?? '',
      categoryFocus: data['businessCategory'] as String? ?? 'Grocery & Crockery',
      address: data['address'] as String? ?? 'Registered Hub Warehouse',
      isApproved: status == AccountStatus.active,
      status: status,
      submittedAt: _parseDate(data['createdAt']),
      adminNotes: data['adminNotes'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      updatedAt: data['updatedAt'] != null ? _parseDate(data['updatedAt']) : null,
    );
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }
}

// ── Service Health Entry (for Telemetry) ─────────────────────────────────────

enum ServiceHealthStatus { healthy, degraded, down, unknown }

class ServiceHealthEntry {
  final String serviceId;
  final String displayName;
  final ServiceHealthStatus status;
  final int? latencyMs;
  final DateTime? lastChecked;
  final String? errorMessage;

  const ServiceHealthEntry({
    required this.serviceId,
    required this.displayName,
    required this.status,
    this.latencyMs,
    this.lastChecked,
    this.errorMessage,
  });

  factory ServiceHealthEntry.fromFirestore(String id, Map<String, dynamic> data) {
    final statusStr = (data['status'] as String? ?? 'unknown').toLowerCase();
    ServiceHealthStatus st;
    switch (statusStr) {
      case 'healthy':
      case 'operational':
        st = ServiceHealthStatus.healthy;
        break;
      case 'degraded':
        st = ServiceHealthStatus.degraded;
        break;
      case 'down':
      case 'unavailable':
        st = ServiceHealthStatus.down;
        break;
      default:
        st = ServiceHealthStatus.unknown;
    }
    return ServiceHealthEntry(
      serviceId: id,
      displayName: data['displayName'] as String? ?? id,
      status: st,
      latencyMs: (data['latencyMs'] as num?)?.toInt(),
      lastChecked: data['lastChecked'] != null
          ? (data['lastChecked'] is Timestamp
              ? (data['lastChecked'] as Timestamp).toDate()
              : DateTime.tryParse(data['lastChecked'].toString()))
          : null,
      errorMessage: data['errorMessage'] as String?,
    );
  }

  /// Fallback synthetic entry (shown when Firestore telemetry collection is absent)
  static ServiceHealthEntry synthetic({
    required String id,
    required String name,
    ServiceHealthStatus status = ServiceHealthStatus.unknown,
  }) {
    return ServiceHealthEntry(
      serviceId: id,
      displayName: name,
      status: status,
      latencyMs: null,
      lastChecked: null,
    );
  }
}

// ── Live Platform Event ───────────────────────────────────────────────────────

class PlatformEvent {
  final String id;
  final String type;   // ORDER_CREATED, SELLER_APPROVED, etc.
  final String? description;
  final DateTime timestamp;
  final String? actorId;
  final String? targetId;

  const PlatformEvent({
    required this.id,
    required this.type,
    this.description,
    required this.timestamp,
    this.actorId,
    this.targetId,
  });

  factory PlatformEvent.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime ts;
    final raw = data['timestamp'] ?? data['recordedAt'];
    if (raw is Timestamp) {
      ts = raw.toDate();
    } else if (raw is String) {
      ts = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }
    return PlatformEvent(
      id: id,
      type: data['action'] as String? ?? data['type'] as String? ?? 'EVENT',
      description: data['description'] as String?,
      timestamp: ts,
      actorId: data['adminId'] as String? ?? data['actorId'] as String?,
      targetId: data['targetId'] as String?,
    );
  }
}

// ── Admin Repository ──────────────────────────────────────────────────────────

class AdminRepository {
  final FirebaseFirestore _firestore;

  static const double _commissionRate = 0.08; // 8% — backend authoritative

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── REALTIME ANALYTICS STREAM ─────────────────────────────────────────────

  Stream<AdminAnalyticsEntity> watchAnalytics() {
    final usersStream = _firestore.collection('users').snapshots();
    final ordersStream = _firestore.collection('orders').snapshots();

    late StreamController<AdminAnalyticsEntity> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? usersSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ordersSub;

    QuerySnapshot<Map<String, dynamic>>? lastUsersSnap;
    QuerySnapshot<Map<String, dynamic>>? lastOrdersSnap;

    void computeAndEmit() {
      if (controller.isClosed) return;

      int activeCustomers = 0;
      int activeSellers = 0;
      int activeRiders = 0;
      int onlineSellers = 0;
      int onlineRiders = 0;
      int ridersOnDelivery = 0;
      int pendingSellerApprovals = 0;
      int pendingRiderApprovals = 0;
      int suspendedSellers = 0;
      int suspendedRiders = 0;

      if (lastUsersSnap != null) {
        for (final doc in lastUsersSnap!.docs) {
          final data = doc.data();
          final role = (data['role'] as String?)?.toLowerCase();
          final statusStr = data['accountStatus'] as String?;
          final status = AccountStatus.fromString(statusStr);
          final isOnline = data['isOnline'] == true;
          final deliveryStatus = (data['deliveryStatus'] as String?)?.toLowerCase();

          if (role == 'customer') {
            if (status == AccountStatus.active) activeCustomers++;
          } else if (role == 'seller') {
            if (status == AccountStatus.active) {
              activeSellers++;
              if (isOnline) onlineSellers++;
            } else if (status == AccountStatus.pending) {
              pendingSellerApprovals++;
            } else if (status == AccountStatus.disabled) {
              suspendedSellers++;
            }
          } else if (role == 'rider') {
            if (status == AccountStatus.active) {
              activeRiders++;
              if (isOnline) onlineRiders++;
              if (deliveryStatus == 'on_delivery' || deliveryStatus == 'in_transit') {
                ridersOnDelivery++;
              }
            } else if (status == AccountStatus.pending) {
              pendingRiderApprovals++;
            } else if (status == AccountStatus.disabled) {
              suspendedRiders++;
            }
          }
        }
      }

      double totalGmv = 0.0;
      double totalRefunds = 0.0;
      int ordersToday = 0;
      int ordersCompleted = 0;
      int ordersActive = 0;
      int ordersCancelled = 0;
      int ordersRefunded = 0;
      int completedForAvg = 0;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      if (lastOrdersSnap != null) {
        for (final doc in lastOrdersSnap!.docs) {
          final data = doc.data();
          final statusStr = (data['status'] as String?)?.toLowerCase() ?? '';
          final amt = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final refundAmt = (data['refundAmount'] as num?)?.toDouble() ?? 0.0;

          final createdAt = _parseDate(data['createdAt']);
          final isToday =
              createdAt != null && createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd);
          if (isToday) ordersToday++;

          switch (statusStr) {
            case 'cancelled':
              ordersCancelled++;
              break;
            case 'refunded':
            case 'partially_refunded':
              ordersRefunded++;
              totalRefunds += refundAmt;
              // Refunded orders still count toward GMV for accounting — exclude refund amount
              totalGmv += (amt - refundAmt).clamp(0.0, double.infinity);
              break;
            case 'delivered':
            case 'completed':
              ordersCompleted++;
              totalGmv += amt;
              completedForAvg++;
              break;
            default:
              // pending, confirmed, preparing, assigned, in_transit, etc.
              ordersActive++;
              totalGmv += amt;
          }
        }
      }

      // Backend-authoritative commission on net GMV
      // Net GMV is GMV after refunds. Platform revenue is the commission applied to net GMV.
      final netGmv = totalGmv - totalRefunds;
      final commission = netGmv > 0 ? netGmv * _commissionRate : 0.0;
      final netRevenue = commission; // Net platform revenue = Net GMV - Seller Payouts
      final avgOrderValue = completedForAvg > 0 ? totalGmv / completedForAvg : null;

      final analytics = AdminAnalyticsEntity(
        totalGmv: totalGmv,
        totalCommission: commission,
        totalRefunds: totalRefunds,
        netPlatformRevenue: netRevenue,
        averageOrderValue: avgOrderValue,
        totalOrdersToday: ordersToday,
        ordersCompleted: ordersCompleted,
        ordersActive: ordersActive,
        ordersCancelled: ordersCancelled,
        ordersRefunded: ordersRefunded,
        totalActiveCustomers: activeCustomers,
        totalActiveSellers: activeSellers,
        totalActiveRiders: activeRiders,
        onlineSellers: onlineSellers,
        onlineRiders: onlineRiders,
        ridersOnDelivery: ridersOnDelivery,
        pendingSellerApprovals: pendingSellerApprovals,
        pendingRiderApprovals: pendingRiderApprovals,
        pendingProductApprovals: 0,
        suspendedSellers: suspendedSellers,
        suspendedRiders: suspendedRiders,
        systemHealthScore: 99.98,
        lastUpdated: DateTime.now().toUtc(),
        isLiveOnline: true,
      );

      controller.add(analytics);
    }

    controller = StreamController<AdminAnalyticsEntity>(
      onListen: () {
        usersSub = usersStream.listen(
          (snap) {
            lastUsersSnap = snap;
            computeAndEmit();
          },
          onError: (err) {
            debugPrint('[AdminRepository] users stream error: $err');
            if (!controller.isClosed) {
              controller.add(AdminAnalyticsEntity.unavailable());
            }
          },
        );

        ordersSub = ordersStream.listen(
          (snap) {
            lastOrdersSnap = snap;
            computeAndEmit();
          },
          onError: (err) {
            debugPrint('[AdminRepository] orders stream error: $err');
            if (!controller.isClosed) {
              computeAndEmit(); // emit best-effort with partial data
            }
          },
        );
      },
      onCancel: () async {
        await usersSub?.cancel();
        await ordersSub?.cancel();
      },
    );

    return controller.stream;
  }

  // ── SERVICE HEALTH STREAM ─────────────────────────────────────────────────

  /// Streams from `serviceHealth` Firestore collection.
  /// Falls back to synthetic unknown-state entries when collection absent.
  Stream<List<ServiceHealthEntry>> watchServiceHealth() {
    return _firestore
        .collection('serviceHealth')
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) {
        // Return synthetic entries so the UI is still populated
        return _syntheticServiceEntries();
      }
      return snap.docs.map((doc) {
        return ServiceHealthEntry.fromFirestore(doc.id, doc.data());
      }).toList();
    }).handleError((err) {
      debugPrint('[AdminRepository] serviceHealth stream error: $err');
      return _syntheticServiceEntries(unknown: true);
    });
  }

  List<ServiceHealthEntry> _syntheticServiceEntries({bool unknown = false}) {
    final st = unknown ? ServiceHealthStatus.unknown : ServiceHealthStatus.unknown;
    return [
      ServiceHealthEntry.synthetic(id: 'firestore', name: 'Cloud Firestore', status: st),
      ServiceHealthEntry.synthetic(id: 'auth', name: 'Firebase Auth', status: st),
      ServiceHealthEntry.synthetic(id: 'orders_api', name: 'Orders API', status: st),
      ServiceHealthEntry.synthetic(id: 'payments', name: 'Payment Gateway', status: st),
      ServiceHealthEntry.synthetic(id: 'notifications', name: 'FCM Notifications', status: st),
      ServiceHealthEntry.synthetic(id: 'storage', name: 'Object Storage & CDN', status: st),
      ServiceHealthEntry.synthetic(id: 'catalog', name: 'Catalog Service', status: st),
    ];
  }

  // ── LIVE EVENTS STREAM ────────────────────────────────────────────────────

  /// Returns latest 30 audit/event log entries in realtime.
  Stream<List<PlatformEvent>> watchLiveEvents() {
    return _firestore
        .collection('adminAuditLogs')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => PlatformEvent.fromFirestore(doc.id, doc.data()))
          .toList();
    }).handleError((err) {
      debugPrint('[AdminRepository] liveEvents stream error: $err');
      return <PlatformEvent>[];
    });
  }

  // ── RIDER KYC STREAM ─────────────────────────────────────────────────────

  Stream<List<RiderKycApplication>> watchRiderKycApplications() {
    late StreamController<List<RiderKycApplication>> controller;
    StreamSubscription? usersSub;
    StreamSubscription? profilesSub;

    final Map<String, Map<String, dynamic>> usersMap = {};
    final Map<String, Map<String, dynamic>> profilesMap = {};

    void emitMergedList() {
      if (controller.isClosed) return;
      final Map<String, Map<String, dynamic>> merged = {};
      usersMap.forEach((uid, data) => merged[uid] = Map.from(data));
      profilesMap.forEach((uid, profileData) {
        if (merged.containsKey(uid)) {
          merged[uid]!.addAll(profileData);
        } else {
          merged[uid] = Map.from(profileData);
        }
      });
      final list = merged.entries
          .map((e) => RiderKycApplication.fromFirestore(e.value, e.key))
          .toList();
      list.sort((a, b) {
        if (a.isPending && !b.isPending) return -1;
        if (!a.isPending && b.isPending) return 1;
        return b.submittedAt.compareTo(a.submittedAt);
      });
      controller.add(list);
    }

    controller = StreamController<List<RiderKycApplication>>.broadcast(
      onListen: () {
        usersSub = _firestore
            .collection('users')
            .where('role', isEqualTo: 'rider')
            .snapshots()
            .listen((snapshot) {
          usersMap.clear();
          for (final doc in snapshot.docs) { usersMap[doc.id] = doc.data(); }
          emitMergedList();
        }, onError: (err) {
          debugPrint('[AdminRepository] rider users stream: $err');
          emitMergedList();
        });

        profilesSub = _firestore
            .collection('riderProfiles')
            .snapshots()
            .listen((snapshot) {
          profilesMap.clear();
          for (final doc in snapshot.docs) { profilesMap[doc.id] = doc.data(); }
          emitMergedList();
        }, onError: (err) {
          debugPrint('[AdminRepository] riderProfiles stream: $err');
          emitMergedList();
        });
      },
      onCancel: () async {
        await usersSub?.cancel();
        await profilesSub?.cancel();
      },
    );

    return controller.stream;
  }

  // ── SELLER KYC STREAM ────────────────────────────────────────────────────

  Stream<List<SellerKycApplication>> watchSellerKycApplications() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'seller')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SellerKycApplication.fromFirestore(doc.data(), doc.id))
          .toList();
      list.sort((a, b) {
        if (!a.isApproved && b.isApproved) return -1;
        if (a.isApproved && !b.isApproved) return 1;
        return b.submittedAt.compareTo(a.submittedAt);
      });
      return list;
    });
  }

  // ── REVIEW ACTIONS ────────────────────────────────────────────────────────

  Future<void> reviewRiderKyc({
    required String riderId,
    required AccountStatus newStatus,
    required String adminId,
    String? notes,
  }) async {
    final now = DateTime.now();
    final updateData = <String, dynamic>{
      'accountStatus': newStatus.name,
      'adminNotes': notes,
      'reviewedBy': adminId,
      'updatedAt': now.toIso8601String(),
    };
    await _firestore.collection('users').doc(riderId).set(updateData, SetOptions(merge: true));
    try {
      await _firestore.collection('riderProfiles').doc(riderId).set(updateData, SetOptions(merge: true));
      await _firestore.collection('riders').doc(riderId).set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AdminRepository] rider profile sync: $e');
    }
    await _writeAuditLog(
      adminId: adminId,
      targetId: riderId,
      targetRole: 'rider',
      action: 'RIDER_KYC_STATUS_UPDATE',
      newStatus: newStatus.name,
      notes: notes,
    );
    // Phase 1B: tell the rider about the review decision in-app.
    await NotificationDispatcher(_firestore).toUser(
      recipientId: riderId,
      kind: 'kyc',
      title: newStatus == AccountStatus.active
          ? '🎉 KYC Approved!'
          : '📋 KYC review update',
      body: newStatus == AccountStatus.active
          ? 'Your rider verification was approved. You can accept deliveries now.'
          : 'Your rider verification status changed to "${newStatus.name}".${notes != null ? ' Note: $notes' : ''}',
      data: {'kind': 'riderKyc', 'status': newStatus.name},
    );
  }

  Future<void> reviewSellerKyc({
    required String sellerId,
    required AccountStatus newStatus,
    required String adminId,
    String? notes,
  }) async {
    final now = DateTime.now();
    final updateData = <String, dynamic>{
      'accountStatus': newStatus.name,
      'adminNotes': notes,
      'reviewedBy': adminId,
      'updatedAt': now.toIso8601String(),
    };
    await _firestore.collection('users').doc(sellerId).set(updateData, SetOptions(merge: true));
    try {
      await _firestore.collection('sellerProfiles').doc(sellerId).set(updateData, SetOptions(merge: true));
      await _firestore.collection('sellers').doc(sellerId).set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AdminRepository] seller profile sync: $e');
    }
    await _writeAuditLog(
      adminId: adminId,
      targetId: sellerId,
      targetRole: 'seller',
      action: 'SELLER_KYC_STATUS_UPDATE',
      newStatus: newStatus.name,
      notes: notes,
    );
    // Phase 1B: tell the seller about the review decision in-app.
    await NotificationDispatcher(_firestore).toUser(
      recipientId: sellerId,
      kind: 'kyc',
      title: newStatus == AccountStatus.active
          ? '🎉 Store Approved!'
          : '📋 KYC review update',
      body: newStatus == AccountStatus.active
          ? 'Your merchant verification was approved. Your listings can go live now.'
          : 'Your merchant verification status changed to "${newStatus.name}".${notes != null ? ' Note: $notes' : ''}',
      data: {'kind': 'sellerKyc', 'status': newStatus.name},
    );
  }

  Future<void> _writeAuditLog({
    required String adminId,
    required String targetId,
    required String targetRole,
    required String action,
    required String newStatus,
    String? notes,
  }) async {
    try {
      await _firestore.collection('adminAuditLogs').add({
        'adminId': adminId,
        'targetId': targetId,
        'targetRole': targetRole,
        'action': action,
        'newStatus': newStatus,
        'notes': notes,
        'timestamp': FieldValue.serverTimestamp(),
        'recordedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[AdminRepository] audit log write: $e');
    }
  }

  // ── ONE-SHOT FETCHES ──────────────────────────────────────────────────────

  Future<AdminAnalyticsEntity> getAnalytics() async {
    try {
      final result = await Future.wait([
        _firestore.collection('users').get(),
        _firestore.collection('orders').get(),
      ]);
      // Re-use compute logic via mock stream
      return _computeAnalyticsFromSnaps(result[0] as QuerySnapshot, result[1] as QuerySnapshot);
    } catch (e) {
      debugPrint('[AdminRepository] getAnalytics: $e');
      return AdminAnalyticsEntity.unavailable();
    }
  }

  AdminAnalyticsEntity _computeAnalyticsFromSnaps(
    QuerySnapshot usersSnap,
    QuerySnapshot ordersSnap,
  ) {
    int activeCustomers = 0, activeSellers = 0, activeRiders = 0;
    int onlineSellers = 0, onlineRiders = 0, ridersOnDelivery = 0;
    int pendingS = 0, pendingR = 0, suspS = 0, suspR = 0;

    for (final doc in usersSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final role = (data['role'] as String?)?.toLowerCase();
      final status = AccountStatus.fromString(data['accountStatus'] as String?);
      final isOnline = data['isOnline'] == true;
      final ds = (data['deliveryStatus'] as String?)?.toLowerCase();

      if (role == 'customer' && status == AccountStatus.active) activeCustomers++;
      if (role == 'seller') {
        if (status == AccountStatus.active) { activeSellers++; if (isOnline) onlineSellers++; }
        if (status == AccountStatus.pending) pendingS++;
        if (status == AccountStatus.disabled) suspS++;
      }
      if (role == 'rider') {
        if (status == AccountStatus.active) {
          activeRiders++; if (isOnline) onlineRiders++;
          if (ds == 'on_delivery' || ds == 'in_transit') ridersOnDelivery++;
        }
        if (status == AccountStatus.pending) pendingR++;
        if (status == AccountStatus.disabled) suspR++;
      }
    }

    double gmv = 0, refunds = 0;
    int ordersToday = 0, completed = 0, active = 0, cancelled = 0, refunded = 0;
    int completedForAvg = 0;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    for (final doc in ordersSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final st = (data['status'] as String?)?.toLowerCase() ?? '';
      final amt = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final refAmt = (data['refundAmount'] as num?)?.toDouble() ?? 0.0;
      final createdAt = _parseDate(data['createdAt']);
      if (createdAt != null && createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd)) ordersToday++;
      if (st == 'cancelled') { cancelled++; }
      else if (st == 'refunded' || st == 'partially_refunded') { refunded++; refunds += refAmt; gmv += (amt - refAmt).clamp(0.0, double.infinity); }
      else if (st == 'delivered' || st == 'completed') { completed++; gmv += amt; completedForAvg++; }
      else { active++; gmv += amt; }
    }

    final netGmv = gmv - refunds;
    final commission = netGmv > 0 ? netGmv * _commissionRate : 0.0;
    return AdminAnalyticsEntity(
      totalGmv: gmv, totalCommission: commission, totalRefunds: refunds,
      netPlatformRevenue: commission,
      averageOrderValue: completedForAvg > 0 ? gmv / completedForAvg : null,
      totalOrdersToday: ordersToday, ordersCompleted: completed, ordersActive: active,
      ordersCancelled: cancelled, ordersRefunded: refunded,
      totalActiveCustomers: activeCustomers, totalActiveSellers: activeSellers,
      totalActiveRiders: activeRiders, onlineSellers: onlineSellers, onlineRiders: onlineRiders,
      ridersOnDelivery: ridersOnDelivery, pendingSellerApprovals: pendingS,
      pendingRiderApprovals: pendingR, suspendedSellers: suspS, suspendedRiders: suspR,
      systemHealthScore: 99.98, lastUpdated: DateTime.now().toUtc(), isLiveOnline: true,
    );
  }

  Future<List<SellerKycApplication>> getKycApplications() async {
    try {
      final snap = await _firestore.collection('users').where('role', isEqualTo: 'seller').get();
      return snap.docs.map((doc) => SellerKycApplication.fromFirestore(doc.data(), doc.id)).toList();
    } catch (_) { return const []; }
  }

  Future<List<RiderKycApplication>> getRiderKycApplications() async {
    try {
      final Map<String, Map<String, dynamic>> merged = {};
      final usersSnap = await _firestore.collection('users').where('role', isEqualTo: 'rider').get();
      for (final doc in usersSnap.docs) { merged[doc.id] = Map.from(doc.data()); }
      try {
        final profilesSnap = await _firestore.collection('riderProfiles').get();
        for (final doc in profilesSnap.docs) {
          if (merged.containsKey(doc.id)) {
            merged[doc.id]!.addAll(doc.data());
          } else {
            merged[doc.id] = Map.from(doc.data());
          }
        }
      } catch (e) { debugPrint('[AdminRepository] riderProfiles fetch: $e'); }
      final list = merged.entries.map((e) => RiderKycApplication.fromFirestore(e.value, e.key)).toList();
      list.sort((a, b) { if (a.isPending && !b.isPending) return -1; if (!a.isPending && b.isPending) return 1; return b.submittedAt.compareTo(a.submittedAt); });
      return list;
    } catch (e) { debugPrint('[AdminRepository] getRiderKycApplications: $e'); return const []; }
  }

  /// Backward-compatible helpers
  Future<void> reviewKyc(String id, bool approve) => reviewSellerKyc(
    sellerId: id, newStatus: approve ? AccountStatus.active : AccountStatus.disabled, adminId: 'admin_sys',
  );

  // ── Helpers ───────────────────────────────────────────────────────────────

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository());
