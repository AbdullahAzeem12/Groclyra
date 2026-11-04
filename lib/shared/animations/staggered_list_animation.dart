import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StaggeredListAnimation extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggeredListAnimation({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: (40 * (index % 10)).ms)
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .slideY(begin: 0.12, end: 0, duration: 350.ms, curve: Curves.easeOutCubic);
  }
}
