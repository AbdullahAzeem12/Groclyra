enum SettlementStatus {
  pending,
  cleared,
  paid,
  refunded,
}

class VendorSettlementEntity {
  final String id;
  final String orderId;
  final String orderNumber;
  final String vendorId;
  final String vendorName;
  final double grossAmount;
  final double platformCommission;
  final double vendorPayable;
  final double commissionRate;
  final SettlementStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? payoutReference;

  const VendorSettlementEntity({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.vendorId,
    required this.vendorName,
    required this.grossAmount,
    required this.platformCommission,
    required this.vendorPayable,
    required this.commissionRate,
    this.status = SettlementStatus.pending,
    required this.createdAt,
    this.paidAt,
    this.payoutReference,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'grossAmount': grossAmount,
        'platformCommission': platformCommission,
        'vendorPayable': vendorPayable,
        'commissionRate': commissionRate,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
        'payoutReference': payoutReference,
      };

  factory VendorSettlementEntity.fromJson(Map<String, dynamic> json) {
    SettlementStatus parsedStatus = SettlementStatus.pending;
    if (json['status'] != null) {
      for (final s in SettlementStatus.values) {
        if (s.name.toLowerCase() == json['status'].toString().toLowerCase()) {
          parsedStatus = s;
          break;
        }
      }
    }

    final gross = (json['grossAmount'] as num?)?.toDouble() ?? 0.0;
    final rate = (json['commissionRate'] as num?)?.toDouble() ?? 0.08;
    final commission = (json['platformCommission'] as num?)?.toDouble() ?? (gross * rate);
    final payable = (json['vendorPayable'] as num?)?.toDouble() ?? (gross - commission);

    return VendorSettlementEntity(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? 'GL-0000',
      vendorId: json['vendorId']?.toString() ?? '',
      vendorName: json['vendorName']?.toString() ?? 'Partner Mart',
      grossAmount: gross,
      platformCommission: commission,
      vendorPayable: payable,
      commissionRate: rate,
      status: parsedStatus,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : null,
      payoutReference: json['payoutReference']?.toString(),
    );
  }

  /// Calculates a settlement ledger entry given items and agreed commission rate
  factory VendorSettlementEntity.calculate({
    required String orderId,
    required String orderNumber,
    required String vendorId,
    required String vendorName,
    required double grossItemTotal,
    required double commissionRate,
  }) {
    final platformCut = double.parse((grossItemTotal * commissionRate).toStringAsFixed(2));
    final payable = double.parse((grossItemTotal - platformCut).toStringAsFixed(2));

    return VendorSettlementEntity(
      id: 'stl_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
      orderNumber: orderNumber,
      vendorId: vendorId,
      vendorName: vendorName,
      grossAmount: grossItemTotal,
      platformCommission: platformCut,
      vendorPayable: payable,
      commissionRate: commissionRate,
      status: SettlementStatus.pending,
      createdAt: DateTime.now(),
    );
  }
}
