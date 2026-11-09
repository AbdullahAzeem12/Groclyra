import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/tables/database_tables.dart';

/// RFC 4648 Base32 implementation tailored for RFC 6238 TOTP authenticator compatibility.
class Base32 {
  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Encodes [bytes] into standard RFC 4648 Base32 string (uppercase, no padding)
  static String encode(List<int> bytes) {
    if (bytes.isEmpty) return '';
    final buffer = StringBuffer();
    int current = 0;
    int bitsRemaining = 0;

    for (final byte in bytes) {
      current = (current << 8) | (byte & 0xff);
      bitsRemaining += 8;
      while (bitsRemaining >= 5) {
        bitsRemaining -= 5;
        final index = (current >> bitsRemaining) & 0x1f;
        buffer.write(_alphabet[index]);
      }
    }

    if (bitsRemaining > 0) {
      final index = (current << (5 - bitsRemaining)) & 0x1f;
      buffer.write(_alphabet[index]);
    }

    return buffer.toString();
  }

  /// Decodes [input] RFC 4648 Base32 string back to byte array
  static Uint8List decode(String input) {
    final clean = input.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
    if (clean.isEmpty) return Uint8List(0);

    final out = <int>[];
    int current = 0;
    int bitsRemaining = 0;

    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      final val = _alphabet.indexOf(char);
      if (val < 0) continue; // Skip invalid characters

      current = (current << 5) | val;
      bitsRemaining += 5;

      if (bitsRemaining >= 8) {
        bitsRemaining -= 8;
        out.add((current >> bitsRemaining) & 0xff);
      }
    }

    return Uint8List.fromList(out);
  }
}

/// RFC 6238 Time-Based One-Time Password (TOTP) Algorithm Engine
/// Compatible with Google Authenticator, Microsoft Authenticator, 1Password, and Authy.
class TotpEngine {
  final int timeStepSeconds;
  final int codeDigits;

  const TotpEngine({
    this.timeStepSeconds = 30,
    this.codeDigits = 6,
  });

  /// Computes RFC 4226 HOTP for given [keyBytes] and [counter]
  String generateHotp(List<int> keyBytes, int counter) {
    // 8-byte big-endian counter representation
    final counterBytes = Uint8List(8);
    var temp = counter;
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = temp & 0xff;
      temp >>= 8;
    }

    // Compute HMAC-SHA1
    final hmac = Hmac(sha1, keyBytes);
    final digest = hmac.convert(counterBytes).bytes;

    // Dynamic Truncation (RFC 4226 Section 5.3)
    final offset = digest[digest.length - 1] & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);

    final modulus = math.pow(10, codeDigits).toInt();
    final otp = binary % modulus;
    return otp.toString().padLeft(codeDigits, '0');
  }

  /// Generates the current 6-digit TOTP code for a Base32 [secret]
  String generateTotp(String secret, {DateTime? time}) {
    final keyBytes = Base32.decode(secret);
    final effectiveTime = time ?? DateTime.now();
    final counter = (effectiveTime.millisecondsSinceEpoch ~/ 1000) ~/ timeStepSeconds;
    return generateHotp(keyBytes, counter);
  }

  /// Verifies [inputCode] against [secret] with [window] tolerance (± window * 30s)
  bool verifyTotp(
    String secret,
    String inputCode, {
    DateTime? time,
    int window = 1,
  }) {
    final cleanCode = inputCode.replaceAll(RegExp(r'\s+'), '');
    if (cleanCode.length != codeDigits) return false;

    final keyBytes = Base32.decode(secret);
    if (keyBytes.isEmpty) return false;

    final effectiveTime = time ?? DateTime.now();
    final currentCounter =
        (effectiveTime.millisecondsSinceEpoch ~/ 1000) ~/ timeStepSeconds;

    for (int i = -window; i <= window; i++) {
      final counter = currentCounter + i;
      final expectedCode = generateHotp(keyBytes, counter);
      if (expectedCode == cleanCode) {
        return true;
      }
    }
    return false;
  }

  /// Generates a high-entropy random Base32 secret string (20 bytes = 160 bits)
  static String generateRandomSecret({int byteLength = 20}) {
    final rng = math.Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => rng.nextInt(256));
    return Base32.encode(bytes);
  }

  /// Formats secret key into 4-character chunks for human readability (e.g. ABCD EFGH 1234)
  static String formatSecretForDisplay(String secret) {
    final clean = secret.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final chunks = <String>[];
    for (int i = 0; i < clean.length; i += 4) {
      final end = (i + 4 < clean.length) ? i + 4 : clean.length;
      chunks.add(clean.substring(i, end));
    }
    return chunks.join(' ');
  }

  /// Generates the standard `otpauth://` URI for Google/Microsoft Authenticator QR scanning
  static String generateOtpAuthUri({
    required String secret,
    required String accountName,
    String issuer = 'Groclyra',
    int digits = 6,
    int period = 30,
  }) {
    final cleanSecret = secret.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final encodedAccount = Uri.encodeComponent(accountName);
    final encodedIssuer = Uri.encodeComponent(issuer);
    return 'otpauth://totp/$encodedIssuer:$encodedAccount?secret=$cleanSecret&issuer=$encodedIssuer&algorithm=SHA1&digits=$digits&period=$period';
  }

  /// Generates [count] single-use cryptographic recovery backup codes (e.g. 4829-1942)
  static List<String> generateBackupCodes({int count = 8}) {
    final rng = math.Random.secure();
    const chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final codes = <String>[];
    for (int i = 0; i < count; i++) {
      final part1 = List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
      final part2 = List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
      codes.add('$part1-$part2');
    }
    return codes;
  }
}

/// Data class holding setup initialization payload for 2FA onboarding
class TwoFactorSetupData {
  final String secretKey;
  final String formattedSecret;
  final String otpAuthUri;
  final List<String> temporaryBackupCodes;

  const TwoFactorSetupData({
    required this.secretKey,
    required this.formattedSecret,
    required this.otpAuthUri,
    required this.temporaryBackupCodes,
  });
}

/// Production SQLite Two-Factor Authentication Service
/// Manages user 2FA lifecycle, backup codes, and session verification.
class TwoFactorAuthService {
  final AppDatabase _db;
  final TotpEngine _engine;

  TwoFactorAuthService({
    AppDatabase? db,
    TotpEngine? engine,
  })  : _db = db ?? AppDatabase.instance,
        _engine = engine ?? const TotpEngine();

  /// Initiates 2FA setup for [userId] by generating fresh secret, backup codes, and otpauth URI
  Future<TwoFactorSetupData> initiateSetup({
    required String userId,
    required String userEmail,
  }) async {
    final secret = TotpEngine.generateRandomSecret();
    final formatted = TotpEngine.formatSecretForDisplay(secret);
    final uri = TotpEngine.generateOtpAuthUri(
      secret: secret,
      accountName: userEmail,
    );
    final backupCodes = TotpEngine.generateBackupCodes();

    // Store in SQLite in disabled state until user confirms with a valid code
    final now = DateTime.now().toIso8601String();
    await _db.insertOrReplace(User2faTable.tableName, {
      User2faTable.colUserId: userId,
      User2faTable.colSecretKey: secret,
      User2faTable.colIsEnabled: 0,
      User2faTable.colBackupCodesJson: jsonEncode(backupCodes),
      User2faTable.colCreatedAt: now,
      User2faTable.colUpdatedAt: now,
    });

    return TwoFactorSetupData(
      secretKey: secret,
      formattedSecret: formatted,
      otpAuthUri: uri,
      temporaryBackupCodes: backupCodes,
    );
  }

  /// Confirms 2FA activation by verifying the user's first 6-digit TOTP code
  Future<bool> confirmActivation({
    required String userId,
    required String code,
  }) async {
    final record = await _getRecord(userId);
    if (record == null) return false;

    final secret = record[User2faTable.colSecretKey] as String? ?? '';
    if (secret.isEmpty) return false;

    final isValid = _engine.verifyTotp(secret, code);
    if (!isValid) return false;

    // Activate in SQLite
    final now = DateTime.now().toIso8601String();
    await _db.update(
      User2faTable.tableName,
      {
        User2faTable.colIsEnabled: 1,
        User2faTable.colUpdatedAt: now,
      },
      where: '${User2faTable.colUserId} = ?',
      whereArgs: [userId],
    );

    return true;
  }

  /// Verifies 6-digit TOTP code or single-use backup code during login
  Future<bool> verifyLoginCode({
    required String userId,
    required String code,
  }) async {
    final record = await _getRecord(userId);
    if (record == null) return true; // 2FA not configured

    final isEnabled = (record[User2faTable.colIsEnabled] as int? ?? 0) == 1;
    if (!isEnabled) return true; // 2FA configured but disabled

    final secret = record[User2faTable.colSecretKey] as String? ?? '';
    final cleanInput = code.trim().toUpperCase();

    // 1. Verify standard 6-digit TOTP code
    if (_engine.verifyTotp(secret, cleanInput)) {
      return true;
    }

    // 2. Fallback: Verify single-use backup code
    final rawBackup = record[User2faTable.colBackupCodesJson] as String?;
    if (rawBackup != null && rawBackup.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawBackup) as List<dynamic>;
        final backupCodes = list.cast<String>().toList();
        final matchedIndex = backupCodes.indexWhere(
          (c) => c.replaceAll('-', '') == cleanInput.replaceAll('-', ''),
        );

        if (matchedIndex >= 0) {
          // Burn the used backup code permanently
          backupCodes.removeAt(matchedIndex);
          final now = DateTime.now().toIso8601String();
          await _db.update(
            User2faTable.tableName,
            {
              User2faTable.colBackupCodesJson: jsonEncode(backupCodes),
              User2faTable.colUpdatedAt: now,
            },
            where: '${User2faTable.colUserId} = ?',
            whereArgs: [userId],
          );
          debugPrint('[2FA] Backup code successfully redeemed and burned for userId=$userId. Remaining: ${backupCodes.length}');
          return true;
        }
      } catch (e) {
        debugPrint('[2FA] Backup code parse note: $e');
      }
    }

    return false;
  }

  /// Checks if 2FA is currently enabled for [userId]
  Future<bool> is2faEnabled(String userId) async {
    final record = await _getRecord(userId);
    if (record == null) return false;
    return (record[User2faTable.colIsEnabled] as int? ?? 0) == 1;
  }

  /// Disables 2FA for [userId] in SQLite
  Future<void> disable2fa(String userId) async {
    final now = DateTime.now().toIso8601String();
    await _db.update(
      User2faTable.tableName,
      {
        User2faTable.colIsEnabled: 0,
        User2faTable.colUpdatedAt: now,
      },
      where: '${User2faTable.colUserId} = ?',
      whereArgs: [userId],
    );
  }

  /// Retrieves list of remaining backup codes
  Future<List<String>> getRemainingBackupCodes(String userId) async {
    final record = await _getRecord(userId);
    if (record == null) return [];
    final rawBackup = record[User2faTable.colBackupCodesJson] as String?;
    if (rawBackup == null || rawBackup.isEmpty) return [];
    try {
      final list = jsonDecode(rawBackup) as List<dynamic>;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Regenerates 8 fresh backup recovery codes
  Future<List<String>> regenerateBackupCodes(String userId) async {
    final newCodes = TotpEngine.generateBackupCodes();
    final now = DateTime.now().toIso8601String();
    await _db.update(
      User2faTable.tableName,
      {
        User2faTable.colBackupCodesJson: jsonEncode(newCodes),
        User2faTable.colUpdatedAt: now,
      },
      where: '${User2faTable.colUserId} = ?',
      whereArgs: [userId],
    );
    return newCodes;
  }

  Future<Map<String, dynamic>?> _getRecord(String userId) async {
    final rows = await _db.query(
      User2faTable.tableName,
      where: '${User2faTable.colUserId} = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }
}

final twoFactorAuthServiceProvider = Provider<TwoFactorAuthService>((ref) {
  return TwoFactorAuthService();
});
