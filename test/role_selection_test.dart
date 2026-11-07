import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/core/theme/gradient_palette.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';
import 'package:groclyra/features/auth/presentation/widgets/role_selector_card.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';

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

  group('RoleSelectorCard Portal Role Selection Tests (Picture 2 UI)', () {
    testWidgets('Renders all 4 portal role cards matching Login Screen', (WidgetTester tester) async {
      UserRole selectedRole = UserRole.customer;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return RoleSelectorCard(
                  selectedRole: selectedRole,
                  palette: AppThemePalette.synthDusk,
                  isDark: true,
                  onRoleSelected: (r) => setState(() => selectedRole = r),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify 4 Portal Cards and their role descriptions
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Groceries & Crockery'), findsOneWidget);

      expect(find.text('Seller'), findsOneWidget);
      expect(find.text('Store & Catalog'), findsOneWidget);

      expect(find.text('Rider'), findsOneWidget);
      expect(find.text('Fulfillment & GPS'), findsOneWidget);

      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Control & Audit'), findsOneWidget);
    });

    testWidgets('Tapping Seller card selects UserRole.seller', (WidgetTester tester) async {
      UserRole selectedRole = UserRole.customer;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return RoleSelectorCard(
                  selectedRole: selectedRole,
                  palette: AppThemePalette.synthDusk,
                  isDark: true,
                  onRoleSelected: (r) => setState(() => selectedRole = r),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Seller'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(selectedRole, equals(UserRole.seller));
    });

    testWidgets('Tapping Admin card selects UserRole.admin', (WidgetTester tester) async {
      UserRole selectedRole = UserRole.customer;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return RoleSelectorCard(
                  selectedRole: selectedRole,
                  palette: AppThemePalette.synthDusk,
                  isDark: true,
                  onRoleSelected: (r) => setState(() => selectedRole = r),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Admin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(selectedRole, equals(UserRole.admin));
    });
  });
}