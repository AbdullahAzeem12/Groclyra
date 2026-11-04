enum SyncRunStatus {
  running,
  succeeded,
  failed,
}

class CatalogSyncRunEntity {
  final String id;
  final String integrationId;
  final String vendorName;
  final SyncRunStatus status;
  final int productsFetched;
  final int productsCreated;
  final int productsUpdated;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final String? provider;

  const CatalogSyncRunEntity({
    required this.id,
    required this.integrationId,
    required this.vendorName,
    required this.status,
    required this.productsFetched,
    required this.productsCreated,
    required this.productsUpdated,
    required this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.provider,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'integrationId': integrationId,
        'vendorName': vendorName,
        'status': status.name,
        'productsFetched': productsFetched,
        'productsCreated': productsCreated,
        'productsUpdated': productsUpdated,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'errorMessage': errorMessage,
        'provider': provider,
      };

  factory CatalogSyncRunEntity.fromJson(Map<String, dynamic> json) {
    SyncRunStatus parsedStatus = SyncRunStatus.succeeded;
    if (json['status'] != null) {
      for (final s in SyncRunStatus.values) {
        if (s.name.toLowerCase() == json['status'].toString().toLowerCase()) {
          parsedStatus = s;
          break;
        }
      }
    }

    return CatalogSyncRunEntity(
      id: json['id']?.toString() ?? '',
      integrationId: json['integrationId']?.toString() ?? '',
      vendorName: json['vendorName']?.toString() ?? '',
      status: parsedStatus,
      productsFetched: (json['productsFetched'] as num?)?.toInt() ?? 0,
      productsCreated: (json['productsCreated'] as num?)?.toInt() ?? 0,
      productsUpdated: (json['productsUpdated'] as num?)?.toInt() ?? 0,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      errorMessage: json['errorMessage']?.toString(),
      provider: json['provider']?.toString(),
    );
  }
}
