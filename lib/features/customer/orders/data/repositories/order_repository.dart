import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/features/customer/cart/domain/entities/cart_item_entity.dart';
import 'package:groclyra/features/customer/orders/domain/entities/order_entity.dart';
import 'package:groclyra/features/notifications/data/notifications_repository.dart';
import 'package:groclyra/core/services/rate_limit_service.dart';

/// Fully SQL-backed OrderRepository (SQLite).
///
/// Orders and delivery tasks are written and read exclusively from SQLite tables.
/// Real-time streams powered by AppDatabase table change notifications keep all portals
/// (customer, seller, rider, admin) in sync instantly.
class OrderRepository {
  final AppDatabase _database;
  final RateLimitService _rateLimitService;
  final NotificationDispatcher _notifier;

  OrderRepository({
    dynamic firestore, // Kept dynamic for legacy test compatibility
    RateLimitService? rateLimitService,
    AppDatabase? database,
  })  : _database = database ?? AppDatabase.instance,
        _rateLimitService = rateLimitService ?? RateLimitService.instance,
        _notifier = NotificationDispatcher(database ?? AppDatabase.instance);

  // ──────────────────────────────────────────────────────────────
  // STREAMS
  // ──────────────────────────────────────────────────────────────

  /// Real-time stream of all orders for a specific customer from SQLite.
  Stream<List<OrderEntity>> streamOrdersForCustomer(String customerId) async* {
    yield await getOrders(customerId: customerId);

    yield* _database.watchTable('orders').asyncMap((_) async {
      return await getOrders(customerId: customerId);
    });
  }

  /// Real-time stream of orders assigned to a specific seller from SQLite.
  Stream<List<OrderEntity>> streamOrdersForSeller(String sellerId) async* {
    yield await _getOrdersForSeller(sellerId);

    yield* _database.watchTable('orders').asyncMap((_) async {
      return await _getOrdersForSeller(sellerId);
    });
  }

  /// Real-time stream of a single order by ID from SQLite.
  Stream<OrderEntity?> streamOrderById(String orderId) async* {
    yield await getOrderById(orderId);

    yield* _database.watchTable('orders').asyncMap((_) async {
      return await getOrderById(orderId);
    });
  }

  /// Real-time stream of all orders (for admin dashboard) from SQLite.
  Stream<List<OrderEntity>> streamAllOrders() async* {
    yield await _getAllOrders();

    yield* _database.watchTable('orders').asyncMap((_) async {
      return await _getAllOrders();
    });
  }

  // ──────────────────────────────────────────────────────────────
  // ONE-SHOT READS
  // ──────────────────────────────────────────────────────────────

  Future<List<OrderEntity>> getOrders({String? customerId}) async {
    try {
      final rows = await _database.query(
        'orders',
        where: customerId != null && customerId.isNotEmpty ? 'customerId = ?' : null,
        whereArgs: customerId != null && customerId.isNotEmpty ? [customerId] : null,
        orderBy: 'createdAt DESC',
      );
      return rows.map(_orderFromRow).whereType<OrderEntity>().toList();
    } catch (e) {
      debugPrint('OrderRepository.getOrders error: $e');
      return [];
    }
  }

  Future<List<OrderEntity>> _getOrdersForSeller(String sellerId) async {
    try {
      final rows = await _database.query(
        'orders',
        where: 'sellerIds LIKE ?',
        whereArgs: ['%$sellerId%'],
        orderBy: 'createdAt DESC',
      );
      return rows.map(_orderFromRow).whereType<OrderEntity>().toList();
    } catch (e) {
      debugPrint('OrderRepository._getOrdersForSeller error: $e');
      return [];
    }
  }

  Future<List<OrderEntity>> _getAllOrders() async {
    try {
      final rows = await _database.query(
        'orders',
        orderBy: 'createdAt DESC',
        limit: 100,
      );
      return rows.map(_orderFromRow).whereType<OrderEntity>().toList();
    } catch (e) {
      debugPrint('OrderRepository._getAllOrders error: $e');
      return [];
    }
  }

  Future<OrderEntity?> getOrderById(String orderId) async {
    try {
      final rows = await _database.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _orderFromRow(rows.first);
    } catch (e) {
      debugPrint('OrderRepository.getOrderById error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // CREATE ORDER (SQLite)
  // ──────────────────────────────────────────────────────────────

  Future<OrderEntity> createOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<CartItemEntity> items,
    required double discountAmount,
    required PaymentMethod paymentMethod,
    double? customerLat,
    double? customerLng,
  }) async {
    // Rate limit check: Prevent customer order flooding
    if (!_rateLimitService.canPlaceOrder(customerId)) {
      final rem = _rateLimitService.getRemainingOrderCooldownSeconds(customerId);
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
      final sSubtotal = sItems.fold(0.0, (acc, it) => acc + it.totalPrice);
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

    // 2. Generate order document
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
      totalAmount: (totalSubtotal + totalShipping - discountAmount).clamp(0.0, double.infinity),
      discountAmount: discountAmount,
      totalShippingFee: totalShipping,
      status: OrderStatus.paid,
      paymentMethod: paymentMethod,
      createdAt: now,
      estimatedDelivery: now.add(const Duration(hours: 48)),
      customerOtp: otp,
    );

    // 3. Write order to SQLite
    final orderData = order.toJson();
    final sellerIdsList = sellerGroup.keys.toList();
    orderData['sellerIds'] = sellerIdsList;

    final orderRow = <String, dynamic>{
      'id': orderId,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'totalAmount': order.totalAmount,
      'discountAmount': discountAmount,
      'totalShippingFee': totalShipping,
      'status': order.status.name,
      'paymentMethod': paymentMethod.name,
      'customerOtp': otp,
      'sellerIds': jsonEncode(sellerIdsList),
      'subOrdersJson': jsonEncode(subOrders.map((s) => s.toJson()).toList()),
      'fullDataJson': jsonEncode(orderData),
      'createdAt': now.toIso8601String(),
      'estimatedDelivery': order.estimatedDelivery.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _database.insertOrReplace('orders', orderRow);
    await _rateLimitService.recordOrderPlaced(customerId);

    // 4. Insert order items into SQLite
    for (final item in items) {
      await _database.insertOrReplace('order_items', {
        'id': 'item_${item.id}_$orderId',
        'orderId': orderId,
        'productId': item.product.id,
        'title': item.product.title,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'totalPrice': item.totalPrice,
        'variantName': item.selectedVariant?.name,
        'imageUrl': item.product.images.isNotEmpty ? item.product.images.first : '',
        'sellerId': item.sellerId,
        'createdAt': now.toIso8601String(),
      });
    }

    // 5. Create real-time delivery tasks in SQLite delivery_tasks table
    for (final sub in subOrders) {
      final taskId = 'task_${sub.id}';

      String sellerAddress = 'Marketplace Partner Outlet';
      String sellerPhone = '+92-300-1234567';
      double? sellerLat;
      double? sellerLng;

      try {
        final sellerRows = await _database.query(
          'seller_profiles',
          where: 'sellerId = ?',
          whereArgs: [sub.sellerId],
          limit: 1,
        );
        if (sellerRows.isNotEmpty) {
          final sData = sellerRows.first;
          final sAddr = sData['address']?.toString();
          if (sAddr != null && sAddr.trim().isNotEmpty) {
            sellerAddress = sAddr.trim();
          }
          final sPhone = sData['phone']?.toString();
          if (sPhone != null && sPhone.trim().isNotEmpty) {
            sellerPhone = sPhone.trim();
          }
          final lat = (sData['latitude'] as num?)?.toDouble();
          final lng = (sData['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            sellerLat = lat;
            sellerLng = lng;
          }
        }
      } catch (e) {
        debugPrint('OrderRepository: seller profile read notice: $e');
      }

      double distanceKm = 3.5;
      double estimatedEarnings = 220.0;
      if (sellerLat != null && sellerLng != null && customerLat != null && customerLng != null) {
        final km = _haversineKm(sellerLat, sellerLng, customerLat, customerLng);
        if (km > 0.05) {
          distanceKm = double.parse(km.toStringAsFixed(2));
          estimatedEarnings = double.parse((80 + distanceKm * 35).toStringAsFixed(2));
        }
      }

      try {
        await _database.insertOrReplace('delivery_tasks', {
          'id': taskId,
          'orderId': orderId,
          'subOrderId': sub.id,
          'orderNumber': orderNumber,
          'sellerStoreName': sub.sellerName,
          'sellerAddress': sellerAddress,
          'sellerPhone': sellerPhone,
          'pickupLat': sellerLat ?? 31.5204,
          'pickupLng': sellerLng ?? 74.3587,
          'customerName': customerName,
          'customerAddress': deliveryAddress,
          'customerPhone': customerPhone,
          'dropLat': customerLat ?? 31.5204,
          'dropLng': customerLng ?? 74.3587,
          'riderLat': sellerLat ?? 31.5204,
          'riderLng': sellerLng ?? 74.3587,
          'distanceKm': distanceKm,
          'codAmount': paymentMethod == PaymentMethod.cashOnDelivery
              ? (sub.subtotal + sub.shippingFee)
              : 0.0,
          'estimatedEarnings': estimatedEarnings,
          'status': 'available',
          'customerOtp': otp,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'assignedAt': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('OrderRepository: delivery task creation notice: $e');
      }
    }

    _database.notifyTable('orders');
    _database.notifyTable('order_items');
    _database.notifyTable('delivery_tasks');

    // 6. Notifications
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

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6372.8;
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
  // STATUS UPDATES (SQLite)
  // ──────────────────────────────────────────────────────────────

  /// Updates top-level order status in SQLite.
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      final rows = await _database.query('orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
      if (rows.isNotEmpty) {
        final existing = Map<String, dynamic>.from(rows.first);
        existing['status'] = newStatus.name;
        existing['updatedAt'] = DateTime.now().toIso8601String();

        if (existing['fullDataJson'] != null) {
          final full = jsonDecode(existing['fullDataJson'] as String) as Map<String, dynamic>;
          full['status'] = newStatus.name;
          full['updatedAt'] = existing['updatedAt'];
          existing['fullDataJson'] = jsonEncode(full);
        }

        await _database.update('orders', existing, where: 'id = ?', whereArgs: [orderId]);
        _database.notifyTable('orders');
      }
    } catch (e) {
      debugPrint('OrderRepository.updateOrderStatus error: $e');
    }
  }

  /// Updates status of a specific sub-order in SQLite.
  Future<void> updateSubOrderStatus({
    required String orderId,
    required String subOrderId,
    required OrderStatus newStatus,
    String? riderId,
    String? riderName,
    String? riderPhone,
  }) async {
    try {
      final rows = await _database.query('orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
      if (rows.isEmpty) return;

      final existing = Map<String, dynamic>.from(rows.first);
      final customerId = existing['customerId']?.toString();

      final fullData = existing['fullDataJson'] != null
          ? jsonDecode(existing['fullDataJson'] as String) as Map<String, dynamic>
          : <String, dynamic>{};

      final subOrdersList = List<Map<String, dynamic>>.from(
        (fullData['subOrders'] as List? ?? []).map((s) => Map<String, dynamic>.from(s as Map)),
      );

      for (final sub in subOrdersList) {
        if (sub['id'] == subOrderId) {
          sub['status'] = newStatus.name;
          if (riderId != null) sub['riderId'] = riderId;
          if (riderName != null) sub['riderName'] = riderName;
          if (riderPhone != null) sub['riderPhone'] = riderPhone;
          break;
        }
      }

      final allDelivered = subOrdersList.every((s) => s['status'] == OrderStatus.delivered.name);
      final anyFailed = subOrdersList.any((s) => s['status'] == OrderStatus.cancelled.name);

      final overallStatus = allDelivered
          ? OrderStatus.delivered.name
          : anyFailed
              ? OrderStatus.cancelled.name
              : newStatus.name;

      final now = DateTime.now().toIso8601String();
      fullData['subOrders'] = subOrdersList;
      fullData['status'] = overallStatus;
      fullData['updatedAt'] = now;

      existing['status'] = overallStatus;
      existing['subOrdersJson'] = jsonEncode(subOrdersList);
      existing['fullDataJson'] = jsonEncode(fullData);
      existing['updatedAt'] = now;

      await _database.update('orders', existing, where: 'id = ?', whereArgs: [orderId]);
      _database.notifyTable('orders');

      // Keep delivery_tasks table in lockstep with order updates
      try {
        final taskStatus = switch (newStatus) {
          OrderStatus.delivered => 'delivered',
          OrderStatus.inTransit || OrderStatus.outForDelivery => 'inTransit',
          OrderStatus.riderAssigned => 'accepted',
          OrderStatus.cancelled || OrderStatus.cancelledBySeller => 'failed',
          _ => 'available',
        };
        final taskUpdate = <String, dynamic>{
          'status': taskStatus,
          'updatedAt': now,
        };
        if (riderId != null) taskUpdate['riderId'] = riderId;
        if (newStatus == OrderStatus.delivered) taskUpdate['completedAt'] = now;

        await _database.update(
          'delivery_tasks',
          taskUpdate,
          where: 'orderId = ? AND subOrderId = ?',
          whereArgs: [orderId, subOrderId],
        );
        _database.notifyTable('delivery_tasks');
      } catch (err) {
        debugPrint('Sync delivery_tasks from updateSubOrderStatus: $err');
      }

      // Customer notifications
      if (customerId != null && customerId.isNotEmpty) {
        switch (newStatus) {
          case OrderStatus.delivered:
            await _notifier.toUser(
              recipientId: customerId,
              kind: 'delivery',
              title: '✅ Order delivered',
              body: 'Your order #$orderId has been delivered. Rate your experience in Order History!',
              data: {'orderId': orderId, 'status': 'delivered'},
            );
            break;
          case OrderStatus.riderAssigned:
            await _notifier.toUser(
              recipientId: customerId,
              kind: 'delivery',
              title: '🛵 Rider assigned',
              body: 'A rider has been assigned to order #$orderId and will pick it up shortly.',
              data: {'orderId': orderId, 'status': 'riderAssigned'},
            );
            break;
          case OrderStatus.inTransit:
          case OrderStatus.outForDelivery:
            await _notifier.toUser(
              recipientId: customerId,
              kind: 'delivery',
              title: '📦 Order on the way',
              body: 'Order #$orderId is out for delivery. Get the OTP ready!',
              data: {'orderId': orderId, 'status': newStatus.name},
            );
            break;
          case OrderStatus.cancelled:
          case OrderStatus.cancelledBySeller:
            await _notifier.toUser(
              recipientId: customerId,
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
    } catch (e) {
      debugPrint('OrderRepository.updateSubOrderStatus error: $e');
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

  OrderEntity? _orderFromRow(Map<String, dynamic> row) {
    try {
      final fullJson = row['fullDataJson'] as String?;
      if (fullJson != null && fullJson.isNotEmpty) {
        final data = jsonDecode(fullJson) as Map<String, dynamic>;
        data['id'] = row['id'];
        return OrderEntity.fromJson(data);
      }
      return OrderEntity.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('OrderRepository._orderFromRow parse error: $e');
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
