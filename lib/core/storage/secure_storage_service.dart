import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  static const String _keyToken = 'groclyra_auth_token';
  static const String _keyRefreshToken = 'groclyra_refresh_token';
  static const String _keyUserPayload = 'groclyra_user_payload';
  static const String _keySavedCredentialsMap = 'groclyra_saved_credentials_map';

  Future<void> saveTokens({required String token, required String refreshToken}) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> saveUserPayload(String jsonStr) async {
    await _storage.write(key: _keyUserPayload, value: jsonStr);
  }

  Future<String?> getUserPayload() async {
    return await _storage.read(key: _keyUserPayload);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  Future<void> clearAll() async {
    await clearTokens();
    await _storage.delete(key: _keyUserPayload);
  }

  Future<void> saveCredentials(String email, String password) async {
    final existingMap = await getSavedCredentialsMap();
    existingMap[email] = password;
    await _storage.write(key: _keySavedCredentialsMap, value: jsonEncode(existingMap));
  }

  Future<Map<String, String>> getSavedCredentialsMap() async {
    final jsonStr = await _storage.read(key: _keySavedCredentialsMap);
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
      await _storage.write(key: _keySavedCredentialsMap, value: jsonEncode(existingMap));
    }
  }

  Future<void> clearAllCredentials() async {
    await _storage.delete(key: _keySavedCredentialsMap);
  }
}

