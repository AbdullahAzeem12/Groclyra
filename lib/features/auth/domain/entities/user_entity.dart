import 'account_status.dart';
import 'rider_location.dart';

enum UserRole {
  customer('Customer', 'Browse, Purchase & Live Tracking'),
  seller('Seller', 'Store, Inventory & Order Fulfillment'),
  rider('Rider', 'Deliveries, GPS Route & POD Verification'),
  admin('Admin', 'Platform Governance, Moderation & Audit');

  final String displayName;
  final String description;

  const UserRole(this.displayName, this.description);

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.customer;
    return UserRole.values.firstWhere(
      (r) => r.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.customer,
    );
  }
}

class UserEntity {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final String? profileImageBase64;
  final bool isVerified;
  final bool emailVerified;
  final AccountStatus accountStatus;
  final bool profileCompleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<UserRole> authorizedRoles;

  // Role-specific metadata
  final String? storeName; // for Seller
  final String? businessCategory; // for Seller
  final String? vehicleNumber; // for Rider
  final String? deliveryZone; // for Rider
  final RiderLocation? deliveryLocation; // for Rider
  final String? cnicNumber; // for Rider
  final String? drivingLicenseNumber; // for Rider
  final String? adminDepartment; // for Admin
  final String? adminId; // for Admin
  final String? deliveryAddress; // for Customer (saved default delivery address)

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.profileImageBase64,
    this.isVerified = true,
    this.emailVerified = true,
    this.accountStatus = AccountStatus.active,
    this.profileCompleted = true,
    required this.createdAt,
    this.updatedAt,
    this.authorizedRoles = const [UserRole.customer],
    this.storeName,
    this.businessCategory,
    this.vehicleNumber,
    this.deliveryZone,
    this.deliveryLocation,
    this.cnicNumber,
    this.drivingLicenseNumber,
    this.adminDepartment,
    this.adminId,
    this.deliveryAddress,
  });

  bool get isCustomer => role == UserRole.customer;
  bool get isSeller => role == UserRole.seller;
  bool get isRider => role == UserRole.rider;
  bool get isAdmin => role == UserRole.admin;
  String get fullName => name;

  bool get isActive => accountStatus == AccountStatus.active;
  bool get isPending => accountStatus == AccountStatus.pending;
  bool get isSuspended => accountStatus == AccountStatus.suspended;
  bool get isDisabled => accountStatus == AccountStatus.disabled;

  UserEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? avatarUrl,
    String? profileImageBase64,
    bool? isVerified,
    bool? emailVerified,
    AccountStatus? accountStatus,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<UserRole>? authorizedRoles,
    String? storeName,
    String? businessCategory,
    String? vehicleNumber,
    String? deliveryZone,
    RiderLocation? deliveryLocation,
    String? cnicNumber,
    String? drivingLicenseNumber,
    String? adminDepartment,
    String? adminId,
    String? deliveryAddress,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      isVerified: isVerified ?? this.isVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      accountStatus: accountStatus ?? this.accountStatus,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorizedRoles: authorizedRoles ?? this.authorizedRoles,
      storeName: storeName ?? this.storeName,
      businessCategory: businessCategory ?? this.businessCategory,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      deliveryZone: deliveryZone ?? this.deliveryZone,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      drivingLicenseNumber: drivingLicenseNumber ?? this.drivingLicenseNumber,
      adminDepartment: adminDepartment ?? this.adminDepartment,
      adminId: adminId ?? this.adminId,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'avatarUrl': avatarUrl,
      'profileImageBase64': profileImageBase64,
      'isVerified': isVerified,
      'emailVerified': emailVerified,
      'accountStatus': accountStatus.name,
      'profileCompleted': profileCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'authorizedRoles': authorizedRoles.map((r) => r.name).toList(),
      'storeName': storeName,
      'businessCategory': businessCategory,
      'vehicleNumber': vehicleNumber,
      'deliveryZone': deliveryZone,
      'deliveryLocation': deliveryLocation?.toMap(),
      'cnicNumber': cnicNumber,
      'drivingLicenseNumber': drivingLicenseNumber,
      'adminDepartment': adminDepartment,
      'adminId': adminId,
      'deliveryAddress': deliveryAddress,
    };
  }

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as String? ?? json['uid'] as String? ?? '',
      name: json['name'] as String? ?? json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      avatarUrl: json['avatarUrl'] as String?,
      profileImageBase64: json['profileImageBase64'] as String?,
      isVerified: json['isVerified'] as bool? ?? true,
      emailVerified: json['emailVerified'] as bool? ?? json['isVerified'] as bool? ?? true,
      accountStatus: AccountStatus.fromString(json['accountStatus'] as String?),
      profileCompleted: json['profileCompleted'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      authorizedRoles: json['authorizedRoles'] != null 
          ? (json['authorizedRoles'] as List).map((r) => UserRole.fromString(r as String?)).toList()
          : [UserRole.fromString(json['role'] as String?)],
      storeName: json['storeName'] as String?,
      businessCategory: json['businessCategory'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      deliveryZone: json['deliveryZone'] as String?,
      deliveryLocation: json['deliveryLocation'] != null ? RiderLocation.fromMap(Map<String, dynamic>.from(json['deliveryLocation'])) : null,
      cnicNumber: json['cnicNumber'] as String?,
      drivingLicenseNumber: json['drivingLicenseNumber'] as String?,
      adminDepartment: json['adminDepartment'] as String?,
      adminId: json['adminId'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': id,
      'displayName': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'avatarUrl': avatarUrl,
      'profileImageBase64': profileImageBase64,
      'isVerified': isVerified,
      'emailVerified': emailVerified,
      'accountStatus': accountStatus.name,
      'profileCompleted': profileCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      'authorizedRoles': authorizedRoles.map((r) => r.name).toList(),
      'storeName': storeName,
      'businessCategory': businessCategory,
      'vehicleNumber': vehicleNumber,
      'deliveryZone': deliveryZone,
      'deliveryLocation': deliveryLocation?.toMap(),
      'cnicNumber': cnicNumber,
      'drivingLicenseNumber': drivingLicenseNumber,
      'adminDepartment': adminDepartment,
      'adminId': adminId,
      'deliveryAddress': deliveryAddress,
    };
  }

  factory UserEntity.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserEntity(
      id: uid,
      name: data['displayName'] as String? ?? data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: UserRole.fromString(data['role'] as String?),
      avatarUrl: data['avatarUrl'] as String?,
      profileImageBase64: data['profileImageBase64'] as String?,
      isVerified: data['isVerified'] as bool? ?? true,
      emailVerified: data['emailVerified'] as bool? ?? false,
      accountStatus: AccountStatus.fromString(data['accountStatus'] as String?),
      profileCompleted: data['profileCompleted'] as bool? ?? true,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'].toString())
          : null,
      authorizedRoles: data['authorizedRoles'] != null 
          ? (data['authorizedRoles'] as List).map((r) => UserRole.fromString(r as String?)).toList()
          : [UserRole.fromString(data['role'] as String?)],
      storeName: data['storeName'] as String?,
      businessCategory: data['businessCategory'] as String?,
      vehicleNumber: data['vehicleNumber'] as String?,
      deliveryZone: data['deliveryZone'] as String?,
      deliveryLocation: data['deliveryLocation'] != null ? RiderLocation.fromMap(Map<String, dynamic>.from(data['deliveryLocation'])) : null,
      cnicNumber: data['cnicNumber'] as String?,
      drivingLicenseNumber: data['drivingLicenseNumber'] as String?,
      adminDepartment: data['adminDepartment'] as String?,
      adminId: data['adminId'] as String?,
      deliveryAddress: data['deliveryAddress'] as String?,
    );
  }
}
