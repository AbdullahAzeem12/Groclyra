import 'dart:async';
import 'package:flutter/material.dart';

/// Real-time live ticking countdown timer for Flash Sales and Deals.
/// Automatically counts down second-by-second to midnight / flash window.
class LiveDealCountdownBadge extends StatefulWidget {
  final Duration? customDuration;
  final TextStyle? textStyle;

  const LiveDealCountdownBadge({
    super.key,
    this.customDuration,
    this.textStyle,
  });

  @override
  State<LiveDealCountdownBadge> createState() => _LiveDealCountdownBadgeState();
}

class _LiveDealCountdownBadgeState extends State<LiveDealCountdownBadge>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late Duration _remaining;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _remaining = widget.customDuration ?? _calculateRemainingTimeToMidnight();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining = _remaining - const Duration(seconds: 1);
        } else {
          _remaining = _calculateRemainingTimeToMidnight();
        }
      });
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Duration _calculateRemainingTimeToMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final diff = midnight.difference(now);
    return diff.isNegative ? const Duration(hours: 4, minutes: 18, seconds: 22) : diff;
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent,
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            'ENDS IN $hours:$minutes:$seconds',
            style: widget.textStyle ??
                const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                  letterSpacing: 0.4,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}

