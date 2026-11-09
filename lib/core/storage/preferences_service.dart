import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../theme/gradient_palette.dart';

/// SQL-backed Application Preferences Service.
///
/// Completely replaces legacy SharedPreferences XML files with true SQLite storage
/// in the `app_preferences` table, featuring in-memory instant reads and reactive table
/// change notifications.
class PreferencesService {
  static const String _keyThemePalette = 'groclyra_theme_palette';
  static const String _keyThemeMode = 'groclyra_theme_mode';
  static const String _keyFirstTime = 'groclyra_first_time';
  static const String _keySavedRole = 'groclyra_saved_role';

  final AppDatabase _db;
  final Map<String, dynamic> _memoryCache;

  PreferencesService._(this._db, this._memoryCache);

  /// Backwards-compatible constructor
  PreferencesService([dynamic legacyPrefs, AppDatabase? db])
      : _db = db ?? AppDatabase.instance,
        _memoryCache = {};

  /// Asynchronously loads all preferences from SQLite into fast in-memory cache
  static Future<PreferencesService> create([AppDatabase? db]) async {
    final database = db ?? AppDatabase.instance;
    await database.init();
    final cache = <String, dynamic>{};
    try {
      final rows = await database.query('app_preferences');
      for (final row in rows) {
        final key = row['key'] as String;
        final val = row['value'] as String;
        final type = row['type'] as String? ?? 'string';
        if (type == 'bool') {
          cache[key] = val == 'true' || val == '1';
        } else if (type == 'int') {
          cache[key] = int.tryParse(val) ?? 0;
        } else if (type == 'double') {
          cache[key] = double.tryParse(val) ?? 0.0;
        } else {
          cache[key] = val;
        }
      }
    } catch (e) {
      debugPrint('[PreferencesService] SQL load note: $e');
    }
    return PreferencesService._(database, cache);
  }

  /// Legacy accessor kept for signature backwards-compatibility (returns null or self)
  dynamic get sharedPreferences => null;

  AppThemePalette getThemePalette() {
    final name = _memoryCache[_keyThemePalette] as String?;
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
    _memoryCache[_keyThemePalette] = palette.name;
    await _db.insertOrReplace('app_preferences', {
      'key': _keyThemePalette,
      'value': palette.name,
      'type': 'string',
      'updatedAt': DateTime.now().toIso8601String(),
    });
    _db.notifyTable('app_preferences');
  }

  ThemeMode getThemeMode() {
    final modeStr = _memoryCache[_keyThemeMode] as String?;
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
    _memoryCache[_keyThemeMode] = mode.name;
    await _db.insertOrReplace('app_preferences', {
      'key': _keyThemeMode,
      'value': mode.name,
      'type': 'string',
      'updatedAt': DateTime.now().toIso8601String(),
    });
    _db.notifyTable('app_preferences');
  }

  bool isFirstTime() {
    final val = _memoryCache[_keyFirstTime];
    if (val is bool) return val;
    return true;
  }

  Future<void> setFirstTimeCompleted() async {
    _memoryCache[_keyFirstTime] = false;
    await _db.insertOrReplace('app_preferences', {
      'key': _keyFirstTime,
      'value': 'false',
      'type': 'bool',
      'updatedAt': DateTime.now().toIso8601String(),
    });
    _db.notifyTable('app_preferences');
  }

  String? getSavedRole() {
    return _memoryCache[_keySavedRole] as String?;
  }

  Future<void> setSavedRole(String roleName) async {
    _memoryCache[_keySavedRole] = roleName;
    await _db.insertOrReplace('app_preferences', {
      'key': _keySavedRole,
      'value': roleName,
      'type': 'string',
      'updatedAt': DateTime.now().toIso8601String(),
    });
    _db.notifyTable('app_preferences');
  }

  Future<void> clearSavedRole() async {
    _memoryCache.remove(_keySavedRole);
    await _db.delete('app_preferences', where: 'key = ?', whereArgs: [_keySavedRole]);
    _db.notifyTable('app_preferences');
  }
}

final preferencesServiceProvider = Provider<PreferencesService?>((ref) => null);
