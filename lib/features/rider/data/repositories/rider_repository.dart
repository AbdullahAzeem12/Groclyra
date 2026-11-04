import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/delivery_task_entity.dart';

/// Firestore-backed RiderRepository.
///
/// Delivery tasks are derived from the `orders` collection — specifically
/// the `subOrders` embedded array — and also from a dedicated `deliveryTasks`
/// collection that is written when a rider is assigned to a sub-order.
class RiderRepository {
  final FirebaseFirestore _firestore;

  RiderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ──────────────────────────────────────────────────────────────
  // STREAMS
  // ──────────────────────────────────────────────────────────────

  /// Real-time stream of delivery tasks assigned to this rider.
  Stream<List<DeliveryTaskEntity>> streamTasksForRider(String riderId) {
    return _firestore
        .collection('deliveryTasks')
        .where('riderId', isEqualTo: riderId)
        .orderBy('assignedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => _taskFromDoc(doc))
            .whereType<DeliveryTaskEntity>()
            .toList())
        .handleError((e) {
      debugPrint('RiderRepository.streamTasksForRider error: $e');
      return <DeliveryTaskEntity>[];
    });
  }

  /// Real-time stream of available (unassigned) delivery tasks.
  Stream<List<DeliveryTaskEntity>> streamAvailableTasks() {
    return _firestore
        .collection('deliveryTasks')
        .where('status', isEqualTo: DeliveryTaskStatus.available.name)
        .orderBy('assignedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => _taskFromDoc(doc))
            .whereType<DeliveryTaskEntity>()
            .toList())
        .handleError((e) {
      debugPrint('RiderRepository.streamAvailableTasks error: $e');
      return <DeliveryTaskEntity>[];
    });
  }

  /// Combined stream: tasks assigned to this rider + all available tasks.
  Stream<List<DeliveryTaskEntity>> streamRiderDashboard(String riderId) {
    // Merge assigned and available tasks into one list
    return _firestore
        .collection('deliveryTasks')
        .where('status', whereIn: [
          DeliveryTaskStatus.available.name,
          DeliveryTaskStatus.accepted.name,
          DeliveryTaskStatus.pickedUp.name,
          DeliveryTaskStatus.inTransit.name,
        ])
        .orderBy('assignedAt', descending: false)
        .snapshots()
        .map((snap) {
          final all = snap.docs
              .map((doc) => _taskFromDoc(doc))
              .whereType<DeliveryTaskEntity>()
              .toList();
          // Put this rider's accepted tasks first, then available ones
          all.sort((a, b) {
            final aIsRider = a.status != DeliveryTaskStatus.available;
            final bIsRider = b.status != DeliveryTaskStatus.available;
            if (aIsRider && !bIsRider) return -1;
            if (!aIsRider && bIsRider) return 1;
            return b.assignedAt.compareTo(a.assignedAt);
          });
          return all;
        })
        .handleError((e) {
          debugPrint('RiderRepository.streamRiderDashboard error: $e');
          return <DeliveryTaskEntity>[];
        });
  }

  // ──────────────────────────────────────────────────────────────
  // ONE-SHOT READ
  // ──────────────────────────────────────────────────────────────

  Future<List<DeliveryTaskEntity>> getDeliveryTasks({String? riderId}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('deliveryTasks')
          .orderBy('assignedAt', descending: true);
      if (riderId != null) {
        query = query.where('riderId', isEqualTo: riderId);
      }
      final snap = await query.get();
      return snap.docs
          .map((doc) => _taskFromDoc(doc))
          .whereType<DeliveryTaskEntity>()
          .toList();
    } catch (e) {
      debugPrint('RiderRepository.getDeliveryTasks error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // WRITE OPERATIONS
  // ──────────────────────────────────────────────────────────────

  /// Accepts an available task (sets riderId and status → accepted).
  ///
  /// Upgraded (Phase 1.3): previously a plain `update()` — two riders could
  /// race-claim the same task and "last writer wins" silently robbed the
  /// delivery from the first rider. Now a transaction re-reads the task and
  /// only claims it if it is STILL `available`; the loser of the race gets a
  /// clean `[acceptClaimParams] == false` result to show a friendly toast.
  /// Firestore serialises transactions, so both riders can never win.
  Future<bool> acceptTask(String taskId, String riderId) async {
    final docRef = _firestore.collection('deliveryTasks').doc(taskId);
    try {
      return await _firestore.runTransaction<bool>((txn) async {
        final snap = await txn.get(docRef);
        if (!snap.exists) return false;
        final status = snap.data()?['status'] as String? ?? '';
        if (status != DeliveryTaskStatus.available.name) {
          return false; // someone else already claimed / progressed it
        }
        txn.update(docRef, {
          'riderId': riderId,
          'status': DeliveryTaskStatus.accepted.name,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('RiderRepository.acceptTask error: $e');
      return false;
    }
  }

  /// Updates the status of a delivery task.
  Future<void> updateTaskStatus(
      String taskId, DeliveryTaskStatus newStatus) async {
    await _firestore.collection('deliveryTasks').doc(taskId).update({
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (newStatus == DeliveryTaskStatus.delivered)
        'deliveredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Verifies the customer OTP and marks the task as delivered.
  ///
  /// Returns `true` on correct OTP, `false` otherwise.
  Future<bool> completeDeliveryWithOtp(
      String taskId, String enteredOtp) async {
    try {
      final doc =
          await _firestore.collection('deliveryTasks').doc(taskId).get();
      if (!doc.exists) return false;
      final storedOtp = doc.data()?['customerOtp'] as String?;
      if (storedOtp == null || storedOtp.trim() != enteredOtp.trim()) {
        return false;
      }
      await updateTaskStatus(taskId, DeliveryTaskStatus.delivered);
      // Also update the corresponding sub-order in the orders collection
      final orderId = doc.data()?['orderId'] as String?;
      final subOrderId = doc.data()?['subOrderId'] as String?;
      if (orderId != null && subOrderId != null) {
        try {
          await _updateSubOrderDelivered(orderId, subOrderId);
        } catch (e) {
          debugPrint('updateSubOrderDelivered error (non-fatal): $e');
        }
      }
      return true;
    } catch (e) {
      debugPrint('RiderRepository.completeDeliveryWithOtp error: $e');
      return false;
    }
  }

  Future<void> _updateSubOrderDelivered(
      String orderId, String subOrderId) async {
    final docRef = _firestore.collection('orders').doc(orderId);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final subOrders = List<Map<String, dynamic>>.from(
        (data['subOrders'] as List<dynamic>? ?? []).map(
            (s) => Map<String, dynamic>.from(s as Map)),
      );
      for (final sub in subOrders) {
        if (sub['id'] == subOrderId) {
          sub['status'] = 'delivered';
          break;
        }
      }
      final allDelivered =
          subOrders.every((s) => s['status'] == 'delivered');
      txn.update(docRef, {
        'subOrders': subOrders,
        if (allDelivered) 'status': 'delivered',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Creates a delivery task document (called when an order is placed or
  /// when admin/seller assigns a rider).
  Future<void> createDeliveryTask(DeliveryTaskEntity task,
      {String? orderId}) async {
    final data = _taskToJson(task);
    if (orderId != null) data['orderId'] = orderId;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['assignedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('deliveryTasks').doc(task.id).set(data);
  }

  // ──────────────────────────────────────────────────────────────
  // RIDER EARNINGS
  // ──────────────────────────────────────────────────────────────

  /// Real-time stream of a rider's earnings stats.
  Stream<Map<String, double>> streamRiderEarnings(String riderId) {
    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day);

    return _firestore
        .collection('deliveryTasks')
        .where('riderId', isEqualTo: riderId)
        .where('status', isEqualTo: DeliveryTaskStatus.delivered.name)
        .snapshots()
        .map((snap) {
      double todayEarnings = 0;
      double totalEarnings = 0;
      double codCashInHand = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final earnings =
            (data['estimatedEarnings'] as num?)?.toDouble() ?? 0;
        final cod = (data['codAmount'] as num?)?.toDouble() ?? 0;
        final deliveredAt = data['deliveredAt'];
        totalEarnings += earnings;

        if (deliveredAt is Timestamp) {
          final dt = deliveredAt.toDate();
          if (dt.isAfter(startOfDay)) {
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
    }).handleError((e) {
      debugPrint('RiderRepository.streamRiderEarnings error: $e');
      return <String, double>{};
    });
  }

  // ──────────────────────────────────────────────────────────────
  // PARSING HELPERS
  // ──────────────────────────────────────────────────────────────

  DeliveryTaskEntity? _taskFromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data()!;
      final statusStr =
          data['status'] as String? ?? DeliveryTaskStatus.available.name;
      final status = DeliveryTaskStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => DeliveryTaskStatus.available,
      );

      final assignedAtRaw = data['assignedAt'];
      final assignedAt = assignedAtRaw is Timestamp
          ? assignedAtRaw.toDate()
          : DateTime.tryParse(assignedAtRaw?.toString() ?? '') ?? DateTime.now();

      return DeliveryTaskEntity(
        id: doc.id,
        subOrderId: data['subOrderId'] as String? ?? '',
        orderNumber: data['orderNumber'] as String? ?? '',
        sellerStoreName: data['sellerStoreName'] as String? ?? '',
        sellerAddress: data['sellerAddress'] as String? ?? '',
        sellerPhone: data['sellerPhone'] as String? ?? '',
        customerName: data['customerName'] as String? ?? '',
        customerAddress: data['customerAddress'] as String? ?? '',
        customerPhone: data['customerPhone'] as String? ?? '',
        distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
        codAmount: (data['codAmount'] as num?)?.toDouble() ?? 0,
        estimatedEarnings:
            (data['estimatedEarnings'] as num?)?.toDouble() ?? 0,
        status: status,
        customerOtp: data['customerOtp'] as String? ?? '',
        assignedAt: assignedAt,
      );
    } catch (e) {
      debugPrint(
          'RiderRepository._taskFromDoc parse error for ${doc.id}: $e');
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
