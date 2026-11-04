import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          syncFromCloud(user.uid);
        }
      });
    } catch (_) {}
  }

  Future<void> syncFromCloud(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('theme')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final paletteName = data['palette'] as String?;
        final modeName = data['mode'] as String?;

        AppThemePalette? cloudPalette;
        if (paletteName != null) {
          try {
            cloudPalette = AppThemePalette.values.firstWhere((p) => p.name == paletteName);
          } catch (_) {}
        }

        ThemeMode? cloudMode;
        if (modeName != null) {
          switch (modeName) {
            case 'dark':
              cloudMode = ThemeMode.dark;
              break;
            case 'light':
              cloudMode = ThemeMode.light;
              break;
            case 'system':
              cloudMode = ThemeMode.system;
              break;
          }
        }

        if (cloudPalette != null || cloudMode != null) {
          state = state.copyWith(
            palette: cloudPalette ?? state.palette,
            mode: cloudMode ?? state.mode,
          );
          if (cloudPalette != null) _prefs?.setThemePalette(cloudPalette);
          if (cloudMode != null) _prefs?.setThemeMode(cloudMode);
        }
      }
    } catch (_) {
      // Offline or network error - local preference takes precedence safely
    }
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('theme')
            .set({
          'palette': state.palette.name,
          'mode': state.mode.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Silently tolerate if offline, permission denied, or Firebase uninitialized in test
    }
  }
}

final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeState>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ThemeController(prefs);
});
