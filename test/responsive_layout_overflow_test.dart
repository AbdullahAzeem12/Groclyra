import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/theme/gradient_palette.dart';
import 'package:groclyra/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:groclyra/features/auth/presentation/widgets/onboarding_3d_icon.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/shared/widgets/product_card_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testProductPicture4Case1 = ProductEntity(
    id: 'prod_crockery_1',
    title: 'Imperial Royal Bone China Dinner Set with Gold Trim',
    shortDescription: 'Bone China luxury 24-piece dinner set',
    description: 'Exquisite handcrafted Bone China dinner set with authentic 24k gold leaf lining.',
    categoryType: MainCategoryType.crockery,
    categoryName: 'Bone China',
    brand: 'Royal Albert',
    sellerId: 'seller_1',
    sellerName: 'Royal Crockery Mart',
    sellerRating: 4.9,
    basePrice: 18500.0,
    salePrice: 14999.0,
    discountPercentage: 19,
    rating: 4.9,
    reviewCount: 450,
    soldCount: 450,
    totalStock: 35,
    images: ['https://via.placeholder.com/300'],
    variants: [],
    material: 'Bone China',
    piecesCount: 24,
    isApproved: true,
    isFeatured: true,
    isFlashDeal: false,
  );

  const testProductPicture4Case2 = ProductEntity(
    id: 'prod_crockery_2',
    title: 'Nordic Matte Glaze Ceramic Dinner Set',
    shortDescription: 'Ceramic Stoneware rustic artisanal design',
    description: 'Ceramic dinnerware set with natural organic curves.',
    categoryType: MainCategoryType.crockery,
    categoryName: 'Ceramic Stone...',
    brand: 'Nordic Living',
    sellerId: 'seller_2',
    sellerName: 'Nordic Studio',
    sellerRating: 4.7,
    basePrice: 4200.0,
    salePrice: 3150.0,
    discountPercentage: 25,
    rating: 4.7,
    reviewCount: 310,
    soldCount: 310,
    totalStock: 50,
    images: ['https://via.placeholder.com/300'],
    variants: [],
    material: 'Ceramic',
    isApproved: true,
    isFeatured: false,
    isFlashDeal: false,
  );

  group('ProductCardItem Zero Overflow & Layout Stress Tests', () {
    testWidgets('Renders Picture 4 exact scenario (width: 105px) without RenderFlex overflow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 105,
                  height: 250,
                  child: ProductCardItem(product: testProductPicture4Case1),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(ProductCardItem), findsOneWidget);
    });

    testWidgets('Renders extreme narrow constraint (width: 95px) without overflow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 95,
                  height: 250,
                  child: ProductCardItem(product: testProductPicture4Case2),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(ProductCardItem), findsOneWidget);
    });

    testWidgets('Renders high-price, long-title, and large discount on standard grid cell (130px) cleanly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 130,
                  height: 270,
                  child: ProductCardItem(product: testProductPicture4Case1),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(ProductCardItem), findsOneWidget);
    });
  });

  group('Onboarding3DIcon Aesthetics & Responsive Tests', () {
    testWidgets('Renders Onboarding3DIcon Slide 0 (Exquisite Crockery) with 3D porcelain plate cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Onboarding3DIcon(
                pageIndex: 0,
                scrollOffset: 0.0,
                palette: AppThemePalette.synthDusk,
                isDark: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byType(Onboarding3DIcon), findsOneWidget);
    });

    testWidgets('Renders Onboarding3DIcon Slide 1 (Fresh Daily Grocery) with 3D shopping cart cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Onboarding3DIcon(
                pageIndex: 1,
                scrollOffset: 0.2,
                palette: AppThemePalette.sunsetCandy,
                isDark: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byType(Onboarding3DIcon), findsOneWidget);
    });

    testWidgets('Renders Onboarding3DIcon Slide 2 (4 Unified Portals) with 3D rocket & 4 orbital portal badges cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Onboarding3DIcon(
                pageIndex: 2,
                scrollOffset: -0.15,
                palette: AppThemePalette.cosmicPop,
                isDark: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byType(Onboarding3DIcon), findsOneWidget);
    });
  });

  group('OnboardingScreen Full Page Responsive & Zero Overflow Tests', () {
    testWidgets('Renders OnboardingScreen on narrow mobile (360x640) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Exquisite Crockery'), findsOneWidget);
      expect(find.text('GROCLYRA'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Swiping to next page updates page and renders zero overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Tap Continue to go to Page 1
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 2000));

      expect(tester.takeException(), isNull);
      expect(find.text('Fresh Daily Grocery'), findsOneWidget);

      // Tap Continue to go to Page 2
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 2000));

      expect(tester.takeException(), isNull);
      expect(find.text('4 Unified Portals, 1 App'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });
  });
}
