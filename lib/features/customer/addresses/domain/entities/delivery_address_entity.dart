import 'package:cloud_firestore/cloud_firestore.dart';

enum AddressLabel {
  home('Home', '🏠'),
  work('Work', '🏢'),
  other('Other', '📍');

  final String displayName;
  final String icon;
  const AddressLabel(this.displayName, this.icon);

  static AddressLabel fromString(String? val) {
    if (val == null) return AddressLabel.home;
    return AddressLabel.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.displayName.toLowerCase() == val.toLowerCase(),
      orElse: () => AddressLabel.home,
    );
  }
}

enum ServiceabilityStatus {
  expressAvailable('Express Delivery (30-60 mins)', 0xFF10B981),
  standardOnly('Standard Delivery (24-48 hours)', 0xFF3B82F6),
  unserviceable('Currently Outside Service Area', 0xFFEF4444);

  final String label;
  final int colorValue;
  const ServiceabilityStatus(this.label, this.colorValue);
}

class DeliveryAddressEntity {
  final String id;
  final String userId;
  final AddressLabel label;
  final String recipientName;
  final String recipientPhone;
  final String provinceOrTerritory;
  final String district;
  final String city;
  final String locality;
  final String? societyOrScheme;
  final String? sectorOrBlock;
  final String street;
  final String houseOrFlat;
  final String? landmark;
  final String? deliveryInstructions;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final ServiceabilityStatus serviceabilityStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DeliveryAddressEntity({
    required this.id,
    required this.userId,
    this.label = AddressLabel.home,
    required this.recipientName,
    required this.recipientPhone,
    String? provinceOrTerritory,
    String? province,
    String? district,
    required this.city,
    String? locality,
    String? societyOrScheme,
    String? societyOrArea,
    this.sectorOrBlock,
    required this.street,
    required this.houseOrFlat,
    String? landmark,
    String? nearestLandmark,
    this.deliveryInstructions,
    String? formattedAddress,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
    this.serviceabilityStatus = ServiceabilityStatus.expressAvailable,
    required this.createdAt,
    this.updatedAt,
  })  : provinceOrTerritory = provinceOrTerritory ?? province ?? 'Sindh',
        district = district ?? city,
        locality = locality ?? societyOrScheme ?? societyOrArea ?? city,
        societyOrScheme = societyOrScheme ?? societyOrArea,
        landmark = landmark ?? nearestLandmark,
        formattedAddress = formattedAddress ??
            [
              houseOrFlat,
              street,
              sectorOrBlock,
              societyOrScheme ?? societyOrArea ?? locality ?? city,
              city,
              provinceOrTerritory ?? province,
            ].where((s) => s != null && s.isNotEmpty).toSet().join(', ');

  String get province => provinceOrTerritory;
  String? get societyOrArea => societyOrScheme;
  String? get nearestLandmark => landmark;
  String get fullAddressDisplay => formattedAddress.isNotEmpty ? formattedAddress : shortDisplay;

  String get shortDisplay {
    if (societyOrScheme != null && societyOrScheme!.isNotEmpty) {
      if (sectorOrBlock != null && sectorOrBlock!.isNotEmpty) {
        return '$societyOrScheme, $sectorOrBlock, $city';
      }
      return '$societyOrScheme, $city';
    }
    return '$locality, $city';
  }

  /// Formatted pin coordinates (e.g. "31.4771°N, 74.2467°E")
  String get coordinatesFormatted {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lngDir = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(4)}°$latDir, ${longitude.abs().toStringAsFixed(4)}°$lngDir';
  }

  DeliveryAddressEntity copyWith({
    String? id,
    String? userId,
    AddressLabel? label,
    String? recipientName,
    String? recipientPhone,
    String? provinceOrTerritory,
    String? district,
    String? city,
    String? locality,
    String? societyOrScheme,
    String? sectorOrBlock,
    String? street,
    String? houseOrFlat,
    String? landmark,
    String? deliveryInstructions,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    bool? isDefault,
    ServiceabilityStatus? serviceabilityStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryAddressEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      provinceOrTerritory: provinceOrTerritory ?? this.provinceOrTerritory,
      district: district ?? this.district,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      societyOrScheme: societyOrScheme ?? this.societyOrScheme,
      sectorOrBlock: sectorOrBlock ?? this.sectorOrBlock,
      street: street ?? this.street,
      houseOrFlat: houseOrFlat ?? this.houseOrFlat,
      landmark: landmark ?? this.landmark,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      serviceabilityStatus: serviceabilityStatus ?? this.serviceabilityStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'label': label.name,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'countryCode': 'PK',
      'provinceOrTerritory': provinceOrTerritory,
      'district': district,
      'city': city,
      'cityOrTown': city,
      'locality': locality,
      'societyOrScheme': societyOrScheme,
      'sectorOrBlock': sectorOrBlock,
      'street': street,
      'houseOrFlat': houseOrFlat,
      'landmark': landmark,
      'deliveryInstructions': deliveryInstructions,
      'formattedAddress': formattedAddress,
      'latitude': latitude,
      'longitude': longitude,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'isDefault': isDefault,
      'serviceabilityStatus': serviceabilityStatus.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory DeliveryAddressEntity.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    double lat = 24.8607;
    double lng = 67.0011;
    if (map['latitude'] is num) {
      lat = (map['latitude'] as num).toDouble();
    } else if (map['location'] is Map && map['location']['latitude'] is num) {
      lat = (map['location']['latitude'] as num).toDouble();
    }
    if (map['longitude'] is num) {
      lng = (map['longitude'] as num).toDouble();
    } else if (map['location'] is Map && map['location']['longitude'] is num) {
      lng = (map['location']['longitude'] as num).toDouble();
    }

    ServiceabilityStatus status = ServiceabilityStatus.expressAvailable;
    final statusStr = map['serviceabilityStatus'] as String?;
    if (statusStr != null) {
      status = ServiceabilityStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => ServiceabilityStatus.expressAvailable,
      );
    }

    return DeliveryAddressEntity(
      id: id,
      userId: map['userId'] as String? ?? '',
      label: AddressLabel.fromString(map['label'] as String?),
      recipientName: map['recipientName'] as String? ?? 'Recipient',
      recipientPhone: map['recipientPhone'] as String? ?? '',
      provinceOrTerritory: map['provinceOrTerritory'] as String? ?? 'Sindh',
      district: map['district'] as String? ?? 'Karachi',
      city: map['city'] as String? ?? 'Karachi',
      locality: map['locality'] as String? ?? 'Clifton',
      societyOrScheme: map['societyOrScheme'] as String?,
      sectorOrBlock: map['sectorOrBlock'] as String?,
      street: map['street'] as String? ?? '',
      houseOrFlat: map['houseOrFlat'] as String? ?? '',
      landmark: map['landmark'] as String?,
      deliveryInstructions: map['deliveryInstructions'] as String?,
      formattedAddress: map['formattedAddress'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      isDefault: map['isDefault'] as bool? ?? false,
      serviceabilityStatus: status,
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }
}
