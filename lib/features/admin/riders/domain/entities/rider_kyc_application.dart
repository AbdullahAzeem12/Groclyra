import 'package:groclyra/features/auth/domain/entities/account_status.dart';

class RiderKycApplication {
  final String id;
  final String riderId;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String vehicleNumber;
  final String vehicleType;
  final String deliveryZone;
  final String address;
  final String cnic;
  final String licenseNumber;
  final AccountStatus status;
  final DateTime submittedAt;
  final DateTime? updatedAt;
  final String? adminNotes;
  final String? reviewedBy;

  const RiderKycApplication({
    required this.id,
    required this.riderId,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.vehicleNumber,
    this.vehicleType = 'Motorcycle (125cc)',
    required this.deliveryZone,
    this.address = 'Default Service Area Hub',
    this.cnic = '42101-XXXXXXX-X',
    this.licenseNumber = 'DL-PK-XXXXX',
    this.status = AccountStatus.pending,
    required this.submittedAt,
    this.updatedAt,
    this.adminNotes,
    this.reviewedBy,
  });

  bool get isPending => status == AccountStatus.pending;
  bool get isApproved => status == AccountStatus.active;
  bool get isSuspended => status == AccountStatus.suspended;
  bool get isRejected => status == AccountStatus.disabled;

  RiderKycApplication copyWith({
    String? id,
    String? riderId,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? vehicleNumber,
    String? vehicleType,
    String? deliveryZone,
    String? address,
    String? cnic,
    String? licenseNumber,
    AccountStatus? status,
    DateTime? submittedAt,
    DateTime? updatedAt,
    String? adminNotes,
    String? reviewedBy,
  }) {
    return RiderKycApplication(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      deliveryZone: deliveryZone ?? this.deliveryZone,
      address: address ?? this.address,
      cnic: cnic ?? this.cnic,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminNotes: adminNotes ?? this.adminNotes,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  factory RiderKycApplication.fromFirestore(Map<String, dynamic> data, String uid) {
    return RiderKycApplication(
      id: uid,
      riderId: data['uid'] as String? ?? uid,
      name: data['displayName'] as String? ?? data['name'] as String? ?? 'Rider Applicant',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      vehicleNumber: data['vehicleNumber'] as String? ?? 'Unregistered',
      vehicleType: data['vehicleType'] as String? ?? 'Motorcycle (125cc)',
      deliveryZone: data['deliveryZone'] as String? ?? 'General Zone',
      address: data['address'] as String? ?? 'Operational Hub, Karachi',
      cnic: data['cnicNumber'] as String? ?? data['cnic'] as String? ?? '42101-${uid.substring(0, uid.length >= 7 ? 7 : uid.length)}-1',
      licenseNumber: data['drivingLicenseNumber'] as String? ?? data['licenseNumber'] as String? ?? 'DL-KHI-${uid.substring(0, uid.length >= 5 ? 5 : uid.length)}',
      status: AccountStatus.fromString(data['accountStatus'] as String?),
      submittedAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.tryParse(data['updatedAt'].toString()) : null,
      adminNotes: data['adminNotes'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': riderId,
      'displayName': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'deliveryZone': deliveryZone,
      'address': address,
      'cnic': cnic,
      'licenseNumber': licenseNumber,
      'accountStatus': status.name,
      'createdAt': submittedAt.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      'adminNotes': adminNotes,
      'reviewedBy': reviewedBy,
    };
  }
}
