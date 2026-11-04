import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/routing/app_router.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';
import 'package:groclyra/features/auth/domain/entities/account_status.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/catalog/data/mock_catalog_data.dart';

class _MockAuthController extends StateNotifier<AuthState> implements AuthController {
  _MockAuthController()
      : super(
          AuthState(
            user: UserEntity(
              id: 'test_customer_id',
              name: 'Customer Test',
              email: 'customer@groclyra.pk',
              phone: '03001234567',
              role: UserRole.customer,
              accountStatus: AccountStatus.active,
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Pushing customerProductDetails does not throw duplicated page keys assertion', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testProduct = MockCatalogData.getProducts().first;
    final mockAuth = _MockAuthController();

    late GoRouter testRouter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => mockAuth),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            testRouter = ref.watch(appRouterProvider);
            return MaterialApp.router(
              routerConfig: testRouter,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));

    // Navigate to customer home
    testRouter.go(RouteNames.customerHome);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now push product details
    testRouter.push('${RouteNames.customerProductDetails}/${testProduct.id}', extra: testProduct);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify product details screen rendered without assertion
    expect(find.text(testProduct.title), findsWidgets);

    // Pop back to home
    testRouter.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Push second product to verify consecutive push navigation
    final secondProduct = MockCatalogData.getProducts()[1];
    testRouter.push('${RouteNames.customerProductDetails}/${secondProduct.id}', extra: secondProduct);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text(secondProduct.title), findsWidgets);

    // Navigate to Cart via go (as triggered by VIEW CART)
    testRouter.go(RouteNames.customerCart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Shopping Cart'), findsOneWidget);
  });
}
