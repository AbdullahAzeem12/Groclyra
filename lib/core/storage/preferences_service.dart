import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/gradient_palette.dart';

class PreferencesService {
  static const String _keyThemePalette = 'groclyra_theme_palette';
  static const String _keyThemeMode = 'groclyra_theme_mode';
  static const String _keyFirstTime = 'groclyra_first_time';
  static const String _keySavedRole = 'groclyra_saved_role';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  /// NEW: shared underlying storage handle so additive cache services
  /// (e.g. LocalCacheService) reuse the same SharedPreferences instance
  /// created once at app boot instead of re-resolving it.
  SharedPreferences get sharedPreferences => _prefs;

  AppThemePalette getThemePalette() {
    final name = _prefs.getString(_keyThemePalette);
    if (name != null) {
      try {
        return AppThemePalette.values.firstWhere((p) => p.name == name);
      } catch (_) {
        return AppThemePalette.synthDusk;
      }
    }
    return AppThemePalette.synthDusk;
  }

  Future<void> setThemePalette(AppThemePalette palette) async {
    await _prefs.setString(_keyThemePalette, palette.name);
  }

  ThemeMode getThemeMode() {
    final modeStr = _prefs.getString(_keyThemeMode);
    switch (modeStr) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  bool isFirstTime() {
    return _prefs.getBool(_keyFirstTime) ?? true;
  }

  Future<void> setFirstTimeCompleted() async {
    await _prefs.setBool(_keyFirstTime, false);
  }

  String? getSavedRole() {
    return _prefs.getString(_keySavedRole);
  }

  Future<void> setSavedRole(String roleName) async {
    await _prefs.setString(_keySavedRole, roleName);
  }

  Future<void> clearSavedRole() async {
    await _prefs.remove(_keySavedRole);
  }
}

final preferencesServiceProvider = Provider<PreferencesService?>((ref) => null);
