import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';

void main() {
  group('AppToggleMessage 3D Floating Notification Tests', () {
    testWidgets('Renders success toggle message with title and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppToggleMessage.success(
                      context,
                      'Default delivery address set successfully',
                      title: 'Address Updated',
                    );
                  },
                  child: const Text('Show Success'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Address Updated'), findsOneWidget);
      expect(find.text('Default delivery address set successfully'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('Renders cart toggle message with action button and handles tap', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppToggleMessage.cart(
                      context,
                      title: 'Loaded Fries (POS)',
                      price: 'Rs. 450',
                      onAction: () => actionTapped = true,
                    );
                  },
                  child: const Text('Show Cart'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Cart'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Added to Cart'), findsOneWidget);
      expect(find.text('Loaded Fries (POS) • Rs. 450'), findsOneWidget);
      expect(find.text('VIEW CART'), findsOneWidget);

      await tester.tap(find.text('VIEW CART'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(actionTapped, isTrue);
    });

    testWidgets('Disappears automatically after duration and does not stick forever', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppToggleMessage.info(
                      context,
                      'Temporary hint message',
                      duration: const Duration(seconds: 1),
                    );
                  },
                  child: const Text('Show Info'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Info'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Temporary hint message'), findsOneWidget);

      // Advance past duration and wait for exit animation to complete
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Temporary hint message'), findsNothing);
    });

    testWidgets('New message immediately replaces previous message without queueing or freezing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => AppToggleMessage.info(context, 'First Message'),
                    child: const Text('First'),
                  ),
                  ElevatedButton(
                    onPressed: () => AppToggleMessage.warning(context, 'Second Message'),
                    child: const Text('Second'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('First'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('First Message'), findsOneWidget);

      // Tap second message immediately
      await tester.tap(find.text('Second'));
      await tester.pump();
      await tester.pumpAndSettle();

      // First message is dismissed, second is displayed
      expect(find.text('First Message'), findsNothing);
      expect(find.text('Second Message'), findsOneWidget);
    });
  });
}
