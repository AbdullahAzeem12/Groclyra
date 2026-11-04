import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/customer/wishlist/data/repositories/wishlist_repository.dart';
import 'package:groclyra/features/customer/wishlist/domain/entities/wishlist_item_entity.dart';

void main() {
  group('WishlistItemEntity Domain & Price Drop Logic Tests', () {
    test('Calculates price drop amount and percentage correctly', () {
      final itemWithDrop = WishlistItemEntity(
        id: 'wish_test_drop',
        userId: 'usr_test',
        productId: 'prod_crock_01',
        title: 'Bone China 24-Piece Dinner Set',
        categoryType: MainCategoryType.crockery,
        categoryName: 'Dinner Sets',
        brand: 'Groclyra Luxury Tableware',
        imageUrl: 'https://example.com/item.jpg',
        savedPrice: 15000.0,
        currentPrice: 12000.0, // 3000 drop (20% off)
        inStock: true,
        collectionName: 'Dinner Sets',
        savedAt: DateTime.now(),
      );

      expect(itemWithDrop.hasPriceDrop, isTrue);
      expect(itemWithDrop.priceDropAmount, equals(3000.0));
      expect(itemWithDrop.discountPercent, equals(20));
      expect(itemWithDrop.inStock, isTrue);
    });

    test('Reports no price drop when current price is equal or higher than saved price', () {
      final normalItem = WishlistItemEntity(
        id: 'wish_test_normal',
        userId: 'usr_test',
        productId: 'prod_groc_01',
        title: 'Organic Basmati Rice 5kg',
        categoryType: MainCategoryType.grocery,
        categoryName: 'Grains & Rice',
        brand: 'Punjab Harvest',
        imageUrl: 'https://example.com/rice.jpg',
        savedPrice: 2200.0,
        currentPrice: 2200.0,
        inStock: true,
        collectionName: 'Daily Groceries',
        savedAt: DateTime.now(),
      );

      expect(normalItem.hasPriceDrop, isFalse);
      expect(normalItem.priceDropAmount, equals(0.0));
    });

    test('Preserves grocery vs crockery category flag and variant selection', () {
      final crockeryItem = WishlistItemEntity(
        id: 'wish_crock_01',
        userId: 'usr_1',
        productId: 'prod_c1',
        variantId: 'var_gold_rim_32pc',
        selectedVariantName: '32-Piece Gold Rim',
        title: 'Imperial Opal Glass Tea Set',
        categoryType: MainCategoryType.crockery,
        categoryName: 'Tea Sets',
        brand: 'Opaline Elite',
        imageUrl: 'https://example.com/teaset.jpg',
        savedPrice: 8500.0,
        currentPrice: 8500.0,
        savedAt: DateTime.now(),
      );

      expect(crockeryItem.categoryType, equals(MainCategoryType.crockery));
      expect(crockeryItem.selectedVariantName, equals('32-Piece Gold Rim'));
      expect(crockeryItem.variantId, equals('var_gold_rim_32pc'));
    });

    test('Serialization toMap and fromMap preserves all fields', () {
      final item = WishlistItemEntity(
        id: 'wish_serialize_01',
        userId: 'usr_2',
        productId: 'prod_g2',
        title: 'Pure Desi Ghee 1kg',
        categoryType: MainCategoryType.grocery,
        categoryName: 'Dairy',
        brand: 'Chakwal Farms',
        imageUrl: 'https://example.com/ghee.jpg',
        savedPrice: 3400.0,
        currentPrice: 3100.0,
        compareAtPrice: 3600.0,
        inStock: true,
        stockCount: 15,
        collectionName: 'Kitchen Essentials',
        savedAt: DateTime(2026, 10, 20, 10, 0),
      );

      final map = item.toMap();
      final restored = WishlistItemEntity.fromMap(map, 'wish_serialize_01');

      expect(restored.id, equals(item.id));
      expect(restored.productId, equals(item.productId));
      expect(restored.savedPrice, equals(item.savedPrice));
      expect(restored.currentPrice, equals(item.currentPrice));
      expect(restored.collectionName, equals('Kitchen Essentials'));
      expect(restored.hasPriceDrop, isTrue);
    });
  });

  group('WishlistRepository In-Memory & Operation Tests', () {
    test('WishlistRepository initializes default seed items when fresh', () async {
      final repo = WishlistRepository();
      final items = await repo.getWishlist(userId: 'usr_guest');

      expect(items, isNotEmpty);
      expect(items.any((i) => i.categoryType == MainCategoryType.crockery), isTrue);
      expect(items.any((i) => i.categoryType == MainCategoryType.grocery), isTrue);
    });

    test('Add item to wishlist updates list and prevents duplicate productIds', () async {
      final repo = WishlistRepository();
      final newItem = WishlistItemEntity(
        id: 'wish_new_spice',
        userId: 'usr_test_add',
        productId: 'prod_spice_09',
        title: 'Sindhi Biryani Masala 100g',
        categoryType: MainCategoryType.grocery,
        categoryName: 'Spices',
        brand: 'National Foods',
        imageUrl: 'https://example.com/spice.jpg',
        savedPrice: 150.0,
        currentPrice: 150.0,
        savedAt: DateTime.now(),
      );

      await repo.addToWishlist(newItem);
      final list = await repo.getWishlist(userId: 'usr_test_add');

      expect(list.any((i) => i.productId == 'prod_spice_09'), isTrue);

      // Re-adding the same product should update rather than duplicate
      final updatedItem = newItem.copyWith(currentPrice: 130.0);
      await repo.addToWishlist(updatedItem);

      final count = (await repo.getWishlist(userId: 'usr_test_add'))
          .where((i) => i.productId == 'prod_spice_09')
          .length;
      expect(count, equals(1));
    });

    test('Remove item from wishlist deletes item successfully', () async {
      final repo = WishlistRepository();
      final items = await repo.getWishlist(userId: 'usr_guest');
      final firstId = items.first.id;

      await repo.removeFromWishlist(userId: 'usr_guest', itemId: firstId);
      final remaining = await repo.getWishlist(userId: 'usr_guest');

      expect(remaining.any((i) => i.id == firstId), isFalse);
    });
  });
}
