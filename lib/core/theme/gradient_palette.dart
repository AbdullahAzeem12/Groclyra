import 'package:flutter/material.dart';

enum AppThemePalette {
  synthDusk('Synth Dusk', 'Vibrant Lifestyle & Modern Contrast', Color(0xFFFF1B6B), Color(0xFF45CAFF)),
  digitalSky('Digital Sky', 'Clean Tech & Confident Enterprise', Color(0xFF0061FF), Color(0xFF60EFFF)),
  sunsetCandy('Sunset Candy', 'Appetizing Warmth & High Energy', Color(0xFFFF0F7B), Color(0xFFF89B29)),
  cosmicPop('Cosmic Pop', 'Futuristic Luminous Dark Accents', Color(0xFF40C9FF), Color(0xFFE81CFF)),
  lavenderDream('Lavender Dream', 'Soft Luxury, Wellness & Fine Dining', Color(0xFF696EFF), Color(0xFFF8ACFF)),
  electricShore('Electric Shore', 'Fresh Fintech & Dynamic Edge', Color(0xFF595CFF), Color(0xFFC6F8FF)),
  emeraldMarket('Emerald Market', 'Fresh Groceries & Pure Organics', Color(0xFF059669), Color(0xFF34D399)),
  oceanGlass('Ocean Glass', 'Crockery Glaze & Pristine Crystal Glass', Color(0xFF0284C7), Color(0xFF22D3EE)),
  roseQuartz('Rose Quartz', 'Fine Bone China & Elegant Tableware', Color(0xFFE11D48), Color(0xFFFB7185)),
  midnightAurora('Midnight Aurora', 'Synth Dark & Glowing Northern Lights', Color(0xFF7C3AED), Color(0xFF10B981));

  final String title;
  final String subtitle;
  final Color startColor;
  final Color endColor;

  const AppThemePalette(this.title, this.subtitle, this.startColor, this.endColor);

  LinearGradient get linearGradient => LinearGradient(
        colors: [startColor, endColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get subtleGradient => LinearGradient(
        colors: [startColor.withValues(alpha: 0.15), endColor.withValues(alpha: 0.15)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  Color get primaryColor => startColor;
  Color get secondaryColor => endColor;
  Color get primary => startColor;
  Color get secondary => endColor;

  String get id {
    switch (this) {
      case AppThemePalette.synthDusk:
        return 'synth_dusk';
      case AppThemePalette.emeraldMarket:
        return 'emerald_market';
      case AppThemePalette.oceanGlass:
        return 'ocean_glass';
      case AppThemePalette.roseQuartz:
        return 'rose_quartz';
      case AppThemePalette.midnightAurora:
        return 'midnight_aurora';
      case AppThemePalette.digitalSky:
        return 'digital_sky';
      case AppThemePalette.sunsetCandy:
        return 'sunset_candy';
      case AppThemePalette.cosmicPop:
        return 'cosmic_pop';
      case AppThemePalette.lavenderDream:
        return 'lavender_dream';
      case AppThemePalette.electricShore:
        return 'electric_shore';
    }
  }

  String get name => title;
  List<Color> get primaryGradient => [startColor, endColor];
  Color get darkSurface => const Color(0xFF0E131F);
  Color get lightSurface => const Color(0xFFF8FAFC);
}

typedef GradientPalette = AppThemePalette;
