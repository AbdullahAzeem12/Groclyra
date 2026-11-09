import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/features/notifications/data/notifications_repository.dart';
import '../../domain/entities/delivery_task_entity.dart';

/// SQL-backed RiderRepository (SQLite).
class RiderRepository {
  final AppDatabase _database;

  RiderRepository({
    dynamic firestore, // Kept dynamic for legacy test compatibility
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  // ──────────────────────────────────────────────────────────────
  // STREAMS
  // ──────────────────────────────────────────────────────────────

  /// Real-time stream of delivery tasks assigned to this rider from SQLite.
  Stream<List<DeliveryTaskEntity>> streamTasksForRider(String riderId) async* {
    yield await getDeliveryTasks(riderId: riderId);

    yield* _database.watchTable('delivery_tasks').asyncMap((_) async {
      return await getDeliveryTasks(riderId: riderId);
    });
  }

  /// Real-time stream of available (unassigned) delivery tasks from SQLite.
  Stream<List<DeliveryTaskEntity>> streamAvailableTasks() async* {
    yield await _getAvailableTasks();

    yield* _database.watchTable('delivery_tasks').asyncMap((_) async {
      return await _getAvailableTasks();
    });
  }

  Future<List<DeliveryTaskEntity>> _getAvailableTasks() async {
    try {
      final rows = await _database.query(
        'delivery_tasks',
        where: 'status = ?',
        whereArgs: [DeliveryTaskStatus.available.name],
        orderBy: 'assignedAt DESC',
      );
      return rows.map(_taskFromRow).whereType<DeliveryTaskEntity>().toList();
    } catch (e) {
      debugPrint('RiderRepository._getAvailableTasks error: $e');
      return <DeliveryTaskEntity>[];
    }
  }

  /// Combined stream: tasks assigned to this rider + all available tasks.
  Stream<List<DeliveryTaskEntity>> streamRiderDashboard(String riderId) async* {
    yield await _getRiderDashboardTasks(riderId);

    yield* _database.watchTable('delivery_tasks').asyncMap((_) async {
      return await _getRiderDashboardTasks(riderId);
    });
  }

  Future<List<DeliveryTaskEntity>> _getRiderDashboardTasks(String riderId) async {
    try {
      final rows = await _database.query(
        'delivery_tasks',
        where: "status IN ('available', 'accepted', 'pickedUp', 'inTransit')",
        orderBy: 'assignedAt DESC',
      );

      final all = rows.map(_taskFromRow).whereType<DeliveryTaskEntity>().toList();
      all.sort((a, b) {
        final aIsRider = a.status != DeliveryTaskStatus.available;
        final bIsRider = b.status != DeliveryTaskStatus.available;
        if (aIsRider && !bIsRider) return -1;
        if (!aIsRider && bIsRider) return 1;
        return b.assignedAt.compareTo(a.assignedAt);
      });
      return all;
    } catch (e) {
      debugPrint('RiderRepository._getRiderDashboardTasks error: $e');
      return <DeliveryTaskEntity>[];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // ONE-SHOT READ
  // ──────────────────────────────────────────────────────────────

  Future<List<DeliveryTaskEntity>> getDeliveryTasks({String? riderId}) async {
    try {
      final rows = await _database.query(
        'delivery_tasks',
        where: riderId != null && riderId.isNotEmpty ? 'riderId = ?' : null,
        whereArgs: riderId != null && riderId.isNotEmpty ? [riderId] : null,
        orderBy: 'assignedAt DESC',
      );
      return rows.map(_taskFromRow).whereType<DeliveryTaskEntity>().toList();
    } catch (e) {
      debugPrint('RiderRepository.getDeliveryTasks error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // WRITE OPERATIONS (SQLite)
  // ──────────────────────────────────────────────────────────────

  /// Accepts an available task atomically in SQLite.
  Future<bool> acceptTask(String taskId, String riderId) async {
    try {
      final rows = await _database.query(
        'delivery_tasks',
        where: 'id = ?',
        whereArgs: [taskId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final current = rows.first;
      if (current['status'] != DeliveryTaskStatus.available.name) {
        return false;
      }

      final now = DateTime.now().toIso8601String();
      await _database.update(
        'delivery_tasks',
        {
          'riderId': riderId,
          'status': DeliveryTaskStatus.accepted.name,
          'acceptedAt': now,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      // Multi-portal sync: update order and sub-order status
      final orderId = current['orderId']?.toString();
      final subOrderId = current['subOrderId']?.toString();
      if (orderId != null && subOrderId != null) {
        final riderRows = await _database.query('users', where: 'id = ?', whereArgs: [riderId], limit: 1);
        final riderProfileRows = await _database.query('rider_profiles', where: 'riderId = ?', whereArgs: [riderId], limit: 1);

        final riderName = riderRows.isNotEmpty
            ? riderRows.first['name']?.toString()
            : (riderProfileRows.isNotEmpty ? riderProfileRows.first['fullName']?.toString() : 'Express Courier');
        final riderPhone = riderRows.isNotEmpty
            ? riderRows.first['phone']?.toString()
            : (riderProfileRows.isNotEmpty ? riderProfileRows.first['phone']?.toString() : '');
        final riderVehicle = riderProfileRows.isNotEmpty
            ? '${riderProfileRows.first['vehicleType'] ?? 'Bike'} • ${riderProfileRows.first['vehicleNumber'] ?? ''}'
            : 'Courier Motorcycle';

        await _syncSubOrderStatus(
          orderId: orderId,
          subOrderId: subOrderId,
          newStatus: 'riderAssigned',
          riderId: riderId,
          riderName: riderName,
          riderPhone: riderPhone,
          riderVehicle: riderVehicle,
        );
      }

      _database.notifyTable('delivery_tasks');
      return true;
    } catch (e) {
      debugPrint('RiderRepository.acceptTask error: $e');
      return false;
    }
  }

  /// Updates status of a delivery task in SQLite and synchronizes with customer and seller portals.
  Future<void> updateTaskStatus(String taskId, DeliveryTaskStatus newStatus) async {
    try {
      final now = DateTime.now().toIso8601String();
      final updates = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': now,
      };
      if (newStatus == DeliveryTaskStatus.delivered) {
        updates['deliveredAt'] = now;
      }
      await _database.update(
        'delivery_tasks',
        updates,
        where: 'id = ?',
        whereArgs: [taskId],
      );

      // Fetch task to sync order
      final taskRows = await _database.query('delivery_tasks', where: 'id = ?', whereArgs: [taskId], limit: 1);
      if (taskRows.isNotEmpty) {
        final orderId = taskRows.first['orderId']?.toString();
        final subOrderId = taskRows.first['subOrderId']?.toString();
        if (orderId != null && subOrderId != null) {
          String mappedOrderStatus = 'inTransit';
          if (newStatus == DeliveryTaskStatus.pickedUp) {
            mappedOrderStatus = 'inTransit';
          } else if (newStatus == DeliveryTaskStatus.inTransit) {
            mappedOrderStatus = 'outForDelivery';
          } else if (newStatus == DeliveryTaskStatus.delivered) {
            mappedOrderStatus = 'delivered';
          }
          await _syncSubOrderStatus(
            orderId: orderId,
            subOrderId: subOrderId,
            newStatus: mappedOrderStatus,
          );
        }
      }

      _database.notifyTable('delivery_tasks');
    } catch (e) {
      debugPrint('RiderRepository.updateTaskStatus error: $e');
    }
  }

  /// Verifies customer OTP and marks task as delivered in SQLite.
  Future<bool> completeDeliveryWithOtp(String taskId, String enteredOtp) async {
    try {
      final rows = await _database.query(
        'delivery_tasks',
        where: 'id = ?',
        whereArgs: [taskId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final storedOtp = rows.first['customerOtp']?.toString();
      if (storedOtp == null || storedOtp.trim() != enteredOtp.trim()) {
        return false;
      }
      await updateTaskStatus(taskId, DeliveryTaskStatus.delivered);

      final orderId = rows.first['orderId']?.toString();
      final subOrderId = rows.first['subOrderId']?.toString();
      final riderId = rows.first['riderId']?.toString();
      final earnings = (rows.first['estimatedEarnings'] as num?)?.toDouble() ??
          (rows.first['deliveryFeeEarnings'] as num?)?.toDouble() ??
          150.0;

      // 1. Credit Rider Wallet in SQLite rider_profiles
      if (riderId != null && riderId.isNotEmpty) {
        final rProfiles = await _database.query('rider_profiles', where: 'riderId = ?', whereArgs: [riderId], limit: 1);
        final currentDeliveries = rProfiles.isNotEmpty ? (rProfiles.first['totalDeliveries'] as num?)?.toInt() ?? 0 : 0;
        final currentWallet = rProfiles.isNotEmpty ? (rProfiles.first['walletBalance'] as num?)?.toDouble() ?? 0.0 : 0.0;

        await _database.insertOrReplace('rider_profiles', {
          'riderId': riderId,
          'totalDeliveries': currentDeliveries + 1,
          'walletBalance': currentWallet + earnings,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        _database.notifyTable('rider_profiles');
      }

      // 2. Mark order and sub-orders as delivered in SQLite orders
      if (orderId != null && subOrderId != null) {
        try {
          await _updateSubOrderDelivered(orderId, subOrderId);
        } catch (e) {
          debugPrint('updateSubOrderDelivered error: $e');
        }
      }
      return true;
    } catch (e) {
      debugPrint('RiderRepository.completeDeliveryWithOtp error: $e');
      return false;
    }
  }

  Future<void> _syncSubOrderStatus({
    required String orderId,
    required String subOrderId,
    required String newStatus,
    String? riderId,
    String? riderName,
    String? riderPhone,
    String? riderVehicle,
  }) async {
    final rows = await _database.query('orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
    if (rows.isEmpty) return;
    final existing = Map<String, dynamic>.from(rows.first);

    Map<String, dynamic> fullData = {};
    if (existing['fullDataJson'] != null) {
      try {
        fullData = jsonDecode(existing['fullDataJson'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    final subOrders = List<Map<String, dynamic>>.from(
      (fullData['subOrders'] as List? ?? []).map((s) => Map<String, dynamic>.from(s as Map)),
    );

    for (final sub in subOrders) {
      if (sub['id'] == subOrderId) {
        sub['status'] = newStatus;
        if (riderId != null) sub['riderId'] = riderId;
        if (riderName != null) sub['riderName'] = riderName;
        if (riderPhone != null) sub['riderPhone'] = riderPhone;
        if (riderVehicle != null) sub['riderVehicle'] = riderVehicle;
        break;
      }
    }

    final now = DateTime.now().toIso8601String();
    fullData['subOrders'] = subOrders;
    fullData['status'] = newStatus;
    fullData['updatedAt'] = now;
    if (riderName != null) fullData['assignedRiderName'] = riderName;
    if (riderPhone != null) fullData['assignedRiderPhone'] = riderPhone;
    if (riderVehicle != null) fullData['assignedRiderVehicle'] = riderVehicle;

    existing['subOrdersJson'] = jsonEncode(subOrders);
    existing['fullDataJson'] = jsonEncode(fullData);
    existing['status'] = newStatus;
    existing['updatedAt'] = now;

    await _database.update('orders', existing, where: 'id = ?', whereArgs: [orderId]);
    _database.notifyTable('orders');

    // Dispatch real-time customer notification for outForDelivery and delivered
    final customerId = existing['customerId']?.toString() ?? fullData['customerId']?.toString() ?? '';
    final orderNum = existing['orderNumber']?.toString() ?? orderId;
    if (customerId.isNotEmpty) {
      if (newStatus == 'outForDelivery') {
        NotificationDispatcher().toUser(
          recipientId: customerId,
          kind: 'outForDelivery',
          title: '🚚 Order #$orderNum Out for Delivery!',
          body: 'Your express courier is on the road heading to your doorstep.',
          data: {'orderId': orderId, 'orderNumber': orderNum},
        );
      } else if (newStatus == 'delivered') {
        NotificationDispatcher().toUser(
          recipientId: customerId,
          kind: 'delivered',
          title: '✅ Order #$orderNum Delivered!',
          body: 'Package delivered and verified via customer OTP. Thank you for shopping with Groclyra!',
          data: {'orderId': orderId, 'orderNumber': orderNum},
        );
      }
    }
  }

  Future<void> _updateSubOrderDelivered(String orderId, String subOrderId) async {
    final rows = await _database.query('orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
    if (rows.isEmpty) return;
    final existing = Map<String, dynamic>.from(rows.first);

    Map<String, dynamic> fullData = {};
    if (existing['fullDataJson'] != null) {
      fullData = jsonDecode(existing['fullDataJson'] as String) as Map<String, dynamic>;
    }

    final subOrders = List<Map<String, dynamic>>.from(
      (fullData['subOrders'] as List? ?? []).map((s) => Map<String, dynamic>.from(s as Map)),
    );

    for (final sub in subOrders) {
      if (sub['id'] == subOrderId) {
        sub['status'] = 'delivered';
        break;
      }
    }

    final allDelivered = subOrders.every((s) => s['status'] == 'delivered');
    final now = DateTime.now().toIso8601String();
    fullData['subOrders'] = subOrders;
    if (allDelivered) fullData['status'] = 'delivered';
    fullData['updatedAt'] = now;

    existing['subOrdersJson'] = jsonEncode(subOrders);
    existing['fullDataJson'] = jsonEncode(fullData);
    if (allDelivered) existing['status'] = 'delivered';
    existing['updatedAt'] = now;

    await _database.update('orders', existing, where: 'id = ?', whereArgs: [orderId]);
    _database.notifyTable('orders');

    // Dispatch real-time customer notification
    final customerId = existing['customerId']?.toString() ?? fullData['customerId']?.toString() ?? '';
    final orderNum = existing['orderNumber']?.toString() ?? orderId;
    if (customerId.isNotEmpty && allDelivered) {
      NotificationDispatcher().toUser(
        recipientId: customerId,
        kind: 'delivered',
        title: '✅ Order #$orderNum Delivered!',
        body: 'Package delivered and verified via customer OTP. Thank you for shopping with Groclyra!',
        data: {'orderId': orderId, 'orderNumber': orderNum},
      );
    }
  }

  /// Creates a delivery task document in SQLite.
  Future<void> createDeliveryTask(DeliveryTaskEntity task, {String? orderId}) async {
    final data = _taskToJson(task);
    if (orderId != null) data['orderId'] = orderId;
    final now = DateTime.now().toIso8601String();
    data['createdAt'] = now;
    data['updatedAt'] = now;
    data['assignedAt'] = task.assignedAt.toIso8601String();

    await _database.insertOrReplace('delivery_tasks', data);
    _database.notifyTable('delivery_tasks');
  }

  // ──────────────────────────────────────────────────────────────
  // RIDER EARNINGS (SQLite)
  // ──────────────────────────────────────────────────────────────

  /// Real-time stream of a rider's earnings stats from SQLite.
  Stream<Map<String, double>> streamRiderEarnings(String riderId) async* {
    yield await _computeRiderEarnings(riderId);

    yield* _database.watchTable('delivery_tasks').asyncMap((_) async {
      return await _computeRiderEarnings(riderId);
    });
  }

  Future<Map<String, double>> _computeRiderEarnings(String riderId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    try {
      final rows = await _database.query(
        'delivery_tasks',
        where: 'riderId = ? AND status = ?',
        whereArgs: [riderId, DeliveryTaskStatus.delivered.name],
      );

      double todayEarnings = 0;
      double totalEarnings = 0;
      double codCashInHand = 0;

      for (final row in rows) {
        final earnings = (row['estimatedEarnings'] as num?)?.toDouble() ?? 0;
        final cod = (row['codAmount'] as num?)?.toDouble() ?? 0;
        totalEarnings += earnings;

        final deliveredAtStr = row['deliveredAt']?.toString() ?? row['updatedAt']?.toString();
        if (deliveredAtStr != null) {
          final dt = DateTime.tryParse(deliveredAtStr);
          if (dt != null && dt.isAfter(startOfDay)) {
            todayEarnings += earnings;
            codCashInHand += cod;
          }
        }
      }

      return {
        'todayEarnings': todayEarnings,
        'totalEarnings': totalEarnings,
        'codCashInHand': codCashInHand,
      };
    } catch (e) {
      debugPrint('RiderRepository.streamRiderEarnings error: $e');
      return <String, double>{};
    }
  }

  /// Remits collected COD cash to hub or mobile wallet agent
  Future<bool> remitCodCash({
    required String riderId,
    required double amount,
    required String channel,
    required String referenceNumber,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await AppDatabase.instance.insert('admin_audit_logs', {
        'id': 'remit_${DateTime.now().millisecondsSinceEpoch}',
        'adminId': riderId,
        'action': 'COD_CASH_REMITTANCE',
        'targetType': 'RIDER_PROFILE',
        'targetId': riderId,
        'detailsJson': jsonEncode({
          'amount': amount,
          'channel': channel,
          'referenceNumber': referenceNumber,
          'timestamp': now,
        }),
        'ipAddress': '127.0.0.1 (Local Rider Device)',
        'createdAt': now,
      });

      final db = AppDatabase.instance.database;
      if (db != null) {
        await db.rawUpdate('''
          UPDATE rider_profiles 
          SET totalCodCollected = MAX(0, totalCodCollected - ?)
          WHERE riderId = ?
        ''', [amount, riderId]);
      }
      _database.notifyTable('rider_profiles');
      return true;
    } catch (e) {
      debugPrint('COD Remit error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // PARSING HELPERS
  // ──────────────────────────────────────────────────────────────

  DeliveryTaskEntity? _taskFromRow(Map<String, dynamic> row) {
    try {
      final statusStr = row['status'] as String? ?? DeliveryTaskStatus.available.name;
      final status = DeliveryTaskStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => DeliveryTaskStatus.available,
      );

      final assignedAtRaw = row['assignedAt'];
      final assignedAt = DateTime.tryParse(assignedAtRaw?.toString() ?? '') ?? DateTime.now();

      return DeliveryTaskEntity(
        id: row['id'] as String,
        subOrderId: row['subOrderId'] as String? ?? '',
        orderNumber: row['orderNumber'] as String? ?? '',
        sellerStoreName: row['sellerStoreName'] as String? ?? '',
        sellerAddress: row['sellerAddress'] as String? ?? '',
        sellerPhone: row['sellerPhone'] as String? ?? '',
        customerName: row['customerName'] as String? ?? '',
        customerAddress: row['customerAddress'] as String? ?? '',
        customerPhone: row['customerPhone'] as String? ?? '',
        distanceKm: (row['distanceKm'] as num?)?.toDouble() ?? 0,
        codAmount: (row['codAmount'] as num?)?.toDouble() ?? 0,
        estimatedEarnings: (row['estimatedEarnings'] as num?)?.toDouble() ?? 0,
        status: status,
        customerOtp: row['customerOtp'] as String? ?? '',
        assignedAt: assignedAt,
      );
    } catch (e) {
      debugPrint('RiderRepository._taskFromRow parse error: $e');
      return null;
    }
  }

  Map<String, dynamic> _taskToJson(DeliveryTaskEntity task) => {
        'id': task.id,
        'subOrderId': task.subOrderId,
        'orderNumber': task.orderNumber,
        'sellerStoreName': task.sellerStoreName,
        'sellerAddress': task.sellerAddress,
        'sellerPhone': task.sellerPhone,
        'customerName': task.customerName,
        'customerAddress': task.customerAddress,
        'customerPhone': task.customerPhone,
        'distanceKm': task.distanceKm,
        'codAmount': task.codAmount,
        'estimatedEarnings': task.estimatedEarnings,
        'status': task.status.name,
        'customerOtp': task.customerOtp,
      };
}

// ──────────────────────────────────────────────────────────────
// PROVIDERS
// ──────────────────────────────────────────────────────────────

final riderRepositoryProvider = Provider<RiderRepository>((ref) {
  return RiderRepository();
});

/// Real-time dashboard tasks for a rider (assigned + available)
final riderDashboardStreamProvider =
    StreamProvider.autoDispose.family<List<DeliveryTaskEntity>, String>(
        (ref, riderId) {
  return ref
      .watch(riderRepositoryProvider)
      .streamRiderDashboard(riderId);
});

/// Real-time earnings for a rider
final riderEarningsStreamProvider =
    StreamProvider.autoDispose.family<Map<String, double>, String>(
        (ref, riderId) {
  return ref
      .watch(riderRepositoryProvider)
      .streamRiderEarnings(riderId);
});
