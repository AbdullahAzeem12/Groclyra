import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/auth/domain/entities/account_status.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/customer/cart/domain/entities/cart_item_entity.dart';
import 'package:groclyra/features/customer/checkout/presentation/screens/checkout_screen.dart';
import 'package:groclyra/features/customer/product_details/presentation/screens/product_details_screen.dart';
import 'package:groclyra/features/customer/reviews/data/repositories/review_repository.dart';
import 'package:groclyra/features/customer/reviews/presentation/controllers/review_controller.dart';

class _TestMockAuthController extends StateNotifier<AuthState> implements AuthController {
  _TestMockAuthController()
      : super(
          AuthState(
            user: UserEntity(
              id: 'test_usr_01',
              name: 'Ayesha Khan',
              email: 'ayesha@groclyra.pk',
              phone: '03001234567',
              role: UserRole.customer,
              accountStatus: AccountStatus.active,
              deliveryAddress: 'House 42, Street 8, DHA Phase 5, Lahore',
              deliveryZone: 'DHA Phase 5, Lahore',
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const dummyProduct = ProductEntity(
    id: 'test_broast_001',
    title: 'Al-Baik Crispy Broast 8 Pcs',
    shortDescription: 'Crispy fried chicken broast with spicy dip',
    description: 'Hot and crispy chicken broast prepared with traditional secret spices.',
    categoryType: MainCategoryType.fastFood,
    categoryName: 'Fast Food',
    brand: 'Al-Baik',
    sellerId: 'vendor_albaik',
    sellerName: 'Al-Baik Official',
    basePrice: 1500.0,
    salePrice: 1399.0,
    discountPercentage: 7,
    rating: 4.9,
    reviewCount: 312,
    soldCount: 1500,
    totalStock: 5,
    images: ['https://images.unsplash.com/photo-1562967914-608f82629710?w=600'],
    variants: [
      ProductVariant(
        id: 'var_family',
        sku: 'ALB-8P',
        name: '8 Pieces (Family)',
        price: 1399.0,
        compareAtPrice: 1500.0,
        stock: 5,
      ),
    ],
  );

  group('ReviewRepository & ReviewController Domain & Real-Time Sync Tests', () {
    test('Generates authentic category-aware reviews for each category', () {
      final repo = ReviewRepository();
      final reviews = repo.getReviewsForProduct(dummyProduct);

      expect(reviews.isNotEmpty, isTrue);
      expect(reviews.length, greaterThanOrEqualTo(3));
      expect(reviews.any((r) => r.isVerifiedPurchase), isTrue);
      expect(reviews.first.comment.contains('broast') || reviews.first.comment.contains('crunchy'), isTrue);
    });

    test('Adding review updates state, average rating, and star distribution in real-time', () {
      final repo = ReviewRepository();
      final container = ProviderContainer(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(reviewControllerProvider(dummyProduct).notifier);
      final initialCount = container.read(reviewControllerProvider(dummyProduct)).totalCount;

      controller.submitReview(
        userName: 'Zain Malik',
        userCity: 'DHA Lahore',
        rating: 5.0,
        comment: 'Outstanding freshness and sizzling crunch! Best fast food in town.',
        variantName: '8 Pieces (Family)',
      );

      final state = container.read(reviewControllerProvider(dummyProduct));
      expect(state.totalCount, equals(initialCount + 1));
      expect(state.allReviews.first.userName, equals('Zain Malik'));
      expect(state.allReviews.first.userCity, equals('DHA Lahore'));
      expect(state.starDistribution[5], greaterThan(0.0));
    });

    test('Toggling helpful upvote increments and decrements count', () {
      final repo = ReviewRepository();
      final container = ProviderContainer(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(reviewControllerProvider(dummyProduct).notifier);
      final initialReview = container.read(reviewControllerProvider(dummyProduct)).allReviews.first;
      final initialHelpful = initialReview.helpfulCount;

      controller.toggleHelpful(initialReview.id);
      var updated = container.read(reviewControllerProvider(dummyProduct)).allReviews.first;
      expect(updated.isHelpfulByUser, isTrue);
      expect(updated.helpfulCount, equals(initialHelpful + 1));

      controller.toggleHelpful(initialReview.id);
      updated = container.read(reviewControllerProvider(dummyProduct)).allReviews.first;
      expect(updated.isHelpfulByUser, isFalse);
      expect(updated.helpfulCount, equals(initialHelpful));
    });

    test('Filter switching filters by star rating and verified status', () {
      final repo = ReviewRepository();
      final container = ProviderContainer(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(reviewControllerProvider(dummyProduct).notifier);

      controller.setFilter('5_star');
      expect(container.read(reviewControllerProvider(dummyProduct)).activeFilter, equals('5_star'));
      for (final r in container.read(reviewControllerProvider(dummyProduct)).filteredReviews) {
        expect(r.rating, greaterThanOrEqualTo(4.8));
      }

      controller.setFilter('verified');
      for (final r in container.read(reviewControllerProvider(dummyProduct)).filteredReviews) {
        expect(r.isVerifiedPurchase, isTrue);
      }
    });
  });

  group('ProductDetailsScreen Dynamic Quantity & Pricing Tests', () {
    testWidgets('Tapping quantity + dynamically updates live subtotal, savings, and button labels', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _TestMockAuthController()),
          ],
          child: const MaterialApp(
            home: ProductDetailsScreen(
              productId: 'test_broast_001',
              initialProduct: dummyProduct,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initial state: quantity 1, subtotal Rs. 1,399
      expect(find.text('Al-Baik Crispy Broast 8 Pcs'), findsOneWidget);
      expect(find.text('Subtotal: '), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);
      expect(find.text('Buy Now'), findsOneWidget);

      // Tap + button to increment quantity to 2
      final addButton = find.byIcon(Icons.add);
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Quantity should be 2, Subtotal Rs. 2,798 (1399 * 2)
      expect(find.widgetWithText(Container, '2'), findsWidgets);
      expect(find.text('Add to Cart (2) • Rs. 2,798'), findsOneWidget);
      expect(find.text('⚡ Buy Now • Rs. 2,798'), findsOneWidget);
      expect(find.textContaining('each × 2 items'), findsOneWidget);

      // Verify Reviews section is rendered
      expect(find.text('Ratings & Reviews'), findsOneWidget);
      expect(find.text('Write a Review'), findsOneWidget);
    });
  });

  group('CheckoutScreen Direct Buy & Itemized Breakdown Tests', () {
    testWidgets('Renders itemized details with picture, variant, unit price, quantity, and line total for Direct Buy', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final directItem = CartItemEntity(
        id: 'direct_item_99',
        product: dummyProduct,
        selectedVariant: dummyProduct.variants.first,
        quantity: 2,
        addedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _TestMockAuthController()),
          ],
          child: MaterialApp(
            home: CheckoutScreen(
              directItem: directItem,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check Order Items card
      expect(find.text('Order Items (2)'), findsOneWidget);
      expect(find.text('Direct Buy'), findsOneWidget);
      expect(find.text('Al-Baik Crispy Broast 8 Pcs'), findsOneWidget);
      expect(find.text('Option: 8 Pieces (Family)'), findsOneWidget);
      expect(find.text('Rs. 1,399 × 2'), findsOneWidget);
      expect(find.text('Rs. 2,798'), findsWidgets); // line total & items total

      // Check Delivery charges (Rs. 150) and Grand Total (Rs. 2,798 + 150 = Rs. 2,948)
      expect(find.text('Rs. 150'), findsOneWidget);
      expect(find.text('Rs. 2,948'), findsWidgets);
      expect(find.text('Confirm & Place Order (Rs. 2,948)'), findsOneWidget);
    });
  });
}