import 'dart:math' as math;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// RotatingBorderGlowCard  -  wraps child in a CustomPaint that draws a
// sleek, high-precision laser beam rotating strictly along the exact card border.
// ═══════════════════════════════════════════════════════════════════════════════

class RotatingBorderGlowCard extends StatelessWidget {
  final AnimationController rotateController;
  final Color color;
  final Color secondaryColor;
  final double phaseOffset; // 0..1
  final bool isDark;
  final double borderRadius;
  final double borderWidth;
  final Widget child;

  const RotatingBorderGlowCard({
    super.key,
    required this.rotateController,
    required this.color,
    required this.secondaryColor,
    required this.phaseOffset,
    required this.isDark,
    required this.borderRadius,
    this.borderWidth = 1.3,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: rotateController,
      builder: (context, innerChild) {
        final progress = (rotateController.value + phaseOffset) % 1.0;
        return CustomPaint(
          foregroundPainter: _BorderGlowPainter(
            progress: progress,
            color: color,
            secondaryColor: secondaryColor,
            borderRadius: borderRadius,
            borderWidth: borderWidth,
            isDark: isDark,
          ),
          child: innerChild,
        );
      },
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BorderGlowPainter
// Uses PathMetrics to trace a razor-sharp, exact-boundary laser beam with a
// smooth gradient tail and diamond specular head along the rounded-rect border.
// ─────────────────────────────────────────────────────────────────────────────

class _BorderGlowPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color secondaryColor;
  final double borderRadius;
  final double borderWidth;
  final bool isDark;

  static const int _segments = 28;
  static const double _beamFraction = 0.22;

  _BorderGlowPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.borderRadius,
    required this.borderWidth,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    // Deflate by half border width so the stroke is centered precisely on the card boundary
    final strokeRRect = rrect.deflate(borderWidth / 2);
    final metrics = (Path()..addRRect(strokeRRect)).computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    if (total <= 0) return;

    canvas.save();

    // ── Strict boundary clip ────────────────────────────────────────────────
    // Strictly restrict all drawing to an exact tight perimeter ribbon.
    // At most 1.5px outside and 2.5px inside the card edge.
    // This physically prevents any glow, shadow, or blur from spilling
    // into adjacent cards or outside boundaries.
    final outerClip = rrect.inflate(1.5);
    final innerClip = rrect.deflate(2.5);
    canvas.clipPath(
      Path()
        ..addRRect(outerClip)
        ..addRRect(innerClip)
        ..fillType = PathFillType.evenOdd,
    );

    // ── Ambient crisp base border (thin, crisp, no thick blur) ─────────────
    canvas.drawRRect(
      strokeRRect,
      Paint()
        ..color = color.withValues(alpha: isDark ? 0.26 : 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    // ── Rotating laser beam along exact perimeter ──────────────────────────
    final beamLength = total * _beamFraction;
    final stepDist = beamLength / _segments;
    final headPos = (progress * total) % total;
    final tailPos = headPos - beamLength;

    // 1. Delicate sheen hugging the beam path
    final glowStart = ((headPos - beamLength * 0.75) % total + total) % total;
    Path glowPath;
    if (glowStart < headPos) {
      glowPath = metric.extractPath(glowStart, headPos);
    } else {
      glowPath = metric.extractPath(glowStart, total)
        ..addPath(metric.extractPath(0, headPos), Offset.zero);
    }
    canvas.drawPath(
      glowPath,
      Paint()
        ..color = color.withValues(alpha: isDark ? 0.32 : 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );

    // 2. Micro-segmented core beam with smooth quadratic fade & specular highlight
    for (int i = 0; i < _segments; i++) {
      final t = (i + 1) / _segments; // 0..1 from tail to head
      final d0 = ((tailPos + i * stepDist) % total + total) % total;
      final d1 = ((tailPos + (i + 1) * stepDist) % total + total) % total;

      Path subPath;
      if (d0 < d1) {
        subPath = metric.extractPath(d0, d1);
      } else {
        subPath = metric.extractPath(d0, total)
          ..addPath(metric.extractPath(0, d1), Offset.zero);
      }

      // Smooth exponential easing for natural light falloff
      final alphaFactor = math.pow(t, 2.0).toDouble();

      // Color progression: secondary -> primary color -> bright white specular head
      Color segColor;
      if (t < 0.65) {
        segColor = Color.lerp(secondaryColor, color, t / 0.65)!;
      } else {
        final whiteMix = ((t - 0.65) / 0.35 * 0.88).clamp(0.0, 1.0);
        segColor = Color.lerp(color, Colors.white, whiteMix)!;
      }

      final segStrokeWidth = borderWidth * (0.85 + t * 0.45);

      canvas.drawPath(
        subPath,
        Paint()
          ..color = segColor.withValues(alpha: alphaFactor * (isDark ? 0.95 : 0.85))
          ..style = PaintingStyle.stroke
          ..strokeWidth = segStrokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Leading hot-spot (crisp specular pinpoint) ──────────────────────────
    final headTang = metric.getTangentForOffset(headPos);
    if (headTang != null) {
      final head = headTang.position;

      // Tight micro-halo around the head
      canvas.drawCircle(
        head,
        3.0,
        Paint()
          ..color = color.withValues(alpha: isDark ? 0.45 : 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );

      // Diamond specular white core point
      canvas.drawCircle(
        head,
        1.6,
        Paint()
          ..color = Colors.white.withValues(alpha: isDark ? 0.98 : 0.90)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BorderGlowPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.secondaryColor != secondaryColor ||
      old.borderWidth != borderWidth ||
      old.isDark != isDark ||
      old.borderRadius != borderRadius;
}
