import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/preferences_service.dart';
import 'gradient_palette.dart';

class ThemeState {
  final AppThemePalette palette;
  final ThemeMode mode;

  const ThemeState({
    required this.palette,
    required this.mode,
  });

  bool get isDark {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    try {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    } catch (_) {
      return false;
    }
  }

  bool isDarkMode(BuildContext context) {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return Theme.of(context).brightness == Brightness.dark;
  }

  ThemeMode get themeMode => mode;

  ThemeState copyWith({
    AppThemePalette? palette,
    ThemeMode? mode,
  }) {
    return ThemeState(
      palette: palette ?? this.palette,
      mode: mode ?? this.mode,
    );
  }
}

class ThemeController extends StateNotifier<ThemeState> {
  final PreferencesService? _prefs;

  ThemeController([this._prefs])
      : super(ThemeState(
          palette: _prefs?.getThemePalette() ?? AppThemePalette.synthDusk,
          mode: _prefs?.getThemeMode() ?? ThemeMode.system,
        )) {
    _listenToCloudTheme();
  }

  void _listenToCloudTheme() {
    // Theme preferences are persisted in SQLite app_preferences
  }

  Future<void> syncFromCloud(String uid) async {
    // Theme is loaded locally from persistent SharedPreferences
  }

  void setPalette(AppThemePalette palette) {
    state = state.copyWith(palette: palette);
    _prefs?.setThemePalette(palette);
    _syncToCloud();
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    _prefs?.setThemeMode(mode);
    _syncToCloud();
  }

  void toggleDarkMode(bool isDark) {
    final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(newMode);
  }

  Future<void> _syncToCloud() async {
    // Theme is synced locally to persistent SharedPreferences
  }
}

final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeState>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ThemeController(prefs);
});
