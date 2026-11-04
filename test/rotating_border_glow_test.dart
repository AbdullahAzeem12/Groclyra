import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/shared/animations/rotating_border_glow_card.dart';

void main() {
  group('RotatingBorderGlowCard Exact Boundary Laser Tests', () {

    testWidgets('Renders child widget cleanly without layout or constraint errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _TestHost(
                isDark: true,
                borderRadius: 20.0,
                borderWidth: 1.3,
                child: Container(
                  width: 320,
                  height: 100,
                  color: const Color(0xFF131A29),
                  child: const Center(child: Text('Exact Boundary Target')),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Exact Boundary Target'), findsOneWidget);
      expect(find.byType(RotatingBorderGlowCard), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Animates smoothly across full 360-degree cycle without exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _TestHost(
                isDark: true,
                borderRadius: 14.0,
                borderWidth: 1.4,
                child: Container(
                  width: 160,
                  height: 130,
                  color: const Color(0xFF131A29),
                  child: const Text('Rotation Cycle Target'),
                ),
              ),
            ),
          ),
        ),
      );

      // Advance frames across the 3000ms animation duration
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Renders in light mode with adjusted alpha without exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: _TestHost(
                isDark: false,
                borderRadius: 20.0,
                borderWidth: 1.2,
                color: const Color(0xFF10B981),
                secondaryColor: const Color(0xFF06D6A0),
                child: Container(
                  width: 300,
                  height: 90,
                  color: Colors.white,
                  child: const Text('Light Mode Target'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Light Mode Target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Supports custom borderWidth parameter cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _TestHost(
                isDark: true,
                borderRadius: 16.0,
                borderWidth: 2.0,
                child: Container(
                  width: 250,
                  height: 80,
                  color: const Color(0xFF131A29),
                  child: const Text('Custom Width Target'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Custom Width Target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _TestHost extends StatefulWidget {
  final bool isDark;
  final double borderRadius;
  final double borderWidth;
  final Color color;
  final Color secondaryColor;
  final Widget child;

  const _TestHost({
    required this.isDark,
    required this.borderRadius,
    required this.borderWidth,
    this.color = const Color(0xFF8B5CF6),
    this.secondaryColor = const Color(0xFFA855F7),
    required this.child,
  });

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotatingBorderGlowCard(
      rotateController: _controller,
      color: widget.color,
      secondaryColor: widget.secondaryColor,
      phaseOffset: 0.25,
      isDark: widget.isDark,
      borderRadius: widget.borderRadius,
      borderWidth: widget.borderWidth,
      child: widget.child,
    );
  }
}
