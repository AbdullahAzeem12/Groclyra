import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';

enum VendorCommerceMode {
  marketplace,
  catalogOnly,
  affiliate,
}

enum VendorIntegrationStatus {
  active,
  pendingAuthorization,
  syncing,
  error,
  inactive,
}

enum VendorProviderType {
  wooCommerce,
  shopify,
  openFoodFacts,
  pos,
  csvFeed,
}

class VendorIntegrationEntity {
  final String id;
  final String vendorId;
  final String vendorName;
  final String businessAddress;
  final String city;
  final VendorProviderType provider;
  final VendorIntegrationStatus status;
  final VendorCommerceMode commerceMode;
  final String externalStoreUrl;
  final MainCategoryType categoryType;
  final String categoryName;
  final double platformCommissionRate; // e.g. 0.065 for 6.5%
  final int totalProductsSynced;
  final double totalGrossSales;
  final double totalCommissionEarned;
  final double totalVendorPayable;
  final DateTime? lastSyncAt;
  final String? lastSyncStatus;
  final int syncIntervalMinutes;
  final bool isDomainVerified;
  final bool isAuthorized;

  const VendorIntegrationEntity({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.businessAddress,
    required this.city,
    required this.provider,
    required this.status,
    required this.commerceMode,
    required this.externalStoreUrl,
    required this.categoryType,
    required this.categoryName,
    this.platformCommissionRate = 0.08,
    this.totalProductsSynced = 0,
    this.totalGrossSales = 0.0,
    this.totalCommissionEarned = 0.0,
    this.totalVendorPayable = 0.0,
    this.lastSyncAt,
    this.lastSyncStatus,
    this.syncIntervalMinutes = 30,
    this.isDomainVerified = true,
    this.isAuthorized = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'businessAddress': businessAddress,
        'city': city,
        'provider': provider.name,
        'status': status.name,
        'commerceMode': commerceMode.name,
        'externalStoreUrl': externalStoreUrl,
        'categoryType': categoryType.name,
        'categoryName': categoryName,
        'platformCommissionRate': platformCommissionRate,
        'totalProductsSynced': totalProductsSynced,
        'totalGrossSales': totalGrossSales,
        'totalCommissionEarned': totalCommissionEarned,
        'totalVendorPayable': totalVendorPayable,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'lastSyncStatus': lastSyncStatus,
        'syncIntervalMinutes': syncIntervalMinutes,
        'isDomainVerified': isDomainVerified,
        'isAuthorized': isAuthorized,
      };

  factory VendorIntegrationEntity.fromJson(Map<String, dynamic> json) {
    VendorProviderType parsedProvider = VendorProviderType.openFoodFacts;
    if (json['provider'] != null) {
      for (final p in VendorProviderType.values) {
        if (p.name.toLowerCase() == json['provider'].toString().toLowerCase()) {
          parsedProvider = p;
          break;
        }
      }
    }

    VendorIntegrationStatus parsedStatus = VendorIntegrationStatus.active;
    if (json['status'] != null) {
      for (final s in VendorIntegrationStatus.values) {
        if (s.name.toLowerCase() == json['status'].toString().toLowerCase()) {
          parsedStatus = s;
          break;
        }
      }
    }

    VendorCommerceMode parsedMode = VendorCommerceMode.marketplace;
    if (json['commerceMode'] != null) {
      for (final m in VendorCommerceMode.values) {
        if (m.name.toLowerCase() == json['commerceMode'].toString().toLowerCase()) {
          parsedMode = m;
          break;
        }
      }
    }

    MainCategoryType parsedCat = MainCategoryType.grocery;
    if (json['categoryType'] != null) {
      for (final c in MainCategoryType.values) {
        if (c.name.toLowerCase() == json['categoryType'].toString().toLowerCase()) {
          parsedCat = c;
          break;
        }
      }
    }

    return VendorIntegrationEntity(
      id: json['id']?.toString() ?? '',
      vendorId: json['vendorId']?.toString() ?? '',
      vendorName: json['vendorName']?.toString() ?? 'Partner Store',
      businessAddress: json['businessAddress']?.toString() ?? 'Pakistan',
      city: json['city']?.toString() ?? 'Karachi',
      provider: parsedProvider,
      status: parsedStatus,
      commerceMode: parsedMode,
      externalStoreUrl: json['externalStoreUrl']?.toString() ?? '',
      categoryType: parsedCat,
      categoryName: json['categoryName']?.toString() ?? 'General',
      platformCommissionRate: (json['platformCommissionRate'] as num?)?.toDouble() ?? 0.08,
      totalProductsSynced: (json['totalProductsSynced'] as num?)?.toInt() ?? 0,
      totalGrossSales: (json['totalGrossSales'] as num?)?.toDouble() ?? 0.0,
      totalCommissionEarned: (json['totalCommissionEarned'] as num?)?.toDouble() ?? 0.0,
      totalVendorPayable: (json['totalVendorPayable'] as num?)?.toDouble() ?? 0.0,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.tryParse(json['lastSyncAt'].toString())
          : null,
      lastSyncStatus: json['lastSyncStatus']?.toString(),
      syncIntervalMinutes: (json['syncIntervalMinutes'] as num?)?.toInt() ?? 30,
      isDomainVerified: json['isDomainVerified'] as bool? ?? true,
      isAuthorized: json['isAuthorized'] as bool? ?? true,
    );
  }
}
