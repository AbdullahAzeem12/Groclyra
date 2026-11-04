import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/gradient_palette.dart';

class FloatingBackground extends StatefulWidget {
  final AppThemePalette palette;
  final bool isDark;

  const FloatingBackground({
    super.key,
    required this.palette,
    required this.isDark,
  });

  @override
  State<FloatingBackground> createState() => _FloatingBackgroundState();
}

class _FloatingBackgroundState extends State<FloatingBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final primary = widget.palette.startColor;
    final secondary = widget.palette.endColor;
    final opacity = widget.isDark ? 0.12 : 0.07;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx1 = math.sin(t * 2 * math.pi) * 35;
        final dy1 = math.cos(t * 2 * math.pi) * 30;
        final dx2 = -math.cos(t * 2 * math.pi) * 40;
        final dy2 = math.sin(t * 2 * math.pi) * 35;

        return Stack(
          children: [
            // Top right glowing orb
            Positioned(
              top: -80 + dy1,
              right: -60 + dx1,
              child: Container(
                width: size.width * 0.75,
                height: size.width * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: opacity * 1.5),
                      primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Middle-left accent orb
            Positioned(
              top: size.height * 0.35 + dy2,
              left: -80 + dx2,
              child: Container(
                width: size.width * 0.65,
                height: size.width * 0.65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      secondary.withValues(alpha: opacity * 1.3),
                      secondary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom floating accent
            Positioned(
              bottom: -100 - dy1,
              right: size.width * 0.15 + dx1,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: opacity),
                      primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
