import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/auth/domain/entities/account_status.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';

class _MockAuthController extends StateNotifier<AuthState> implements AuthController {
  UserRole? selectedRoleTracked;

  _MockAuthController()
      : super(
          AuthState(
            user: UserEntity(
              id: 'test_user_1',
              name: 'Test User',
              email: 'test@groclyra.pk',
              phone: '03001234567',
              role: UserRole.customer,
              accountStatus: AccountStatus.active,
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        );

  @override
  void selectRole(UserRole role) {
    selectedRoleTracked = role;
    state = state.copyWith(selectedRole: role);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SpringTouchScale Jelly Pop & 3D Touch Tests', () {
    testWidgets('SpringTouchScale renders child and responds to tap gesture cleanly', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SpringTouchScale(
                onTap: () => tapped = true,
                scaleFactor: 0.94,
                pressDepth: 3.0,
                enableRipple: true,
                splashColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                child: const Text('Jelly Pop Button'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Jelly Pop Button'), findsOneWidget);

      // Tap the widget to trigger press down and tap up with jelly bounce
      await tester.tap(find.text('Jelly Pop Button'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('SpringTouchScale handles tap cancellation with smooth rebound', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SpringTouchScale(
                onTap: () {},
                scaleFactor: 0.95,
                pressDepth: 2.5,
                child: const Text('Cancel Test Target'),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Cancel Test Target')));
      await tester.pump(const Duration(milliseconds: 50));
      // Cancel gesture
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('RoleSelectionScreen 3D Color Management & Portal Cards Tests', () {
    testWidgets('Renders all 4 portal cards with distinct role badges matching Picture 1 color management',
        (WidgetTester tester) async {
      final mockAuth = _MockAuthController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => mockAuth),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const RoleSelectionScreen(),
          ),
        ),
      );

      // Settle entrance animations with discrete duration because FloatingBackground has infinite ambient repeat
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Verify Brand Header
      expect(find.text('GL'), findsOneWidget);
      expect(find.text('Unified Marketplace'), findsOneWidget);
      expect(find.text('Welcome to Groclyra'), findsOneWidget);
      expect(find.text('Select your portal to continue into the unified marketplace:'), findsOneWidget);

      // Verify 4 Portal Cards and their role badges
      expect(find.text('Customer Portal'), findsOneWidget);
      expect(find.text('B2C & Grocery'), findsOneWidget);

      expect(find.text('Seller Center'), findsOneWidget);
      expect(find.text('Store & Catalog'), findsOneWidget);

      expect(find.text('Express Rider Hub'), findsOneWidget);
      expect(find.text('Fulfillment & GPS'), findsOneWidget);

      expect(find.text('Admin Console'), findsOneWidget);
      expect(find.text('Control & Audit'), findsOneWidget);

      // Verify Bottom Navigation Actions
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('Tapping Customer Portal selects UserRole.customer', (WidgetTester tester) async {
      final mockAuth = _MockAuthController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => mockAuth),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const RoleSelectionScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      await tester.tap(find.text('Customer Portal'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(mockAuth.selectedRoleTracked, equals(UserRole.customer));
    });

    testWidgets('Tapping Admin Console selects UserRole.admin', (WidgetTester tester) async {
      final mockAuth = _MockAuthController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => mockAuth),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const RoleSelectionScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      await tester.ensureVisible(find.text('Admin Console'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Admin Console'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(mockAuth.selectedRoleTracked, equals(UserRole.admin));
    });
  });
}