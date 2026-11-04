import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/customer/cart/domain/entities/cart_item_entity.dart';
import 'package:groclyra/features/customer/orders/domain/entities/order_entity.dart';
import 'package:groclyra/features/notifications/data/notifications_repository.dart';
import 'package:groclyra/core/services/rate_limit_service.dart';

/// Fully Firestore-backed OrderRepository.
///
/// Orders are written and read exclusively from the `orders` Firestore
/// collection. Real-time streams keep all portals (customer, seller, rider,
/// admin) in sync without manual refreshes.
class OrderRepository {
  final FirebaseFirestore _firestore;
  final RateLimitService _rateLimitService;
  // Phase 1B: best-effort notification dispatcher (never blocks order flow).
  final NotificationDispatcher _notifier =
      NotificationDispatcher(FirebaseFirestore.instance);

  OrderRepository({
    FirebaseFirestore? firestore,
    RateLimitService? rateLimitService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _rateLimitService = rateLimitService ?? RateLimitService.instance;

  // ──────────────────────────────────────────────────────────────
  // STREAMS
  // ──────────────────────────────────────────────────────────────

  /// Real-time stream of all orders for a specific customer.
  Stream<List<OrderEntity>> streamOrdersForCustomer(String customerId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => _orderFromDoc(doc))
            .whereType<OrderEntity>()
            .toList())
        .handleError((e) {
      debugPrint('OrderRepository.streamOrdersForCustomer error: $e');
      return <OrderEntity>[];
    });
  }

  /// Real-time stream of orders assigned to a specific seller (via subOrders).
  Stream<List<OrderEntity>> streamOrdersForSeller(String sellerId) {
    return _firestore
        .collection('orders')
        .where('sellerIds', arrayContains: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => _orderFromDoc(doc))
            .whereType<OrderEntity>()
            .toList())
        .handleError((e) {
      debugPrint('OrderRepository.streamOrdersForSeller error: $e');
      return <OrderEntity>[];
    });
  }

  /// Real-time stream of a single order by ID.
  Stream<OrderEntity?> streamOrderById(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? _orderFromDoc(doc) : null)
        .handleError((e) {
      debugPrint('OrderRepository.streamOrderById error: $e');
      return null;
    });
  }

  /// Real-time stream of all orders (for admin dashboard).
  Stream<List<OrderEntity>> streamAllOrders() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => _orderFromDoc(doc))
            .whereType<OrderEntity>()
            .toList())
        .handleError((e) {
      debugPrint('OrderRepository.streamAllOrders error: $e');
      return <OrderEntity>[];
    });
  }

  // ──────────────────────────────────────────────────────────────
  // ONE-SHOT READS (kept for backward compatibility)
  // ──────────────────────────────────────────────────────────────

  Future<List<OrderEntity>> getOrders({String? customerId}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true);
      if (customerId != null) {
        query = query.where('customerId', isEqualTo: customerId);
      }
      final snap = await query.get();
      return snap.docs
          .map((doc) => _orderFromDoc(doc))
          .whereType<OrderEntity>()
          .toList();
    } catch (e) {
      debugPrint('OrderRepository.getOrders error: $e');
      return [];
    }
  }

  Future<OrderEntity?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return _orderFromDoc(doc);
    } catch (e) {
      debugPrint('OrderRepository.getOrderById error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // CREATE ORDER
  // ──────────────────────────────────────────────────────────────

  Future<OrderEntity> createOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<CartItemEntity> items,
    required double discountAmount,
    required PaymentMethod paymentMethod,
    // New optional parameters: exact delivery coordinates captured at
    // checkout (map picker). Previously the rider navigation screen silently
    // fell back to the hard-coded Karachi centre when these were missing.
    double? customerLat,
    double? customerLng,
  }) async {
    // Rate limit check: Prevent customer order flooding / rapid duplicate submissions
    if (!_rateLimitService.canPlaceOrder(customerId)) {
      final rem =
          _rateLimitService.getRemainingOrderCooldownSeconds(customerId);
      throw Exception(
        'An order was recently submitted. Please wait $rem seconds before placing another order.',
      );
    }

    final secureRandom = math.Random.secure();

    // 1. Split cart by seller → sub-orders
    final Map<String, List<CartItemEntity>> sellerGroup = {};
    for (final item in items) {
      sellerGroup.putIfAbsent(item.sellerId, () => []).add(item);
    }

    final List<SubOrderEntity> subOrders = [];
    double totalSubtotal = 0.0;
    double totalShipping = 0.0;

    for (final entry in sellerGroup.entries) {
      final sId = entry.key;
      final sItems = entry.value;
      final sName = sItems.first.sellerName;
      final sSubtotal =
          sItems.fold(0.0, (acc, it) => acc + it.totalPrice);
      const sShipping = 150.0;

      totalSubtotal += sSubtotal;
      totalShipping += sShipping;

      final subId =
          'sub_${DateTime.now().microsecondsSinceEpoch}_${secureRandom.nextInt(900000) + 100000}_$sId';

      subOrders.add(
        SubOrderEntity(
          id: subId,
          sellerId: sId,
          sellerName: sName,
          items: sItems,
          subtotal: sSubtotal,
          shippingFee: sShipping,
          status: OrderStatus.paid,
          trackingCode: 'TRK-GL-${secureRandom.nextInt(90000) + 10000}',
        ),
      );
    }

    // 2. Generate order document with cryptographically collision-safe ID
    final otp = '${secureRandom.nextInt(9000) + 1000}';
    final entropy = secureRandom.nextInt(900000) + 100000;
    final orderId = 'ord_${DateTime.now().microsecondsSinceEpoch}_$entropy';
    final orderNumber = 'GL-${secureRandom.nextInt(90000) + 10000}';
    final now = DateTime.now();

    final order = OrderEntity(
      id: orderId,
      orderNumber: orderNumber,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      subOrders: subOrders,
      totalAmount: (totalSubtotal + totalShipping - discountAmount)
          .clamp(0.0, double.infinity),
      discountAmount: discountAmount,
      totalShippingFee: totalShipping,
      status: OrderStatus.paid,
      paymentMethod: paymentMethod,
      createdAt: now,
      estimatedDelivery: now.add(const Duration(hours: 48)),
      customerOtp: otp,
    );

    // 3. Write to Firestore — include sellerIds array for seller-side queries
    final data = order.toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['sellerIds'] = sellerGroup.keys.toList(); // enables arrayContains filter

    await _firestore.collection('orders').doc(orderId).set(data);
    await _rateLimitService.recordOrderPlaced(customerId);

    // 4. Create real-time delivery task for riders in the deliveryTasks collection
    for (final sub in subOrders) {
      final taskId = 'task_${sub.id}';

      // Upgraded: read the seller's real store profile so delivery tasks carry
      // actual pickup details instead of the previous hardcoded placeholders.
      // The old hardcoded strings are kept as final fallbacks so task creation
      // can never fail, even when the seller profile is missing.
      String sellerAddress = 'Marketplace Partner Outlet';
      String sellerPhone = '+92-300-1234567';
      double? sellerLat;
      double? sellerLng;
      try {
        final sellerDoc = await _firestore
            .collection('sellerProfiles')
            .doc(sub.sellerId)
            .get();
        final sData = sellerDoc.data() ?? const {};
        final sAddr = (sData['storeAddress'] ?? sData['address']) as String?;
        if (sAddr != null && sAddr.trim().isNotEmpty) {
          sellerAddress = sAddr.trim();
        }
        final sPhone = (sData['phone'] ?? sData['contactPhone']) as String?;
        if (sPhone != null && sPhone.trim().isNotEmpty) {
          sellerPhone = sPhone.trim();
        }
        final lat = (sData['storeLat'] ?? sData['latitude']) as num?;
        final lng = (sData['storeLng'] ?? sData['longitude']) as num?;
        if (lat != null && lng != null) {
          sellerLat = lat.toDouble();
          sellerLng = lng.toDouble();
        }
      } catch (e) {
        debugPrint(
            'OrderRepository: seller profile read notice for ${sub.sellerId}: $e');
      }

      // Upgraded: compute distance & payout from real coordinates when both
      // the seller store and customer have lat/lng; otherwise the existing
      // default estimate is preserved so routes never break.
      double distanceKm = 3.5;
      double estimatedEarnings = 220.0;
      if (sellerLat != null &&
          sellerLng != null &&
          customerLat != null &&
          customerLng != null) {
        final km = _haversineKm(
          sellerLat,
          sellerLng,
          customerLat,
          customerLng,
        );
        if (km > 0.05) {
          distanceKm = double.parse(km.toStringAsFixed(2));
          // Payout model: base fee + per-km rate (kept in sync with the
          // estimated earnings previously shown to riders).
          estimatedEarnings =
              double.parse((80 + distanceKm * 35).toStringAsFixed(2));
        }
      }

      try {
        await _firestore.collection('deliveryTasks').doc(taskId).set({
          'id': taskId,
          'orderId': orderId,
          'subOrderId': sub.id,
          'orderNumber': orderNumber,
          'sellerStoreName': sub.sellerName,
          'sellerAddress': sellerAddress,
          'sellerPhone': sellerPhone,
          'customerName': customerName,
          'customerAddress': deliveryAddress,
          'customerPhone': customerPhone,
          'distanceKm': distanceKm,
          'codAmount': paymentMethod == PaymentMethod.cashOnDelivery
              ? (sub.subtotal + sub.shippingFee)
              : 0.0,
          'estimatedEarnings': estimatedEarnings,
          // New fields: exact destination coordinates for rider navigation.
          // Null-safe: only written when the caller supplies them, otherwise
          // the navigation screen keeps its existing behavior.
          if (customerLat != null) 'customerLat': customerLat,
          if (customerLng != null) 'customerLng': customerLng,
          if (sellerLat != null) 'sellerLat': sellerLat,
          if (sellerLng != null) 'sellerLng': sellerLng,
          'status': 'available',
          'customerOtp': otp,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'assignedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('OrderRepository: delivery task creation notice: $e');
      }
    }

    // ── Notifications (Phase 1B) ─────────────────────────────────────────
    // Best-effort, after every primary write has succeeded.
    for (final entry in sellerGroup.entries) {
      await _notifier.toUser(
        recipientId: entry.key,
        kind: 'order',
        title: '🛒 New order ${entry.value.length > 1 ? 'items' : 'item'}',
        body: 'You received a new order #$orderNumber. Accept it to start fulfillment.',
        data: {'orderId': orderId, 'orderNumber': orderNumber},
      );
    }
    await _notifier.toAllAdmins(
      kind: 'order',
      title: '📈 New marketplace order',
      body: 'Order #$orderNumber placed by $customerName.',
      data: {'orderId': orderId, 'orderNumber': orderNumber},
    );

    return order;
  }

  /// Great-circle distance in kilometres between two lat/lng points.
  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6372.8; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = 0.5 -
        math.cos(dLat) / 2 +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            (1 - math.cos(dLng)) / 2;
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180);

  // ──────────────────────────────────────────────────────────────
  // STATUS UPDATES
  // ──────────────────────────────────────────────────────────────

  /// Updates the top-level order status.
  Future<void> updateOrderStatus(
      String orderId, OrderStatus newStatus) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the status of a specific sub-order (seller / rider view).
  Future<void> updateSubOrderStatus({
    required String orderId,
    required String subOrderId,
    required OrderStatus newStatus,
    String? riderId,
    String? riderName,
    String? riderPhone,
  }) async {
    final docRef = _firestore.collection('orders').doc(orderId);
    String? customerId;
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      customerId = data['customerId'] as String?;
      final subOrders = List<Map<String, dynamic>>.from(
        (data['subOrders'] as List<dynamic>? ?? []).map(
            (s) => Map<String, dynamic>.from(s as Map)),
      );
      for (final sub in subOrders) {
        if (sub['id'] == subOrderId) {
          sub['status'] = newStatus.name;
          if (riderId != null) sub['riderId'] = riderId;
          if (riderName != null) sub['riderName'] = riderName;
          if (riderPhone != null) sub['riderPhone'] = riderPhone;
          break;
        }
      }

      // Derive overall order status from sub-orders
      final allDelivered =
          subOrders.every((s) => s['status'] == OrderStatus.delivered.name);
      final anyFailed =
          subOrders.any((s) => s['status'] == OrderStatus.cancelled.name);

      final overallStatus = allDelivered
          ? OrderStatus.delivered.name
          : anyFailed
              ? OrderStatus.cancelled.name
              : newStatus.name;

      // Denormalised rider list (security rules key off this field so no
      // array scanning is possible in rules). Additive: previous subOrders
      // shape is untouched.
      final riderIds = (data['riderIds'] as List?)?.cast<String>() ?? const [];
      if (riderId != null && !riderIds.contains(riderId)) {
        riderIds.add(riderId);
      }

      txn.update(docRef, {
        'subOrders': subOrders,
        'status': overallStatus,
        if (riderId != null) 'riderIds': riderIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // ── Notifications (Phase 1B) — customer-facing status updates ────────
    final rid = customerId;
    if (rid != null && rid.isNotEmpty) {
      switch (newStatus) {
        case OrderStatus.delivered:
          await _notifier.toUser(
            recipientId: rid,
            kind: 'delivery',
            title: '✅ Order delivered',
            body: 'Your order #$orderId has been delivered. Rate your experience in Order History!',
            data: {'orderId': orderId, 'status': 'delivered'},
          );
          break;
        case OrderStatus.riderAssigned:
          await _notifier.toUser(
            recipientId: rid,
            kind: 'delivery',
            title: '🛵 Rider assigned',
            body: 'A rider has been assigned to order #$orderId and will pick it up shortly.',
            data: {'orderId': orderId, 'status': 'riderAssigned'},
          );
          break;
        case OrderStatus.inTransit:
        case OrderStatus.outForDelivery:
          await _notifier.toUser(
            recipientId: rid,
            kind: 'delivery',
            title: '📦 Order on the way',
            body: 'Order #$orderId is out for delivery. Get the OTP ready!',
            data: {'orderId': orderId, 'status': newStatus.name},
          );
          break;
        case OrderStatus.cancelled:
        case OrderStatus.cancelledBySeller:
          await _notifier.toUser(
            recipientId: rid,
            kind: 'delivery',
            title: '⚠️ Order cancelled',
            body: 'Order #$orderId was cancelled. Any paid amount will be refunded.',
            data: {'orderId': orderId, 'status': 'cancelled'},
          );
          break;
        default:
          break;
      }
    }
  }

  /// Assigns a rider to a sub-order.
  Future<void> assignRider({
    required String orderId,
    required String subOrderId,
    required String riderId,
    required String riderName,
    required String riderPhone,
  }) async {
    await updateSubOrderStatus(
      orderId: orderId,
      subOrderId: subOrderId,
      newStatus: OrderStatus.riderAssigned,
      riderId: riderId,
      riderName: riderName,
      riderPhone: riderPhone,
    );
  }

  // ──────────────────────────────────────────────────────────────
  // PARSING HELPERS
  // ──────────────────────────────────────────────────────────────

  OrderEntity? _orderFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data()!;
      data['id'] = doc.id;

      // Convert Firestore Timestamp → ISO string for fromJson
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        data['createdAt'] = createdAt.toDate().toIso8601String();
      }
      final updatedAt = data['updatedAt'];
      if (updatedAt is Timestamp) {
        data['updatedAt'] = updatedAt.toDate().toIso8601String();
      }
      final estimated = data['estimatedDelivery'];
      if (estimated is Timestamp) {
        data['estimatedDelivery'] = estimated.toDate().toIso8601String();
      }

      return OrderEntity.fromJson(data);
    } catch (e) {
      debugPrint('OrderRepository._orderFromDoc error for ${doc.id}: $e');
      return null;
    }
  }
}

// ──────────────────────────────────────────────────────────────
// PROVIDERS
// ──────────────────────────────────────────────────────────────

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    rateLimitService: ref.watch(rateLimitServiceProvider),
  );
});

/// Customer's real-time order history
final customerOrdersStreamProvider =
    StreamProvider.autoDispose.family<List<OrderEntity>, String>(
        (ref, customerId) {
  return ref
      .watch(orderRepositoryProvider)
      .streamOrdersForCustomer(customerId);
});

/// Real-time stream of a single order
final orderByIdStreamProvider =
    StreamProvider.autoDispose.family<OrderEntity?, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).streamOrderById(orderId);
});

/// Seller's real-time order feed
final sellerOrdersStreamProvider =
    StreamProvider.autoDispose.family<List<OrderEntity>, String>(
        (ref, sellerId) {
  return ref
      .watch(orderRepositoryProvider)
      .streamOrdersForSeller(sellerId);
});
