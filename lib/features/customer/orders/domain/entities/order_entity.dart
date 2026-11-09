import 'package:flutter/material.dart';
import 'package:groclyra/features/customer/cart/domain/entities/cart_item_entity.dart';

enum OrderStatus {
  paymentPending('Payment Pending', Color(0xFFF59E0B)),
  paid('Paid & Confirmed', Color(0xFF10B981)),
  sellerProcessing('Seller Packing', Color(0xFF3B82F6)),
  readyForPickup('Ready for Pickup', Color(0xFF8B5CF6)),
  riderAssigned('Rider Dispatched', Color(0xFF06B6D4)),
  inTransit('In Transit', Color(0xFFF97316)),
  outForDelivery('Out for Delivery', Color(0xFFEC4899)),
  delivered('Delivered', Color(0xFF10B981)),
  cancelled('Cancelled', Color(0xFFEF4444)),
  cancelledBySeller('Rejected by Seller', Color(0xFFEF4444));

  final String label;
  final Color color;

  const OrderStatus(this.label, this.color);
}

enum PaymentMethod {
  cashOnDelivery('Cash on Delivery (COD)', 'Pay cash when rider arrives at your doorstep'),
  payFast('Pay Online (Recommended)', 'Cards, wallets & bank accounts via PayFast secure checkout'),
  jazzCash('JazzCash Mobile Account', 'Instant payment via JazzCash mobile wallet'),
  easypaisa('Easypaisa Mobile Wallet', 'Fast checkout via Easypaisa account'),
  creditDebitCard('Credit / Debit Card', 'Visa, Mastercard & UnionPay supported');

  final String title;
  final String description;

  const PaymentMethod(this.title, this.description);
}

class SubOrderEntity {
  final String id;
  final String sellerId;
  final String sellerName;
  final List<CartItemEntity> items;
  final double subtotal;
  final double shippingFee;
  final OrderStatus status;
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final String? trackingCode;

  const SubOrderEntity({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.items,
    required this.subtotal,
    this.shippingFee = 150.0,
    required this.status,
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.trackingCode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'shippingFee': shippingFee,
        'status': status.name,
        'riderId': riderId,
        'riderName': riderName,
        'riderPhone': riderPhone,
        'trackingCode': trackingCode,
      };

  factory SubOrderEntity.fromJson(Map<String, dynamic> json) => SubOrderEntity(
        id: json['id'],
        sellerId: json['sellerId'],
        sellerName: json['sellerName'],
        items: (json['items'] as List<dynamic>)
            .map((e) => CartItemEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (json['subtotal'] as num).toDouble(),
        shippingFee: (json['shippingFee'] as num?)?.toDouble() ?? 150.0,
        status: OrderStatus.values.firstWhere((s) => s.name == json['status']),
        riderId: json['riderId'],
        riderName: json['riderName'],
        riderPhone: json['riderPhone'],
        trackingCode: json['trackingCode'],
      );
}

class OrderEntity {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final List<SubOrderEntity> subOrders;
  final double totalAmount;
  final double discountAmount;
  final double totalShippingFee;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;
  final DateTime estimatedDelivery;
  final String? customerOtp;
  final double? customerLat;
  final double? customerLng;

  const OrderEntity({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.subOrders,
    required this.totalAmount,
    this.discountAmount = 0.0,
    required this.totalShippingFee,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    required this.estimatedDelivery,
    this.customerOtp = '4829',
    this.customerLat,
    this.customerLng,
  });

  int get totalItemCount => subOrders.fold<int>(
      0, (sum, sub) => sum + sub.items.fold<int>(0, (subSum, it) => subSum + it.quantity));

  String get deliveryOtpPin => customerOtp ?? '4829';
  String? get assignedRiderName => subOrders.firstOrNull?.riderName ?? 'Muhammad Bilal';
  String? get assignedRiderPhone => subOrders.firstOrNull?.riderPhone ?? '+92 300 1234567';
  String? get assignedRiderVehicle => 'Honda 125 • KHI-LEJ-4821';

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'deliveryAddress': deliveryAddress,
        'subOrders': subOrders.map((e) => e.toJson()).toList(),
        'totalAmount': totalAmount,
        'discountAmount': discountAmount,
        'totalShippingFee': totalShippingFee,
        'status': status.name,
        'paymentMethod': paymentMethod.name,
        'createdAt': createdAt.toIso8601String(),
        'estimatedDelivery': estimatedDelivery.toIso8601String(),
        'customerOtp': customerOtp,
        'customerLat': customerLat,
        'customerLng': customerLng,
      };

  factory OrderEntity.fromJson(Map<String, dynamic> json) => OrderEntity(
        id: json['id'],
        orderNumber: json['orderNumber'],
        customerId: json['customerId'],
        customerName: json['customerName'],
        customerPhone: json['customerPhone'],
        deliveryAddress: json['deliveryAddress'],
        subOrders: (json['subOrders'] as List<dynamic>)
            .map((e) => SubOrderEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
        totalShippingFee: (json['totalShippingFee'] as num).toDouble(),
        status: OrderStatus.values.firstWhere((s) => s.name == json['status']),
        paymentMethod: PaymentMethod.values.firstWhere((p) => p.name == json['paymentMethod']),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        estimatedDelivery: DateTime.tryParse(json['estimatedDelivery'] ?? '') ??
            DateTime.now().add(const Duration(days: 2)),
        customerOtp: json['customerOtp'] ?? '4829',
        customerLat: (json['customerLat'] as num?)?.toDouble(),
        customerLng: (json['customerLng'] as num?)?.toDouble(),
      );
}
