import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../database/app_database.dart';

class BiometricCapability {
  final bool isSupported;
  final bool hasEnrolledBiometrics;
  final String? enrolledEmail;
  final String? enrolledRole;
  final List<BiometricType> availableTypes;

  const BiometricCapability({
    this.isSupported = false,
    this.hasEnrolledBiometrics = false,
    this.enrolledEmail,
    this.enrolledRole,
    this.availableTypes = const [],
  });

  bool get hasFingerprint =>
      availableTypes.contains(BiometricType.fingerprint) ||
      availableTypes.contains(BiometricType.strong);

  bool get hasFaceId => availableTypes.contains(BiometricType.face);
}

final biometricAuthProvider =
    StateNotifierProvider<BiometricAuthNotifier, BiometricCapability>((ref) {
  return BiometricAuthNotifier();
});

class BiometricAuthNotifier extends StateNotifier<BiometricCapability> {
  final LocalAuthentication _auth = LocalAuthentication();

  BiometricAuthNotifier() : super(const BiometricCapability()) {
    checkBiometricStatus();
  }

  Future<void> checkBiometricStatus() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final availableTypes = await _auth.getAvailableBiometrics();

      // Check if user has enrolled credentials in SQLite secure vault
      final vaultRows = await AppDatabase.instance.query(
        'app_secure_vault',
        where: 'key = ?',
        whereArgs: ['biometric_auth_credential'],
        limit: 1,
      );

      String? enrolledEmail;
      String? enrolledRole;
      bool hasEnrolled = false;

      if (vaultRows.isNotEmpty) {
        final val = vaultRows.first['value']?.toString();
        if (val != null && val.isNotEmpty) {
          try {
            final data = jsonDecode(val) as Map<String, dynamic>;
            enrolledEmail = data['email']?.toString();
            enrolledRole = data['role']?.toString();
            hasEnrolled = enrolledEmail != null && enrolledEmail.isNotEmpty;
          } catch (_) {}
        }
      }

      state = BiometricCapability(
        isSupported: isSupported && canCheck,
        hasEnrolledBiometrics: hasEnrolled,
        enrolledEmail: enrolledEmail,
        enrolledRole: enrolledRole,
        availableTypes: availableTypes,
      );
    } catch (e) {
      debugPrint('[BiometricAuth] Check status error: $e');
      state = const BiometricCapability(isSupported: false);
    }
  }

  /// Prompts the user for biometric authentication (Fingerprint / Face ID)
  Future<bool> authenticateWithBiometrics({
    String reason = 'Scan your fingerprint or face to sign in to Groclyra',
  }) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );

      if (authenticated) {
        HapticFeedback.mediumImpact();
      }
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('[BiometricAuth] PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('[BiometricAuth] Authentication error: $e');
      return false;
    }
  }

  /// Saves user biometric session into SQLite secure vault
  Future<void> saveBiometricSession({
    required String email,
    required String role,
    String? token,
  }) async {
    try {
      final payload = jsonEncode({
        'email': email,
        'role': role,
        'token': token ?? 'vault_token_${DateTime.now().millisecondsSinceEpoch}',
        'savedAt': DateTime.now().toIso8601String(),
      });

      await AppDatabase.instance.insertOrReplace('app_secure_vault', {
        'key': 'biometric_auth_credential',
        'value': payload,
        'iv': 'groclyra_iv_${DateTime.now().year}',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await checkBiometricStatus();
    } catch (e) {
      debugPrint('[BiometricAuth] Failed to save biometric session: $e');
    }
  }

  /// Clears enrolled biometric credentials
  Future<void> clearBiometricSession() async {
    try {
      await AppDatabase.instance.delete(
        'app_secure_vault',
        where: 'key = ?',
        whereArgs: ['biometric_auth_credential'],
      );
      await checkBiometricStatus();
    } catch (_) {}
  }
}
