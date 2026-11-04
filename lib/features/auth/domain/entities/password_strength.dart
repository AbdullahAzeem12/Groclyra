import 'package:flutter/material.dart';

enum PasswordStrengthLevel {
  empty('Enter password', Colors.grey, 0.0),
  weak('Weak', Color(0xFFEF4444), 0.25),
  fair('Fair', Color(0xFFF59E0B), 0.5),
  good('Good', Color(0xFF10B981), 0.75),
  strong('Strong', Color(0xFF059669), 1.0);

  final String label;
  final Color color;
  final double score;

  const PasswordStrengthLevel(this.label, this.color, this.score);
}

class PasswordStrength {
  final String password;
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;

  const PasswordStrength({
    required this.password,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  factory PasswordStrength.evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(
        password: '',
        hasMinLength: false,
        hasUppercase: false,
        hasLowercase: false,
        hasNumber: false,
        hasSpecialChar: false,
      );
    }

    final hasMinLength = password.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    return PasswordStrength(
      password: password,
      hasMinLength: hasMinLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasNumber: hasNumber,
      hasSpecialChar: hasSpecialChar,
    );
  }

  int get metCount {
    int count = 0;
    if (hasMinLength) count++;
    if (hasUppercase) count++;
    if (hasLowercase) count++;
    if (hasNumber) count++;
    if (hasSpecialChar) count++;
    return count;
  }

  PasswordStrengthLevel get level {
    if (password.isEmpty) return PasswordStrengthLevel.empty;
    if (metCount <= 2) return PasswordStrengthLevel.weak;
    if (metCount == 3) return PasswordStrengthLevel.fair;
    if (metCount == 4) return PasswordStrengthLevel.good;
    return PasswordStrengthLevel.strong;
  }

  bool get isValid => hasMinLength && hasLowercase && (hasUppercase || hasNumber);
}
