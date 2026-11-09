import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';
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
    if (raw is DateTime) return raw;
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
    final statusStr = (data['status'] as String? ?? 'healthy').toLowerCase();
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
        st = ServiceHealthStatus.healthy;
    }
    return ServiceHealthEntry(
      serviceId: id,
      displayName: data['displayName'] as String? ?? id,
      status: st,
      latencyMs: (data['latencyMs'] as num?)?.toInt() ?? 5,
      lastChecked: DateTime.now(),
      errorMessage: data['errorMessage'] as String?,
    );
  }

  static ServiceHealthEntry synthetic({
    required String id,
    required String name,
    ServiceHealthStatus status = ServiceHealthStatus.healthy,
  }) {
    return ServiceHealthEntry(
      serviceId: id,
      displayName: name,
      status: status,
      latencyMs: 8,
      lastChecked: DateTime.now(),
    );
  }
}

// ── Live Platform Event ───────────────────────────────────────────────────────

class PlatformEvent {
  final String id;
  final String type;
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
    final raw = data['timestamp'] ?? data['recordedAt'] ?? data['createdAt'];
    if (raw is DateTime) {
      ts = raw;
    } else if (raw is String) {
      ts = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }
    return PlatformEvent(
      id: id,
      type: data['action'] as String? ?? data['type'] as String? ?? 'EVENT',
      description: data['description'] as String? ?? data['notes'] as String?,
      timestamp: ts,
      actorId: data['adminId'] as String? ?? data['actorId'] as String?,
      targetId: data['targetId'] as String?,
    );
  }
}

// ── Admin Repository (SQLite) ────────────────────────────────────────────────

class AdminRepository {
  final AppDatabase _database;
  final NotificationDispatcher _notifier;

  static const double _commissionRate = 0.08; // 8% platform cut

  AdminRepository({
    dynamic firestore, // Kept dynamic for legacy test compatibility
    AppDatabase? database,
  })  : _database = database ?? AppDatabase.instance,
        _notifier = NotificationDispatcher(database ?? AppDatabase.instance);

  // ── REALTIME ANALYTICS STREAM ─────────────────────────────────────────────

  Stream<AdminAnalyticsEntity> watchAnalytics() async* {
    yield await getAnalytics();

    final controller = StreamController<AdminAnalyticsEntity>();

    final sub1 = _database.watchTable('users').listen((_) async {
      if (!controller.isClosed) controller.add(await getAnalytics());
    });
    final sub2 = _database.watchTable('orders').listen((_) async {
      if (!controller.isClosed) controller.add(await getAnalytics());
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    yield* controller.stream;
  }

  // ── SERVICE HEALTH STREAM ─────────────────────────────────────────────────

  Stream<List<ServiceHealthEntry>> watchServiceHealth() async* {
    yield _syntheticServiceEntries();

    yield* _database.watchTable('system_telemetry').asyncMap((_) async {
      return _syntheticServiceEntries();
    });
  }

  List<ServiceHealthEntry> _syntheticServiceEntries() {
    return [
      ServiceHealthEntry.synthetic(id: 'sqlite_db', name: 'Groclyra SQL Database (SQLite)', status: ServiceHealthStatus.healthy),
      ServiceHealthEntry.synthetic(id: 'auth_engine', name: 'Secure Authentication Engine', status: ServiceHealthStatus.healthy),
      ServiceHealthEntry.synthetic(id: 'orders_api', name: 'Reactive Orders Pipeline', status: ServiceHealthStatus.healthy),
      ServiceHealthEntry.synthetic(id: 'payments', name: 'JazzCash / EasyPaisa / PayFast', status: ServiceHealthStatus.healthy),
      ServiceHealthEntry.synthetic(id: 'notifications', name: 'Local Reactive Notifications', status: ServiceHealthStatus.healthy),
      ServiceHealthEntry.synthetic(id: 'catalog', name: 'Unified Multi-Mart Catalog', status: ServiceHealthStatus.healthy),
      ServiceHealthEntry.synthetic(id: 'logistics', name: 'Express Rider Dispatch Engine', status: ServiceHealthStatus.healthy),
    ];
  }

  // ── LIVE EVENTS STREAM ────────────────────────────────────────────────────

  Stream<List<PlatformEvent>> watchLiveEvents() async* {
    yield await _getLiveEvents();

    yield* _database.watchTable('system_telemetry').asyncMap((_) async {
      return await _getLiveEvents();
    });
  }

  Future<List<PlatformEvent>> _getLiveEvents() async {
    try {
      final rows = await _database.query(
        'system_telemetry',
        orderBy: 'recordedAt DESC',
        limit: 30,
      );
      return rows.map((r) {
        Map<String, dynamic> tags = {};
        if (r['tagsJson'] != null) {
          try {
            tags = jsonDecode(r['tagsJson'].toString()) as Map<String, dynamic>;
          } catch (_) {}
        }
        return PlatformEvent(
          id: r['id'].toString(),
          type: r['metricName']?.toString() ?? 'SYSTEM_EVENT',
          description: tags['action']?.toString() ?? tags['notes']?.toString() ?? 'Telemetry Event Recorded',
          timestamp: DateTime.tryParse(r['recordedAt']?.toString() ?? '') ?? DateTime.now(),
          actorId: tags['adminId']?.toString(),
          targetId: tags['targetId']?.toString(),
        );
      }).toList();
    } catch (_) {
      return <PlatformEvent>[];
    }
  }

  // ── RIDER KYC STREAM ─────────────────────────────────────────────────────

  Stream<List<RiderKycApplication>> watchRiderKycApplications() async* {
    yield await getRiderKycApplications();

    final controller = StreamController<List<RiderKycApplication>>();

    final sub1 = _database.watchTable('users').listen((_) async {
      if (!controller.isClosed) controller.add(await getRiderKycApplications());
    });
    final sub2 = _database.watchTable('rider_profiles').listen((_) async {
      if (!controller.isClosed) controller.add(await getRiderKycApplications());
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    yield* controller.stream;
  }

  // ── SELLER KYC STREAM ────────────────────────────────────────────────────

  Stream<List<SellerKycApplication>> watchSellerKycApplications() async* {
    yield await getKycApplications();

    yield* _database.watchTable('users').asyncMap((_) async {
      return await getKycApplications();
    });
  }

  // ── REVIEW ACTIONS ────────────────────────────────────────────────────────

  Future<void> reviewRiderKyc({
    required String riderId,
    required AccountStatus newStatus,
    required String adminId,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final updateData = <String, dynamic>{
      'accountStatus': newStatus.name,
      'updatedAt': now,
    };

    await _database.update('users', updateData, where: 'id = ?', whereArgs: [riderId]);
    await _database.update('rider_profiles', {
      'isKycApproved': newStatus == AccountStatus.active ? 1 : 0,
      'updatedAt': now,
    }, where: 'riderId = ?', whereArgs: [riderId]);

    _database.notifyTable('users');
    _database.notifyTable('rider_profiles');

    await _writeAuditLog(
      adminId: adminId,
      targetId: riderId,
      targetRole: 'rider',
      action: 'RIDER_KYC_STATUS_UPDATE',
      newStatus: newStatus.name,
      notes: notes,
    );

    await _notifier.toUser(
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
    final now = DateTime.now().toIso8601String();
    final updateData = <String, dynamic>{
      'accountStatus': newStatus.name,
      'updatedAt': now,
    };

    await _database.update('users', updateData, where: 'id = ?', whereArgs: [sellerId]);
    await _database.update('seller_profiles', {
      'isKycApproved': newStatus == AccountStatus.active ? 1 : 0,
      'updatedAt': now,
    }, where: 'sellerId = ?', whereArgs: [sellerId]);

    _database.notifyTable('users');
    _database.notifyTable('seller_profiles');

    await _writeAuditLog(
      adminId: adminId,
      targetId: sellerId,
      targetRole: 'seller',
      action: 'SELLER_KYC_STATUS_UPDATE',
      newStatus: newStatus.name,
      notes: notes,
    );

    await _notifier.toUser(
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
      final id = 'audit_${DateTime.now().millisecondsSinceEpoch}';
      await _database.insertOrReplace('system_telemetry', {
        'id': id,
        'metricName': action,
        'metricValue': 1.0,
        'tagsJson': jsonEncode({
          'adminId': adminId,
          'targetId': targetId,
          'targetRole': targetRole,
          'action': action,
          'newStatus': newStatus,
          'notes': notes,
        }),
        'recordedAt': DateTime.now().toIso8601String(),
      });
      _database.notifyTable('system_telemetry');
    } catch (e) {
      debugPrint('[AdminRepository] audit log write: $e');
    }
  }

  // ── ONE-SHOT FETCHES ──────────────────────────────────────────────────────

  Future<AdminAnalyticsEntity> getAnalytics() async {
    try {
      final usersRows = await _database.query('users');
      final ordersRows = await _database.query('orders');

      int activeCustomers = 0, activeSellers = 0, activeRiders = 0;
      int onlineSellers = 0, onlineRiders = 0, ridersOnDelivery = 0;
      int pendingS = 0, pendingR = 0, suspS = 0, suspR = 0;

      for (final data in usersRows) {
        final role = (data['role'] as String?)?.toLowerCase();
        final status = AccountStatus.fromString(data['accountStatus'] as String?);
        final isOnline = data['isOnline'] == 1 || data['isOnline'] == true;
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

      for (final data in ordersRows) {
        final st = (data['status'] as String?)?.toLowerCase() ?? '';
        final amt = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final refAmt = (data['refundAmount'] as num?)?.toDouble() ?? 0.0;
        final createdAtStr = data['createdAt']?.toString();
        final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

        if (createdAt != null && createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd)) {
          ordersToday++;
        }
        if (st == 'cancelled') {
          cancelled++;
        } else if (st == 'refunded' || st == 'partially_refunded') {
          refunded++;
          refunds += refAmt;
          gmv += (amt - refAmt).clamp(0.0, double.infinity);
        } else if (st == 'delivered' || st == 'completed') {
          completed++;
          gmv += amt;
          completedForAvg++;
        } else {
          active++;
          gmv += amt;
        }
      }

      final netGmv = gmv - refunds;
      final commission = netGmv > 0 ? netGmv * _commissionRate : 0.0;

      return AdminAnalyticsEntity(
        totalGmv: gmv,
        totalCommission: commission,
        totalRefunds: refunds,
        netPlatformRevenue: commission,
        averageOrderValue: completedForAvg > 0 ? gmv / completedForAvg : null,
        totalOrdersToday: ordersToday,
        ordersCompleted: completed,
        ordersActive: active,
        ordersCancelled: cancelled,
        ordersRefunded: refunded,
        totalActiveCustomers: activeCustomers,
        totalActiveSellers: activeSellers,
        totalActiveRiders: activeRiders,
        onlineSellers: onlineSellers,
        onlineRiders: onlineRiders,
        ridersOnDelivery: ridersOnDelivery,
        pendingSellerApprovals: pendingS,
        pendingRiderApprovals: pendingR,
        suspendedSellers: suspS,
        suspendedRiders: suspR,
        systemHealthScore: 99.98,
        lastUpdated: DateTime.now().toUtc(),
        isLiveOnline: true,
      );
    } catch (e) {
      debugPrint('[AdminRepository] getAnalytics error: $e');
      return AdminAnalyticsEntity.unavailable();
    }
  }

  Future<List<SellerKycApplication>> getKycApplications() async {
    try {
      final rows = await _database.query(
        'users',
        where: 'role = ?',
        whereArgs: ['seller'],
      );
      final list = rows.map((doc) => SellerKycApplication.fromFirestore(doc, doc['id'].toString())).toList();
      list.sort((a, b) {
        if (!a.isApproved && b.isApproved) return -1;
        if (a.isApproved && !b.isApproved) return 1;
        return b.submittedAt.compareTo(a.submittedAt);
      });
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<List<RiderKycApplication>> getRiderKycApplications() async {
    try {
      final Map<String, Map<String, dynamic>> merged = {};
      final usersRows = await _database.query(
        'users',
        where: 'role = ?',
        whereArgs: ['rider'],
      );
      for (final r in usersRows) {
        merged[r['id'].toString()] = Map<String, dynamic>.from(r);
      }

      try {
        final profileRows = await _database.query('rider_profiles');
        for (final p in profileRows) {
          final id = p['riderId']?.toString();
          if (id != null && merged.containsKey(id)) {
            merged[id]!.addAll(p);
          } else if (id != null) {
            merged[id] = Map<String, dynamic>.from(p);
          }
        }
      } catch (_) {}

      final list = merged.entries.map((e) => RiderKycApplication.fromFirestore(e.value, e.key)).toList();
      list.sort((a, b) {
        if (a.isPending && !b.isPending) return -1;
        if (!a.isPending && b.isPending) return 1;
        return b.submittedAt.compareTo(a.submittedAt);
      });
      return list;
    } catch (e) {
      debugPrint('[AdminRepository] getRiderKycApplications: $e');
      return const [];
    }
  }

  Future<void> reviewKyc(String id, bool approve) => reviewSellerKyc(
    sellerId: id,
    newStatus: approve ? AccountStatus.active : AccountStatus.disabled,
    adminId: 'admin_sys',
  );
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository());
