/// Groclyra SQL Relational Table Definitions & Schema Registry
/// All tables, columns, indexes, and primary keys defined here without magic strings.
library database_tables;

abstract class UsersTable {
  static const String tableName = 'users';
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colEmail = 'email';
  static const String colPhone = 'phone';
  static const String colRole = 'role';
  static const String colAccountStatus = 'accountStatus';
  static const String colActivePortalRole = 'activePortalRole';
  static const String colAuthorizedRolesJson = 'authorizedRolesJson';
  static const String colAvatarUrl = 'avatarUrl';
  static const String colDeliveryAddress = 'deliveryAddress';
  static const String colDeliveryZone = 'deliveryZone';
  static const String colDeviceToken = 'deviceToken';
  static const String colPasswordHash = 'passwordHash';
  static const String colOauthProvider = 'oauthProvider';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';
  static const String colFullDataJson = 'fullDataJson';
}

abstract class CategoriesTable {
  static const String tableName = 'categories';
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colParentType = 'parentType';
  static const String colIconEmoji = 'iconEmoji';
  static const String colImageUrl = 'imageUrl';
  static const String colProductCount = 'productCount';
  static const String colSubcategoriesJson = 'subcategoriesJson';
  static const String colSortOrder = 'sortOrder';
  static const String colCreatedAt = 'createdAt';
  static const String colFullDataJson = 'fullDataJson';
}

abstract class ProductsTable {
  static const String tableName = 'products';
  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colBrand = 'brand';
  static const String colBasePrice = 'basePrice';
  static const String colSalePrice = 'salePrice';
  static const String colDiscountPercentage = 'discountPercentage';
  static const String colUnit = 'unit';
  static const String colCategoryId = 'categoryId';
  static const String colSubcategory = 'subcategory';
  static const String colParentCategory = 'parentCategory';
  static const String colImageUrl = 'imageUrl';
  static const String colSecondaryImagesJson = 'secondaryImagesJson';
  static const String colRating = 'rating';
  static const String colReviewCount = 'reviewCount';
  static const String colIsAvailable = 'isAvailable';
  static const String colIsFlashDeal = 'isFlashDeal';
  static const String colStockQuantity = 'stockQuantity';
  static const String colVendorId = 'vendorId';
  static const String colVendorStoreName = 'vendorStoreName';
  static const String colFullDataJson = 'fullDataJson';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class ReviewsTable {
  static const String tableName = 'reviews';
  static const String colId = 'id';
  static const String colProductId = 'productId';
  static const String colUserId = 'userId';
  static const String colUserName = 'userName';
  static const String colUserAvatar = 'userAvatar';
  static const String colRating = 'rating';
  static const String colComment = 'comment';
  static const String colVerified = 'verified';
  static const String colHelpfulVotes = 'helpfulVotes';
  static const String colCreatedAt = 'createdAt';
  static const String colFullDataJson = 'fullDataJson';
}

abstract class AddressesTable {
  static const String tableName = 'addresses';
  static const String colId = 'id';
  static const String colUserId = 'userId';
  static const String colLabel = 'label';
  static const String colRecipientName = 'recipientName';
  static const String colPhone = 'phone';
  static const String colProvinceOrTerritory = 'provinceOrTerritory';
  static const String colCity = 'city';
  static const String colLocality = 'locality';
  static const String colSocietyOrScheme = 'societyOrScheme';
  static const String colSectorOrBlock = 'sectorOrBlock';
  static const String colStreet = 'street';
  static const String colHouseOrFlat = 'houseOrFlat';
  static const String colFormattedAddress = 'formattedAddress';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colIsDefault = 'isDefault';
  static const String colServiceabilityStatus = 'serviceabilityStatus';
  static const String colFullDataJson = 'fullDataJson';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class OrdersTable {
  static const String tableName = 'orders';
  static const String colId = 'id';
  static const String colUserId = 'userId';
  static const String colTotalAmount = 'totalAmount';
  static const String colDiscountAmount = 'discountAmount';
  static const String colDeliveryFee = 'deliveryFee';
  static const String colFinalAmount = 'finalAmount';
  static const String colStatus = 'status';
  static const String colPaymentMethod = 'paymentMethod';
  static const String colPaymentStatus = 'paymentStatus';
  static const String colTransactionRef = 'transactionRef';
  static const String colDeliveryAddressJson = 'deliveryAddressJson';
  static const String colTrackingNumber = 'trackingNumber';
  static const String colRiderId = 'riderId';
  static const String colEstimatedDeliveryTime = 'estimatedDeliveryTime';
  static const String colDeliveredAt = 'deliveredAt';
  static const String colFullDataJson = 'fullDataJson';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class OrderItemsTable {
  static const String tableName = 'order_items';
  static const String colId = 'id';
  static const String colOrderId = 'orderId';
  static const String colProductId = 'productId';
  static const String colTitle = 'title';
  static const String colVariantName = 'variantName';
  static const String colUnitPrice = 'unitPrice';
  static const String colQuantity = 'quantity';
  static const String colLineTotal = 'lineTotal';
  static const String colImageUrl = 'imageUrl';
  static const String colFullDataJson = 'fullDataJson';
}

abstract class WishlistTable {
  static const String tableName = 'wishlist';
  static const String colId = 'id';
  static const String colUserId = 'userId';
  static const String colProductId = 'productId';
  static const String colOriginalPrice = 'originalPrice';
  static const String colCurrentPrice = 'currentPrice';
  static const String colAddedAt = 'addedAt';
  static const String colFullDataJson = 'fullDataJson';
}

abstract class SellerProfilesTable {
  static const String tableName = 'seller_profiles';
  static const String colSellerId = 'sellerId';
  static const String colStoreName = 'storeName';
  static const String colOwnerName = 'ownerName';
  static const String colBusinessEmail = 'businessEmail';
  static const String colPhone = 'phone';
  static const String colStoreCategory = 'storeCategory';
  static const String colVerificationStatus = 'verificationStatus';
  static const String colCity = 'city';
  static const String colFullAddress = 'fullAddress';
  static const String colCnicOrNtn = 'cnicOrNtn';
  static const String colBankName = 'bankName';
  static const String colAccountNumber = 'accountNumber';
  static const String colAccountTitle = 'accountTitle';
  static const String colRating = 'rating';
  static const String colTotalOrders = 'totalOrders';
  static const String colFullDataJson = 'fullDataJson';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class DeliveryTasksTable {
  static const String tableName = 'delivery_tasks';
  static const String colId = 'id';
  static const String colOrderId = 'orderId';
  static const String colRiderId = 'riderId';
  static const String colStatus = 'status';
  static const String colPickupLocationName = 'pickupLocationName';
  static const String colPickupAddress = 'pickupAddress';
  static const String colPickupLat = 'pickupLat';
  static const String colPickupLng = 'pickupLng';
  static const String colDropRecipientName = 'dropRecipientName';
  static const String colDropAddress = 'dropAddress';
  static const String colDropPhone = 'dropPhone';
  static const String colDropLat = 'dropLat';
  static const String colDropLng = 'dropLng';
  static const String colDeliveryFeeEarnings = 'deliveryFeeEarnings';
  static const String colDeliveryOtp = 'deliveryOtp';
  static const String colFullDataJson = 'fullDataJson';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class RiderProfilesTable {
  static const String tableName = 'rider_profiles';
  static const String colRiderId = 'riderId';
  static const String colFullName = 'fullName';
  static const String colPhone = 'phone';
  static const String colCity = 'city';
  static const String colVehicleType = 'vehicleType';
  static const String colVehicleNumber = 'vehicleNumber';
  static const String colCnicNumber = 'cnicNumber';
  static const String colDrivingLicenseNumber = 'drivingLicenseNumber';
  static const String colAccountStatus = 'accountStatus';
  static const String colRating = 'rating';
  static const String colTotalDeliveries = 'totalDeliveries';
  static const String colCurrentLat = 'currentLat';
  static const String colCurrentLng = 'currentLng';
  static const String colIsOnline = 'isOnline';
  static const String colWalletBalance = 'walletBalance';
  static const String colFullDataJson = 'fullDataJson';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class VendorIntegrationsTable {
  static const String tableName = 'vendor_integrations';
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colStoreName = 'storeName';
  static const String colLogoUrl = 'logoUrl';
  static const String colBannerUrl = 'bannerUrl';
  static const String colRating = 'rating';
  static const String colVerified = 'verified';
  static const String colIsOpen = 'isOpen';
  static const String colCity = 'city';
  static const String colAddress = 'address';
  static const String colTotalProducts = 'totalProducts';
  static const String colLiveSync = 'liveSync';
  static const String colCatalogType = 'catalogType';
  static const String colCreatedAt = 'createdAt';
}

abstract class NotificationsTable {
  static const String tableName = 'notifications';
  static const String colId = 'id';
  static const String colUserId = 'userId';
  static const String colTitle = 'title';
  static const String colBody = 'body';
  static const String colType = 'type';
  static const String colIsRead = 'isRead';
  static const String colCreatedAt = 'createdAt';
  static const String colFullDataJson = 'fullDataJson';
}

abstract class SupportMessagesTable {
  static const String tableName = 'support_messages';
  static const String colId = 'id';
  static const String colTicketId = 'ticketId';
  static const String colUserId = 'userId';
  static const String colSenderType = 'senderType';
  static const String colMessage = 'message';
  static const String colAttachmentUrl = 'attachmentUrl';
  static const String colCreatedAt = 'createdAt';
}

abstract class NotificationPreferencesTable {
  static const String tableName = 'notification_preferences';
  static const String colUserId = 'userId';
  static const String colOrdersPush = 'ordersPush';
  static const String colPromotionsPush = 'promotionsPush';
  static const String colDeliverySms = 'deliverySms';
  static const String colNewsletterEmail = 'newsletterEmail';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class SystemTelemetryTable {
  static const String tableName = 'system_telemetry';
  static const String colKey = 'key';
  static const String colValue = 'value';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class CouponsTable {
  static const String tableName = 'coupons';
  static const String colId = 'id';
  static const String colCode = 'code';
  static const String colTitle = 'title';
  static const String colDiscountPercentage = 'discountPercentage';
  static const String colMaxDiscount = 'maxDiscount';
  static const String colMinOrderAmount = 'minOrderAmount';
  static const String colValidUntil = 'validUntil';
  static const String colIsActive = 'isActive';
  static const String colUsageCount = 'usageCount';
  static const String colCreatedAt = 'createdAt';
}

abstract class SchemaMigrationsTable {
  static const String tableName = 'schema_migrations';
  static const String colVersion = 'version';
  static const String colName = 'name';
  static const String colAppliedAt = 'appliedAt';
}

abstract class AppPreferencesTable {
  static const String tableName = 'app_preferences';
  static const String colKey = 'key';
  static const String colValue = 'value';
  static const String colType = 'type';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class AppSecureVaultTable {
  static const String tableName = 'app_secure_vault';
  static const String colKey = 'key';
  static const String colValue = 'value';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class CartCacheTable {
  static const String tableName = 'cart_cache';
  static const String colUserId = 'userId';
  static const String colProductId = 'productId';
  static const String colQuantity = 'quantity';
  static const String colVariantName = 'variantName';
  static const String colUnitPrice = 'unitPrice';
  static const String colFullDataJson = 'fullDataJson';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class AppRateLimitsTable {
  static const String tableName = 'app_rate_limits';
  static const String colKey = 'key';
  static const String colHitCount = 'hitCount';
  static const String colLastAttemptEpoch = 'lastAttemptEpoch';
  static const String colLockoutUntilEpoch = 'lockoutUntilEpoch';
  static const String colUpdatedAt = 'updatedAt';
}

abstract class OfflineMutationsTable {
  static const String tableName = 'offline_mutations';
  static const String colId = 'id';
  static const String colMutationType = 'mutationType';
  static const String colPayloadJson = 'payloadJson';
  static const String colStatus = 'status';
  static const String colCreatedAt = 'createdAt';
}
