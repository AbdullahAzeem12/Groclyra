import 'package:flutter/material.dart';

enum DeliveryTaskStatus {
  available('Available', Color(0xFF3B82F6)),
  accepted('Accepted', Color(0xFF8B5CF6)),
  pickedUp('Picked Up from Seller', Color(0xFFF59E0B)),
  inTransit('In Transit to Customer', Color(0xFFF97316)),
  delivered('Delivered Successfully', Color(0xFF10B981)),
  failed('Delivery Failed / Returned', Color(0xFFEF4444));

  final String label;
  final Color color;

  const DeliveryTaskStatus(this.label, this.color);
}

class DeliveryTaskEntity {
  final String id;
  final String subOrderId;
  final String orderNumber;
  final String sellerStoreName;
  final String sellerAddress;
  final String sellerPhone;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final double distanceKm;
  final double codAmount; // 0 if prepaid
  final double estimatedEarnings;
  final DeliveryTaskStatus status;
  final String customerOtp;
  final DateTime assignedAt;

  const DeliveryTaskEntity({
    required this.id,
    required this.subOrderId,
    required this.orderNumber,
    required this.sellerStoreName,
    required this.sellerAddress,
    required this.sellerPhone,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.distanceKm,
    required this.codAmount,
    required this.estimatedEarnings,
    required this.status,
    required this.customerOtp,
    required this.assignedAt,
  });

  bool get isCod => codAmount > 0;
}
