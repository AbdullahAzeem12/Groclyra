import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';

class CartItemEntity {
  final String id;
  final ProductEntity product;
  final ProductVariant? selectedVariant;
  final int quantity;
  final DateTime addedAt;

  const CartItemEntity({
    required this.id,
    required this.product,
    this.selectedVariant,
    required this.quantity,
    required this.addedAt,
  });

  double get unitPrice => selectedVariant?.price ?? product.salePrice;
  double get totalPrice => unitPrice * quantity;
  String get sellerId => product.sellerId;
  String get sellerName => product.sellerName;

  CartItemEntity copyWith({
    int? quantity,
    ProductVariant? selectedVariant,
  }) {
    return CartItemEntity(
      id: id,
      product: product,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product': product.toJson(),
        'selectedVariant': selectedVariant?.toJson(),
        'quantity': quantity,
        'addedAt': addedAt.toIso8601String(),
      };

  factory CartItemEntity.fromJson(Map<String, dynamic> json) => CartItemEntity(
        id: json['id'],
        product: ProductEntity.fromJson(json['product']),
        selectedVariant: json['selectedVariant'] != null
            ? ProductVariant.fromJson(json['selectedVariant'])
            : null,
        quantity: json['quantity'] as int,
        addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
      );
}
