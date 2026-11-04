import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/entities/password_strength.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;
  final bool isDark;

  const PasswordStrengthIndicator({
    super.key,
    required this.strength,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (strength.password.isEmpty) {
      return const SizedBox.shrink();
    }

    final level = strength.level;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.p8),

        // Progress bar + Strength label
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: level.score),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, child) {
                    return LinearProgressIndicator(
                      value: val,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(level.color),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.p12),
            Text(
              level.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: level.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.p8),

        // Criteria pills/checks
        Wrap(
          spacing: AppDimensions.p12,
          runSpacing: 4,
          children: [
            _buildCheckItem('8+ chars', strength.hasMinLength),
            _buildCheckItem('Uppercase', strength.hasUppercase),
            _buildCheckItem('Lowercase', strength.hasLowercase),
            _buildCheckItem('Number', strength.hasNumber),
            _buildCheckItem('Symbol', strength.hasSpecialChar),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckItem(String label, bool isMet) {
    const activeColor = Color(0xFF10B981);
    final inactiveColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      style: TextStyle(
        fontSize: 11,
        fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
        color: isMet ? activeColor : inactiveColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMet
                  ? activeColor.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            child: Icon(
              isMet ? Icons.check_rounded : Icons.circle_outlined,
              size: 10,
              color: isMet ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}
