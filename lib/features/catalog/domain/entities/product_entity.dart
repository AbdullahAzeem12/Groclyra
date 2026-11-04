import 'category_entity.dart';

class ProductVariant {
  final String id;
  final String sku;
  final String name;
  final double price;
  final double? compareAtPrice;
  final int stock;
  final String? imageUrl;
  final Map<String, String> attributes; // e.g. {'Pieces': '24 pcs', 'Material': 'Bone China'}

  const ProductVariant({
    required this.id,
    required this.sku,
    required this.name,
    required this.price,
    this.compareAtPrice,
    required this.stock,
    this.imageUrl,
    this.attributes = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'price': price,
        'compareAtPrice': compareAtPrice,
        'stock': stock,
        'imageUrl': imageUrl,
        'attributes': attributes,
      };

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        compareAtPrice: json['compareAtPrice'] != null ? (json['compareAtPrice'] as num?)?.toDouble() : null,
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        imageUrl: json['imageUrl']?.toString(),
        attributes: json['attributes'] != null ? Map<String, String>.from(json['attributes'] as Map) : const {},
      );
}

class ProductEntity {
  final String id;
  final String title;
  final String shortDescription;
  final String description;
  final MainCategoryType categoryType;
  final String categoryName;
  final String brand;
  final String sellerId;
  final String sellerName;
  final double sellerRating;

  final double basePrice;
  final double salePrice;
  final int discountPercentage;
  final double rating;
  final int reviewCount;
  final int soldCount;
  final int totalStock;
  final List<String> images;
  final List<ProductVariant> variants;

  // Crockery Specific Attributes
  final String? material; // Bone China, Porcelain, Ceramic, Glass, Melamine, Stainless Steel
  final bool? isMicrowaveSafe;
  final bool? isDishwasherSafe;
  final int? piecesCount;
  final String? capacity;

  // Grocery Specific Attributes
  final String? weightVolume; // e.g. "5 kg", "1 Litre", "500g"
  final List<String>? dietaryFlags; // Halal, 100% Pure, Organic, Gluten-Free
  final String? storageInstruction; // Keep refrigerated, Store in cool dry place
  final bool? isCookedReadyMeal;

  // Fast Food & Bakery Specific Attributes
  final String? restaurantName;       // e.g. "Al-Baik", "The Bread Factory"
  final String? restaurantType;       // "restaurant" | "bakery" | "cafe" | "dhaba"
  final String? cuisineType;          // e.g. "Pakistani", "Continental", "Chinese"
  final int? preparationTimeMinutes;  // e.g. 25
  final int? deliveryTimeMinutes;     // e.g. 45
  final bool? isVegetarian;
  final List<String>? allergenInfo;   // e.g. ["Gluten", "Dairy", "Nuts"]
  final Map<String, String>? nutritionInfo; // e.g. {"Calories": "650 kcal"}
  final String? portionSize;          // e.g. "Serves 2-3"
  final double? minOrderAmount;       // minimum order for this item

  // Dairy & Bakery Specific Attributes
  final String? unit;                 // e.g. "Litre", "500g", "piece", "loaf"
  final String? packageSize;          // e.g. "1L", "250g", "1kg"
  final int? expiryDays;              // shelf life in days
  final String? storageTemp;          // "Refrigerated", "Ambient", "Frozen"
  final List<String>? ingredients;    // ingredient list
  final List<String>? allergens;      // e.g. ["Gluten", "Dairy", "Nuts"]
  final Map<String, String>? nutritionFacts; // e.g. {"Fat": "3.5g", "Protein": "8g"}
  final bool? isHalal;
  final bool? isOrganic;
  final String? subcategoryName;      // e.g. "Milk", "Bread", "Cake"
  final int? preparationTimeMinutesBakery; // for freshly baked items

  // POS Integration
  final String? externalPosId;
  final String? posProvider;

  // Real-World Vendor Provenance & Live Sync
  final String sourceType; // 'native_seller' | 'vendor_api' | 'pos' | 'open_food_facts' | 'csv_feed' | 'affiliate'
  final String? sourceVendorId;
  final String? sourceStoreId;
  final String? sourceProductId;
  final String? sourceSku;
  final String? externalProductUrl;
  final String checkoutMode; // 'groclyra_marketplace' | 'vendor_checkout' | 'affiliate_link'
  final String stockStatus; // 'in_stock' | 'out_of_stock' | 'unknown'
  final bool inventoryQuantityKnown;
  final DateTime? lastSyncedAt;
  final String? catalogSyncStatus;
  final int? syncFreshnessMinutes;
  final double platformCommissionRate;

  // Moderation & Flags
  final bool isApproved;
  final bool isFeatured;
  final bool isFlashDeal;

  const ProductEntity({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.description,
    required this.categoryType,
    required this.categoryName,
    required this.brand,
    required this.sellerId,
    required this.sellerName,
    this.sellerRating = 0.0,
    required this.basePrice,
    required this.salePrice,
    required this.discountPercentage,
    required this.rating,
    required this.reviewCount,
    required this.soldCount,
    required this.totalStock,
    required this.images,
    required this.variants,
    this.material,
    this.isMicrowaveSafe,
    this.isDishwasherSafe,
    this.piecesCount,
    this.capacity,
    this.weightVolume,
    this.dietaryFlags,
    this.storageInstruction,
    this.isCookedReadyMeal,
    this.restaurantName,
    this.restaurantType,
    this.cuisineType,
    this.preparationTimeMinutes,
    this.deliveryTimeMinutes,
    this.isVegetarian,
    this.allergenInfo,
    this.nutritionInfo,
    this.portionSize,
    this.minOrderAmount,
    // Dairy & Bakery
    this.unit,
    this.packageSize,
    this.expiryDays,
    this.storageTemp,
    this.ingredients,
    this.allergens,
    this.nutritionFacts,
    this.isHalal,
    this.isOrganic,
    this.subcategoryName,
    this.preparationTimeMinutesBakery,
    this.externalPosId,
    this.posProvider,
    this.sourceType = 'native_seller',
    this.sourceVendorId,
    this.sourceStoreId,
    this.sourceProductId,
    this.sourceSku,
    this.externalProductUrl,
    this.checkoutMode = 'groclyra_marketplace',
    this.stockStatus = 'in_stock',
    this.inventoryQuantityKnown = true,
    this.lastSyncedAt,
    this.catalogSyncStatus,
    this.syncFreshnessMinutes = 30,
    this.platformCommissionRate = 0.08,
    this.isApproved = true,
    this.isFeatured = false,
    this.isFlashDeal = false,
  });

  bool get isCrockery => categoryType == MainCategoryType.crockery;
  bool get isGrocery => categoryType == MainCategoryType.grocery;
  bool get isFastFood => categoryType == MainCategoryType.fastFood;
  bool get isBakery => categoryType == MainCategoryType.fastFood && restaurantType == 'bakery';
  bool get isRestaurant => categoryType == MainCategoryType.fastFood && restaurantType == 'restaurant';
  bool get isDairyBakery => categoryType == MainCategoryType.dairyBakery;
  bool get isDairyProduct => isDairyBakery && (subcategoryName != null && ['Milk','Yogurt','Cheese','Butter','Cream','Eggs','Lassi','Ice Cream'].any((s) => subcategoryName!.contains(s)));
  bool get isBakeryItem => isDairyBakery && !isDairyProduct;
  bool get inStock => stockStatus != 'out_of_stock' && totalStock > 0;
  bool get isLiveSynced => sourceType != 'native_seller';
  bool get isStale {
    if (lastSyncedAt == null) return false;
    final freshness = syncFreshnessMinutes ?? 60;
    return DateTime.now().difference(lastSyncedAt!).inMinutes > freshness;
  }
  String get primaryImage {
    if (images.isNotEmpty && images.first.trim().isNotEmpty) {
      return images.first.trim();
    }
    return getSmartFallbackImageUrl(title: title, categoryType: categoryType);
  }

  static String getSmartFallbackImageUrl({String? title, MainCategoryType? categoryType}) {
    final t = (title ?? '').toLowerCase();
    if (t.contains('tea') || t.contains('danedar') || t.contains('chai') || t.contains('tapal')) {
      return 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600';
    }
    if (t.contains('biryani') || t.contains('masala') || t.contains('shan') || t.contains('spice')) {
      return 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=600';
    }
    if (t.contains('milk') || t.contains('olper') || t.contains('milkpak') || t.contains('dairy')) {
      return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600';
    }
    if (t.contains('bread') || t.contains('dawn') || t.contains('toast') || t.contains('bun') || t.contains('loaf')) {
      return 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600';
    }
    if (t.contains('cheese') || t.contains('mozzarella') || t.contains('adams')) {
      return 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=600';
    }
    if (t.contains('dahi') || t.contains('yogurt') || t.contains('prema') || t.contains('cream')) {
      return 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600';
    }
    if (t.contains('burger') || t.contains('patty') || t.contains('patties') || t.contains('k&n')) {
      return 'https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?w=600';
    }
    if (t.contains('pizza') || t.contains('fajita') || t.contains('cheezious')) {
      return 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600';
    }
    if (t.contains('fries') || t.contains('optp') || t.contains('potato')) {
      return 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=600';
    }
    if (t.contains('broast') || t.contains('chicken') || t.contains('al-baik') || t.contains('albaik')) {
      return 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600';
    }
    if (t.contains('cake') || t.contains('pastry') || t.contains('croissant') || t.contains('muffin')) {
      return 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600';
    }
    if (t.contains('oil') || t.contains('dalda') || t.contains('canola')) {
      return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=600';
    }
    if (t.contains('rice') || t.contains('basmati') || t.contains('mughal')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600';
    }
    if (t.contains('pickle') || t.contains('achar')) {
      return 'https://images.unsplash.com/photo-1599599810769-bcde5a160d32?w=600';
    }
    if (t.contains('china') || t.contains('porcelain') || t.contains('noritake') || t.contains('chenone') || t.contains('dinner set')) {
      return 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=600';
    }
    if (t.contains('bowl') || t.contains('borosil') || t.contains('soup')) {
      return 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=600';
    }
    if (t.contains('cup') || t.contains('mug') || t.contains('tea cup') || t.contains('saucer') || t.contains('heritage')) {
      return 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600';
    }
    if (t.contains('plate') || t.contains('platter')) {
      return 'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=600';
    }
    if (t.contains('glass') || t.contains('jug') || t.contains('tumbler')) {
      return 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600';
    }

    switch (categoryType) {
      case MainCategoryType.crockery:
        return 'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=600';
      case MainCategoryType.grocery:
        return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600';
      case MainCategoryType.dairyBakery:
        return 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600';
      case MainCategoryType.fastFood:
        return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600';
      default:
        return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'shortDescription': shortDescription,
        'description': description,
        'categoryType': categoryType.name,
        'categoryName': categoryName,
        'brand': brand,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'sellerRating': sellerRating,
        'basePrice': basePrice,
        'salePrice': salePrice,
        'discountPercentage': discountPercentage,
        'rating': rating,
        'reviewCount': reviewCount,
        'soldCount': soldCount,
        'totalStock': totalStock,
        'images': images,
        'variants': variants.map((v) => v.toJson()).toList(),
        'material': material,
        'isMicrowaveSafe': isMicrowaveSafe,
        'isDishwasherSafe': isDishwasherSafe,
        'piecesCount': piecesCount,
        'capacity': capacity,
        'weightVolume': weightVolume,
        'dietaryFlags': dietaryFlags,
        'storageInstruction': storageInstruction,
        'isCookedReadyMeal': isCookedReadyMeal,
        'restaurantName': restaurantName,
        'restaurantType': restaurantType,
        'cuisineType': cuisineType,
        'preparationTimeMinutes': preparationTimeMinutes,
        'deliveryTimeMinutes': deliveryTimeMinutes,
        'isVegetarian': isVegetarian,
        'allergenInfo': allergenInfo,
        'nutritionInfo': nutritionInfo,
        'portionSize': portionSize,
        'minOrderAmount': minOrderAmount,
        'externalPosId': externalPosId,
        'posProvider': posProvider,
        'sourceType': sourceType,
        'sourceVendorId': sourceVendorId,
        'sourceStoreId': sourceStoreId,
        'sourceProductId': sourceProductId,
        'sourceSku': sourceSku,
        'externalProductUrl': externalProductUrl,
        'checkoutMode': checkoutMode,
        'stockStatus': stockStatus,
        'inventoryQuantityKnown': inventoryQuantityKnown,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'catalogSyncStatus': catalogSyncStatus,
        'syncFreshnessMinutes': syncFreshnessMinutes,
        'platformCommissionRate': platformCommissionRate,
        'isApproved': isApproved,
        'isFeatured': isFeatured,
        'isFlashDeal': isFlashDeal,
        // Dairy & Bakery
        'unit': unit,
        'packageSize': packageSize,
        'expiryDays': expiryDays,
        'storageTemp': storageTemp,
        'ingredients': ingredients,
        'allergens': allergens,
        'nutritionFacts': nutritionFacts,
        'isHalal': isHalal,
        'isOrganic': isOrganic,
        'subcategoryName': subcategoryName,
        'preparationTimeMinutesBakery': preparationTimeMinutesBakery,
      };

  factory ProductEntity.fromJson(Map<String, dynamic> json) {
    MainCategoryType parsedCategoryType = MainCategoryType.grocery;
    if (json['categoryType'] != null) {
      final catStr = json['categoryType'].toString().toLowerCase().trim();
      for (final val in MainCategoryType.values) {
        if (val.name.toLowerCase() == catStr) {
          parsedCategoryType = val;
          break;
        }
      }
    }

    final rawBasePrice = json['basePrice'];
    final basePrice = rawBasePrice is num
        ? rawBasePrice.toDouble()
        : (double.tryParse(rawBasePrice?.toString() ?? '') ?? 0.0);

    final rawSalePrice = json['salePrice'];
    final salePrice = rawSalePrice is num
        ? rawSalePrice.toDouble()
        : (double.tryParse(rawSalePrice?.toString() ?? '') ?? basePrice);

    final rawImages = json['images'];
    List<String> images = [];
    if (rawImages is List) {
      images = rawImages.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    if (images.isEmpty && json['primaryImage'] != null && json['primaryImage'].toString().isNotEmpty) {
      images = [json['primaryImage'].toString()];
    }

    final rawVariants = json['variants'];
    List<ProductVariant> variants = [];
    if (rawVariants is List) {
      for (final v in rawVariants) {
        if (v is Map) {
          try {
            variants.add(ProductVariant.fromJson(Map<String, dynamic>.from(v)));
          } catch (_) {}
        }
      }
    }

    int toIntSafe(dynamic val, [int fallback = 0]) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    int? toIntSafeNullable(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    double toDoubleSafe(dynamic val, [double fallback = 0.0]) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    double? toDoubleSafeNullable(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return ProductEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Product',
      shortDescription: json['shortDescription']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      categoryType: parsedCategoryType,
      categoryName: json['categoryName']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      sellerId: json['sellerId']?.toString() ?? '',
      sellerName: json['sellerName']?.toString() ?? '',
      sellerRating: toDoubleSafe(json['sellerRating'], 0.0),
      basePrice: basePrice,
      salePrice: salePrice,
      discountPercentage: toIntSafe(json['discountPercentage'], 0),
      rating: toDoubleSafe(json['rating'], 0.0),
      reviewCount: toIntSafe(json['reviewCount'], 0),
      soldCount: toIntSafe(json['soldCount'], 0),
      totalStock: toIntSafe(json['totalStock'], 0),
      images: images,
      variants: variants,
      material: json['material']?.toString(),
      isMicrowaveSafe: json['isMicrowaveSafe'] as bool?,
      isDishwasherSafe: json['isDishwasherSafe'] as bool?,
      piecesCount: toIntSafeNullable(json['piecesCount']),
      capacity: json['capacity']?.toString(),
      weightVolume: json['weightVolume']?.toString(),
      dietaryFlags: (json['dietaryFlags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      storageInstruction: json['storageInstruction']?.toString(),
      isCookedReadyMeal: json['isCookedReadyMeal'] as bool?,
      restaurantName: json['restaurantName']?.toString(),
      restaurantType: json['restaurantType']?.toString(),
      cuisineType: json['cuisineType']?.toString(),
      preparationTimeMinutes: toIntSafeNullable(json['preparationTimeMinutes']),
      deliveryTimeMinutes: toIntSafeNullable(json['deliveryTimeMinutes']),
      isVegetarian: json['isVegetarian'] as bool?,
      allergenInfo: (json['allergenInfo'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      nutritionInfo: json['nutritionInfo'] != null
          ? Map<String, String>.from(json['nutritionInfo'] as Map)
          : null,
      portionSize: json['portionSize']?.toString(),
      minOrderAmount: toDoubleSafeNullable(json['minOrderAmount']),
      externalPosId: json['externalPosId']?.toString(),
      posProvider: json['posProvider']?.toString(),
      sourceType: json['sourceType']?.toString() ?? 'native_seller',
      sourceVendorId: json['sourceVendorId']?.toString(),
      sourceStoreId: json['sourceStoreId']?.toString(),
      sourceProductId: json['sourceProductId']?.toString(),
      sourceSku: json['sourceSku']?.toString(),
      externalProductUrl: json['externalProductUrl']?.toString(),
      checkoutMode: json['checkoutMode']?.toString() ?? 'groclyra_marketplace',
      stockStatus: json['stockStatus']?.toString() ?? 'in_stock',
      inventoryQuantityKnown: json['inventoryQuantityKnown'] as bool? ?? true,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.tryParse(json['lastSyncedAt'].toString())
          : null,
      catalogSyncStatus: json['catalogSyncStatus']?.toString(),
      syncFreshnessMinutes: toIntSafeNullable(json['syncFreshnessMinutes']) ?? 30,
      platformCommissionRate: toDoubleSafe(json['platformCommissionRate'], 0.08),
      isApproved: json['isApproved'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isFlashDeal: json['isFlashDeal'] as bool? ?? false,
      // Dairy & Bakery - all optional with safe defaults
      unit: json['unit']?.toString(),
      packageSize: json['packageSize']?.toString(),
      expiryDays: toIntSafeNullable(json['expiryDays']),
      storageTemp: json['storageTemp']?.toString(),
      ingredients: (json['ingredients'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      allergens: (json['allergens'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      nutritionFacts: json['nutritionFacts'] != null
          ? Map<String, String>.from(json['nutritionFacts'] as Map)
          : null,
      isHalal: json['isHalal'] as bool?,
      isOrganic: json['isOrganic'] as bool?,
      subcategoryName: json['subcategoryName']?.toString(),
      preparationTimeMinutesBakery: toIntSafeNullable(json['preparationTimeMinutesBakery']),
    );
  }
}
