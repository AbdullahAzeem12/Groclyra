class SellerStoreEntity {
  final String id;
  final String sellerId;
  final String storeName;
  final String? ownerName;
  final String? email;
  final String? phone;
  final String? businessCategory;
  final String? storeDescription;
  final String? storeAddress;
  final String? logoUrl;
  final String? bannerUrl;
  final double rating;
  final int totalProducts;
  final int totalOrders;
  final double todayRevenue;
  final double totalRevenue;
  final double pendingPayout;
  final int lowStockCount;
  final bool isKycApproved;
  final String? accountStatus;

  const SellerStoreEntity({
    required this.id,
    required this.sellerId,
    required this.storeName,
    this.ownerName,
    this.email,
    this.phone,
    this.businessCategory,
    this.storeDescription,
    this.storeAddress,
    this.logoUrl,
    this.bannerUrl,
    required this.rating,
    required this.totalProducts,
    required this.totalOrders,
    required this.todayRevenue,
    required this.totalRevenue,
    required this.pendingPayout,
    required this.lowStockCount,
    required this.isKycApproved,
    this.accountStatus,
  });
}
