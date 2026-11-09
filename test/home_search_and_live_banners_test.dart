import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/shared/widgets/live_promo_banner_carousel.dart';
import 'package:groclyra/shared/widgets/live_deal_countdown_badge.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';

void main() {
  group('LiveDealCountdownBadge Real-Time Timer Tests', () {
    testWidgets('Renders countdown badge with ticking time without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiveDealCountdownBadge(
                customDuration: Duration(hours: 3, minutes: 45, seconds: 12),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ENDS IN 03:45:12'), findsOneWidget);
      expect(find.byType(LiveDealCountdownBadge), findsOneWidget);

      // Advance time by 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('ENDS IN 03:45:10'), findsOneWidget);
    });
  });

  group('LivePromoBannerCarousel Multi-Banner Real Ads & Offers Tests', () {
    testWidgets('Renders all promotional banner offerings with zero overflow', (tester) async {
      PromoBannerItem? tappedBanner;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: LivePromoBannerCarousel(
                  onBannerTap: (banner) => tappedBanner = banner,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check first banner rendered
      expect(find.text('Imperial Bone China & Crystal Dining'), findsOneWidget);
      expect(find.text('VERIFIED LUXURY'), findsOneWidget);

      // Tap first banner
      await tester.tap(find.text('Imperial Bone China & Crystal Dining'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tappedBanner, isNotNull);
      expect(tappedBanner!.targetPillar, MainCategoryType.crockery);
      expect(tappedBanner!.id, 'banner_crockery');
    });

    testWidgets('Renders on narrow mobile screen (320px) with ZERO RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: LivePromoBannerCarousel(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Swipe to next banner updates current page and displays Grocery Offer', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
                child: LivePromoBannerCarousel(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Drag page view to page 1
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Grocery Super Saver Pantry'), findsOneWidget);
      expect(find.text('SAME DAY DISPATCH'), findsOneWidget);
    });
  });
}
