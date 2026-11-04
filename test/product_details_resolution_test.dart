import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/customer/product_details/presentation/screens/product_details_screen.dart';

void main() {
  group('ProductEntity & Variant JSON Resiliency Tests', () {
    test('ProductEntity.fromJson survives missing categoryType, null prices, and untyped maps', () {
      final rawDoc = {
        'id': 'pos_loaded_fries_99',
        'title': 'Loaded Fries (POS)',
        'categoryType': null, // null categoryType
        'basePrice': '450', // string price instead of num
        'salePrice': null, // null sale price
        'restaurantName': 'Foodics Demo Store',
        'isVegetarian': true,
        'preparationTimeMinutes': '15', // string minutes
        'variants': [
          {
            'id': 'var_1',
            'sku': 'FRIES-L',
            'name': 'Large',
            'price': 450,
            'stock': 10.0, // double stock from Firestore
          }
        ],
      };

      final parsed = ProductEntity.fromJson(rawDoc);
      expect(parsed.id, equals('pos_loaded_fries_99'));
      expect(parsed.title, equals('Loaded Fries (POS)'));
      expect(parsed.categoryType, equals(MainCategoryType.grocery)); // safe fallback
      expect(parsed.basePrice, equals(450.0));
      expect(parsed.salePrice, equals(450.0));
      expect(parsed.variants.length, equals(1));
      expect(parsed.variants.first.stock, equals(10));
      expect(parsed.restaurantName, equals('Foodics Demo Store'));
    });

    test('ProductVariant.fromJson handles integer, double, and null prices/stock', () {
      final rawVariant = {
        'id': 'v_rice_5kg',
        'sku': 'RICE-5',
        'name': '5 kg Super Basmati',
        'price': 3500, // int
        'compareAtPrice': 4000.50, // double
        'stock': 25, // int
      };

      final variant = ProductVariant.fromJson(rawVariant);
      expect(variant.id, equals('v_rice_5kg'));
      expect(variant.price, equals(3500.0));
      expect(variant.compareAtPrice, equals(4000.50));
      expect(variant.stock, equals(25));
    });
  });

  group('ProductDetailsScreen Multi-tier Rendering Tests', () {
    testWidgets('Renders ProductDetailsScreen immediately when initialProduct is passed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const testProduct = ProductEntity(
        id: 'foodics_prod_fries_101',
        title: 'Loaded Fries (POS)',
        shortDescription: 'Crispy fries loaded with cheese and chicken',
        description: 'Authentic crispy fries topped with melted mozzarella, grilled fajita strips, and signature spicy dip.',
        categoryType: MainCategoryType.fastFood,
        categoryName: 'Fast Food',
        brand: 'Foodics Demo Store',
        sellerId: 'seller_foodics_1',
        sellerName: 'Foodics Authorized Store',
        basePrice: 450.0,
        salePrice: 450.0,
        discountPercentage: 0,
        rating: 4.8,
        reviewCount: 12,
        soldCount: 85,
        totalStock: 50,
        images: [],
        variants: [],
        restaurantName: 'Foodics Demo Store',
        restaurantType: 'restaurant',
        cuisineType: 'Continental & Fast Food',
        preparationTimeMinutes: 15,
        isVegetarian: false,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProductDetailsScreen(
              productId: 'foodics_prod_fries_101',
              initialProduct: testProduct,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify title, store, and price render
      expect(find.text('Loaded Fries (POS)'), findsOneWidget);
      expect(find.textContaining('Foodics Demo Store'), findsWidgets);
      expect(find.text('Add to Cart'), findsOneWidget);
      expect(find.text('Buy Now'), findsOneWidget);
      expect(find.text('Product not available'), findsNothing);
    });

    testWidgets('Renders fast food specifications for restaurant products', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const fastFoodProduct = ProductEntity(
        id: 'square_prod_fries_102',
        title: 'Loaded Fries (POS)',
        shortDescription: 'Square POS synced fries',
        description: 'Golden seasoned potatoes with melted cheese sauce.',
        categoryType: MainCategoryType.fastFood,
        categoryName: 'Fast Food',
        brand: 'Square Demo Store',
        sellerId: 'seller_sq_1',
        sellerName: 'Square Demo Store',
        basePrice: 450.0,
        salePrice: 450.0,
        discountPercentage: 0,
        rating: 4.7,
        reviewCount: 9,
        soldCount: 40,
        totalStock: 30,
        images: [],
        variants: [],
        restaurantName: 'Square Demo Store',
        cuisineType: 'Fast Food',
        preparationTimeMinutes: 10,
        isVegetarian: true,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProductDetailsScreen(
              productId: 'square_prod_fries_102',
              initialProduct: fastFoodProduct,
            ),
          ),
        ),
      );
      await tester.pump();

      // Scroll to reveal specifications
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Specifications'), findsOneWidget);
      expect(find.text('Square Demo Store'), findsWidgets);
      expect(find.text('10 minutes'), findsOneWidget);
      expect(find.text('100% Vegetarian'), findsOneWidget);
    });
  });
}
