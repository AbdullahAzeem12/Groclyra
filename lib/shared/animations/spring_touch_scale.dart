import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive touch widget providing physical 3D press depth,
/// dynamic "jelly pop" elastic rebound, and optional smooth Material ripple effects.
///
/// [onTap] fires **after** the bounce-back animation peak so users see the full
/// spring before the route transition. [navigationDelayMs] controls that delay.
class SpringTouchScale extends StatefulWidget {
  final Widget child;

  /// Called after the bounce-back animation peak (default 160 ms after release).
  final VoidCallback? onTap;

  /// How far the widget scales down on press (e.g. 0.93).
  final double scaleFactor;

  /// Vertical translation depth in pixels during press (3-D push feel).
  final double pressDepth;

  /// Whether to show an InkWell ripple behind the pressed widget.
  final bool enableRipple;

  final Color? splashColor;
  final Color? highlightColor;
  final BorderRadius? borderRadius;
  final bool enableHaptic;

  /// Milliseconds to wait after release before calling [onTap].
  /// 160 ms lets the eye see the elastic peak before the route fires.
  final int navigationDelayMs;

  const SpringTouchScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
    this.pressDepth = 2.5,
    this.enableRipple = false,
    this.splashColor,
    this.highlightColor,
    this.borderRadius,
    this.enableHaptic = true,
    this.navigationDelayMs = 160,
  });

  @override
  State<SpringTouchScale> createState() => _SpringTouchScaleState();
}

class _SpringTouchScaleState extends State<SpringTouchScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isTapping = false;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // lowerBound < 0 lets elasticOut overshoot above 1.0 (jelly swell)
      duration: const Duration(milliseconds: 520),
      lowerBound: -0.5,
      upperBound: 1.5,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    if (widget.onTap == null) return;
    if (_isTapping) return;
    if (widget.enableHaptic) HapticFeedback.lightImpact();
    _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 55),
      curve: Curves.easeIn,
    );
  }

  void _handlePressUp() {
    if (widget.onTap == null) return;
    if (_isTapping) return;
    _isTapping = true;

    // Satisfying dual-tap: selection click on release
    if (widget.enableHaptic) HapticFeedback.selectionClick();

    // Elastic overshoot: value dips below 0 -> scale briefly > 1.0 (swell)
    _controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
    );

    // Navigate after the bounce peak is visible to the user
    _navTimer?.cancel();
    _navTimer = Timer(Duration(milliseconds: widget.navigationDelayMs), () {
      if (mounted) {
        _isTapping = false;
        widget.onTap!();
      }
    });
  }

  void _handlePressCancel() {
    _navTimer?.cancel();
    if (widget.onTap == null) return;
    _isTapping = false;
    _controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final animatedChild = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        // val == 1.0  -> scaleFactor (compressed)
        // val  < 0.0  -> overshoots above 1.0 (jelly swell on release)
        final scale = (1.0 - (val * (1.0 - widget.scaleFactor))).clamp(0.1, 1.5);
        final translateY = val * widget.pressDepth;

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: widget.child,
    );

    if (widget.enableRipple && widget.onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        clipBehavior:
            widget.borderRadius != null ? Clip.antiAlias : Clip.none,
        child: InkWell(
          onTapDown: (_) => _handlePressDown(),
          onTap: _handlePressUp,
          onTapCancel: _handlePressCancel,
          borderRadius: widget.borderRadius,
          splashColor: widget.splashColor ?? Colors.white.withValues(alpha: 0.12),
          highlightColor:
              widget.highlightColor ?? Colors.white.withValues(alpha: 0.06),
          child: animatedChild,
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => _handlePressDown(),
      onTapUp: (_) => _handlePressUp(),
      onTapCancel: _handlePressCancel,
      behavior: HitTestBehavior.opaque,
      child: animatedChild,
    );
  }
}
