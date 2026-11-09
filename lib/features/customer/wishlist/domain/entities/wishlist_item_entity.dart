import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';

class WishlistItemEntity {
  final String id;
  final String userId;
  final String productId;
  final String? variantId;
  final String title;
  final MainCategoryType categoryType;
  final String categoryName;
  final String brand;
  final String imageUrl;
  final double savedPrice;
  final double currentPrice;
  final double? compareAtPrice;
  final bool inStock;
  final int stockCount;
  final String? selectedVariantName;
  final String collectionName;
  final DateTime savedAt;

  const WishlistItemEntity({
    required this.id,
    required this.userId,
    required this.productId,
    this.variantId,
    required this.title,
    required this.categoryType,
    required this.categoryName,
    required this.brand,
    required this.imageUrl,
    required this.savedPrice,
    required this.currentPrice,
    this.compareAtPrice,
    this.inStock = true,
    this.stockCount = 10,
    this.selectedVariantName,
    this.collectionName = 'General',
    required this.savedAt,
  });

  bool get hasPriceDrop => currentPrice < savedPrice;
  double get priceDropAmount => hasPriceDrop ? (savedPrice - currentPrice) : 0.0;
  int get discountPercent => hasPriceDrop ? (((savedPrice - currentPrice) / savedPrice) * 100).round() : 0;


  WishlistItemEntity copyWith({
    String? id,
    String? userId,
    String? productId,
    String? variantId,
    String? title,
    MainCategoryType? categoryType,
    String? categoryName,
    String? brand,
    String? imageUrl,
    double? savedPrice,
    double? currentPrice,
    double? compareAtPrice,
    bool? inStock,
    int? stockCount,
    String? selectedVariantName,
    String? collectionName,
    DateTime? savedAt,
  }) {
    return WishlistItemEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      title: title ?? this.title,
      categoryType: categoryType ?? this.categoryType,
      categoryName: categoryName ?? this.categoryName,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
      savedPrice: savedPrice ?? this.savedPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      inStock: inStock ?? this.inStock,
      stockCount: stockCount ?? this.stockCount,
      selectedVariantName: selectedVariantName ?? this.selectedVariantName,
      collectionName: collectionName ?? this.collectionName,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'productId': productId,
      'variantId': variantId,
      'title': title,
      'categoryType': categoryType.name,
      'categoryName': categoryName,
      'brand': brand,
      'imageUrl': imageUrl,
      'savedPrice': savedPrice,
      'currentPrice': currentPrice,
      'compareAtPrice': compareAtPrice,
      'inStock': inStock,
      'stockCount': stockCount,
      'selectedVariantName': selectedVariantName,
      'collectionName': collectionName,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory WishlistItemEntity.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      try {
        final dynamic d = val;
        if (d != null && d.toDate != null) return d.toDate();
      } catch (_) {}
      return DateTime.now();
    }

    MainCategoryType catType = MainCategoryType.grocery;
    if (map['categoryType'] == 'crockery') {
      catType = MainCategoryType.crockery;
    }

    return WishlistItemEntity(
      id: docId,
      userId: map['userId'] as String? ?? '',
      productId: map['productId'] as String? ?? docId,
      variantId: map['variantId'] as String?,
      title: map['title'] as String? ?? 'Product',
      categoryType: catType,
      categoryName: map['categoryName'] as String? ?? 'General',
      brand: map['brand'] as String? ?? 'Groclyra Essentials',
      imageUrl: map['imageUrl'] as String? ?? 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=400',
      savedPrice: (map['savedPrice'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (map['currentPrice'] as num?)?.toDouble() ?? 0.0,
      compareAtPrice: (map['compareAtPrice'] as num?)?.toDouble(),
      inStock: map['inStock'] as bool? ?? true,
      stockCount: map['stockCount'] as int? ?? 10,
      selectedVariantName: map['selectedVariantName'] as String?,
      collectionName: map['collectionName'] as String? ?? 'General',
      savedAt: parseDate(map['savedAt']),
    );
  }
}
