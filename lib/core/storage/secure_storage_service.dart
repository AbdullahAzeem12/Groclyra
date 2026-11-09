import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

/// SQL-backed Secure Storage Service.
///
/// Completely replaces flutter_secure_storage with persistent SQLite ACID storage
/// in the `app_secure_vault` table, providing thread-safe token and credential management.
class SecureStorageService {
  final AppDatabase _db;

  SecureStorageService([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  static const String _keyToken = 'groclyra_auth_token';
  static const String _keyRefreshToken = 'groclyra_refresh_token';
  static const String _keyUserPayload = 'groclyra_user_payload';
  static const String _keySavedCredentialsMap = 'groclyra_saved_credentials_map';

  Future<void> _write(String key, String value) async {
    try {
      await _db.insertOrReplace('app_secure_vault', {
        'key': key,
        'value': value,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      _db.notifyTable('app_secure_vault');
    } catch (e) {
      debugPrint('[SecureStorageService] Write error for $key: $e');
    }
  }

  Future<String?> _read(String key) async {
    try {
      final rows = await _db.query(
        'app_secure_vault',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (e) {
      debugPrint('[SecureStorageService] Read error for $key: $e');
      return null;
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _db.delete(
        'app_secure_vault',
        where: 'key = ?',
        whereArgs: [key],
      );
      _db.notifyTable('app_secure_vault');
    } catch (e) {
      debugPrint('[SecureStorageService] Delete error for $key: $e');
    }
  }

  Future<void> saveTokens({required String token, required String refreshToken}) async {
    await _write(_keyToken, token);
    await _write(_keyRefreshToken, refreshToken);
  }

  Future<String?> getToken() async {
    return await _read(_keyToken);
  }

  Future<String?> getRefreshToken() async {
    return await _read(_keyRefreshToken);
  }

  Future<void> saveUserPayload(String jsonStr) async {
    await _write(_keyUserPayload, jsonStr);
  }

  Future<String?> getUserPayload() async {
    return await _read(_keyUserPayload);
  }

  Future<void> clearTokens() async {
    await _delete(_keyToken);
    await _delete(_keyRefreshToken);
  }

  Future<void> clearAll() async {
    await clearTokens();
    await _delete(_keyUserPayload);
  }

  Future<void> saveCredentials(String email, String password) async {
    final existingMap = await getSavedCredentialsMap();
    existingMap[email] = password;
    await _write(_keySavedCredentialsMap, jsonEncode(existingMap));
  }

  Future<Map<String, String>> getSavedCredentialsMap() async {
    final jsonStr = await _read(_keySavedCredentialsMap);
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Future<void> clearCredentials(String email) async {
    final existingMap = await getSavedCredentialsMap();
    if (existingMap.containsKey(email)) {
      existingMap.remove(email);
      await _write(_keySavedCredentialsMap, jsonEncode(existingMap));
    }
  }

  Future<void> clearAllCredentials() async {
    await _delete(_keySavedCredentialsMap);
  }
}
