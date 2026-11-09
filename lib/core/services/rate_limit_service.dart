import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

/// Centralized Rate-Limiting and Abuse-Prevention Service.
///
/// Enforces client-side rate limits, cooldowns, and lockouts backed by
/// true SQLite persistent storage (`app_rate_limits` table) to prevent spam,
/// brute-force, SMS/Email bombing, and order flooding with zero external storage files.
class RateLimitService {
  final dynamic _legacyPrefs;
  final AppDatabase _db;
  final Map<String, int> _cache;
  static RateLimitService? _instance;

  RateLimitService([this._legacyPrefs, AppDatabase? db, Map<String, int>? cache])
      : _db = db ?? AppDatabase.instance,
        _cache = cache ?? <String, int>{} {
    _instance = this;
  }

  static RateLimitService get instance => _instance ?? RateLimitService();

  static Future<RateLimitService> create([AppDatabase? db]) async {
    final database = db ?? AppDatabase.instance;
    await database.init();
    final cache = <String, int>{};
    try {
      final rows = await database.query('app_rate_limits');
      for (final row in rows) {
        final key = row['key'] as String;
        final hitCount = row['hitCount'];
        if (hitCount is int) {
          cache[key] = hitCount;
        } else if (hitCount != null) {
          cache[key] = int.tryParse(hitCount.toString()) ?? 0;
        }
      }
    } catch (e) {
      debugPrint('[RateLimitService] Initial load note: $e');
    }
    final service = RateLimitService(null, database, cache);
    _instance = service;
    return service;
  }

  void setPreferences(dynamic prefs) {
    _instance = RateLimitService(prefs, _db, _cache);
  }

  // Internal storage helpers
  int? _getInt(String key) {
    if (_legacyPrefs != null) {
      try {
        final val = _legacyPrefs.getInt(key);
        if (val != null) return val as int;
      } catch (_) {}
    }
    return _cache[key];
  }

  Future<void> _setInt(String key, int val) async {
    _cache[key] = val;
    if (_legacyPrefs != null) {
      try {
        await _legacyPrefs.setInt(key, val);
      } catch (_) {}
    }
    try {
      await _db.insertOrReplace('app_rate_limits', {
        'key': key,
        'hitCount': val,
        'lastAttemptEpoch': DateTime.now().millisecondsSinceEpoch,
        'lockoutUntilEpoch': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      _db.notifyTable('app_rate_limits');
    } catch (e) {
      debugPrint('[RateLimitService] SQLite write note: $e');
    }
  }

  Future<void> _remove(String key) async {
    _cache.remove(key);
    if (_legacyPrefs != null) {
      try {
        await _legacyPrefs.remove(key);
      } catch (_) {}
    }
    try {
      await _db.delete('app_rate_limits', where: 'key = ?', whereArgs: [key]);
      _db.notifyTable('app_rate_limits');
    } catch (e) {
      debugPrint('[RateLimitService] SQLite remove note: $e');
    }
  }

  // Configuration Constants
  static const int maxFailedLogins = 5;
  static const Duration loginLockoutDuration = Duration(minutes: 15);

  static const Duration otpResendCooldown = Duration(seconds: 60);
  static const int maxOtpPerHour = 5;

  static const Duration passwordResetCooldown = Duration(seconds: 60);
  static const int maxPasswordResetsPerHour = 3;

  static const Duration emailVerificationCooldown = Duration(seconds: 60);

  static const Duration registrationCooldown = Duration(seconds: 30);
  static const int maxRegistrationsPerHour = 3;

  static const Duration orderPlacementCooldown = Duration(seconds: 15);

  // Storage Keys Prefixes
  static const String _prefixFailedLoginCount = 'rl_fail_login_cnt_';
  static const String _prefixLoginLockoutUntil = 'rl_login_lock_until_';
  static const String _prefixOtpLastSent = 'rl_otp_last_';
  static const String _prefixOtpCountWindow = 'rl_otp_cnt_';
  static const String _prefixPasswordResetLast = 'rl_pw_reset_last_';
  static const String _prefixPasswordResetCount = 'rl_pw_reset_cnt_';
  static const String _prefixEmailVerifyLast = 'rl_em_verify_last_';
  static const String _prefixRegistrationLast = 'rl_reg_last';
  static const String _prefixRegistrationCount = 'rl_reg_cnt';
  static const String _prefixOrderLast = 'rl_order_last_';

  // ───────────────────────────────────────────────────────────────────────────
  // 1. LOGIN ATTEMPT LIMITING & ACCOUNT LOCKOUT
  // ───────────────────────────────────────────────────────────────────────────

  String _cleanEmail(String email) => email.trim().toLowerCase();

  /// Checks if the account/email is currently locked out due to repeated failed logins.
  bool isLoginLockedOut(String email) {
    final key = '$_prefixLoginLockoutUntil${_cleanEmail(email)}';
    final lockoutMillis = _getInt(key);
    if (lockoutMillis == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < lockoutMillis) {
      return true;
    }
    // Lockout expired, clean up
    _remove(key);
    _remove('$_prefixFailedLoginCount${_cleanEmail(email)}');
    return false;
  }

  /// Returns remaining lockout time in seconds (0 if not locked out).
  int getRemainingLoginLockoutSeconds(String email) {
    final key = '$_prefixLoginLockoutUntil${_cleanEmail(email)}';
    final lockoutMillis = _getInt(key);
    if (lockoutMillis == null) return 0;

    final diffMs = lockoutMillis - DateTime.now().millisecondsSinceEpoch;
    return diffMs > 0 ? (diffMs / 1000).ceil() : 0;
  }

  /// Current number of consecutive failed login attempts for this email.
  int getFailedLoginCount(String email) {
    return _getInt('$_prefixFailedLoginCount${_cleanEmail(email)}') ?? 0;
  }

  /// Records a failed login attempt. Locks the account if threshold is reached.
  Future<int> recordFailedLogin(String email) async {
    final cleaned = _cleanEmail(email);
    final countKey = '$_prefixFailedLoginCount$cleaned';
    final currentCount = (_getInt(countKey) ?? 0) + 1;
    await _setInt(countKey, currentCount);

    if (currentCount >= maxFailedLogins) {
      final lockUntil = DateTime.now()
          .add(loginLockoutDuration)
          .millisecondsSinceEpoch;
      await _setInt('$_prefixLoginLockoutUntil$cleaned', lockUntil);
      debugPrint('RateLimitService: Account $cleaned locked out for 15 minutes.');
    }
    return currentCount;
  }

  /// Resets the failed login counter after a successful login.
  Future<void> resetFailedLogins(String email) async {
    final cleaned = _cleanEmail(email);
    await _remove('$_prefixFailedLoginCount$cleaned');
    await _remove('$_prefixLoginLockoutUntil$cleaned');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. PHONE OTP RATE LIMITING & COOLDOWN
  // ───────────────────────────────────────────────────────────────────────────

  String _cleanPhone(String phone) => phone.replaceAll(RegExp(r'\s+|-'), '');

  /// Returns remaining OTP cooldown in seconds (0 if cooldown has passed).
  int getRemainingOtpCooldownSeconds(String phone) {
    final key = '$_prefixOtpLastSent${_cleanPhone(phone)}';
    final lastSentMillis = _getInt(key);
    if (lastSentMillis == null) return 0;

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastSentMillis;
    final remainingMs = otpResendCooldown.inMilliseconds - elapsed;
    return remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;
  }

  /// Checks if a new OTP can be sent to this phone number.
  bool canSendOtp(String phone) {
    if (getRemainingOtpCooldownSeconds(phone) > 0) return false;

    final countKey = '$_prefixOtpCountWindow${_cleanPhone(phone)}';
    final count = _getInt(countKey) ?? 0;
    return count < maxOtpPerHour;
  }

  /// Records an OTP dispatch event.
  Future<void> recordOtpSent(String phone) async {
    final cleaned = _cleanPhone(phone);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _setInt('$_prefixOtpLastSent$cleaned', now);

    final countKey = '$_prefixOtpCountWindow$cleaned';
    final count = (_getInt(countKey) ?? 0) + 1;
    await _setInt(countKey, count);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. PASSWORD RESET RATE LIMITING & COOLDOWN
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns remaining password reset cooldown in seconds (0 if ready).
  int getRemainingPasswordResetCooldownSeconds(String email) {
    final key = '$_prefixPasswordResetLast${_cleanEmail(email)}';
    final lastSentMillis = _getInt(key);
    if (lastSentMillis == null) return 0;

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastSentMillis;
    final remainingMs = passwordResetCooldown.inMilliseconds - elapsed;
    return remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;
  }

  /// Checks if a password reset email can be sent to this email.
  bool canSendPasswordReset(String email) {
    if (getRemainingPasswordResetCooldownSeconds(email) > 0) return false;

    final countKey = '$_prefixPasswordResetCount${_cleanEmail(email)}';
    final count = _getInt(countKey) ?? 0;
    return count < maxPasswordResetsPerHour;
  }

  /// Records a password reset dispatch event.
  Future<void> recordPasswordResetSent(String email) async {
    final cleaned = _cleanEmail(email);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _setInt('$_prefixPasswordResetLast$cleaned', now);

    final countKey = '$_prefixPasswordResetCount$cleaned';
    final count = (_getInt(countKey) ?? 0) + 1;
    await _setInt(countKey, count);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. EMAIL VERIFICATION COOLDOWN
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns remaining email verification resend cooldown in seconds.
  int getRemainingEmailVerificationCooldownSeconds(String uidOrEmail) {
    final key = '$_prefixEmailVerifyLast$uidOrEmail';
    final lastSentMillis = _getInt(key);
    if (lastSentMillis == null) return 0;

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastSentMillis;
    final remainingMs = emailVerificationCooldown.inMilliseconds - elapsed;
    return remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;
  }

  /// Checks if an email verification can be dispatched.
  bool canResendEmailVerification(String uidOrEmail) {
    return getRemainingEmailVerificationCooldownSeconds(uidOrEmail) <= 0;
  }

  /// Records an email verification send event.
  Future<void> recordEmailVerificationSent(String uidOrEmail) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _setInt('$_prefixEmailVerifyLast$uidOrEmail', now);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. REGISTRATION RATE LIMITING
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns remaining registration cooldown in seconds.
  int getRemainingRegistrationCooldownSeconds() {
    final lastMillis = _getInt(_prefixRegistrationLast);
    if (lastMillis == null) return 0;

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastMillis;
    final remainingMs = registrationCooldown.inMilliseconds - elapsed;
    return remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;
  }

  /// Checks if a new user registration can proceed from this device.
  bool canRegister() {
    if (getRemainingRegistrationCooldownSeconds() > 0) return false;
    final count = _getInt(_prefixRegistrationCount) ?? 0;
    return count < maxRegistrationsPerHour;
  }

  /// Records a registration attempt.
  Future<void> recordRegistrationAttempt() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _setInt(_prefixRegistrationLast, now);

    final count = (_getInt(_prefixRegistrationCount) ?? 0) + 1;
    await _setInt(_prefixRegistrationCount, count);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. ORDER PLACEMENT FLOODING COOLDOWN
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns remaining cooldown before customer can place another order.
  int getRemainingOrderCooldownSeconds(String customerId) {
    final key = '$_prefixOrderLast$customerId';
    final lastMillis = _getInt(key);
    if (lastMillis == null) return 0;

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastMillis;
    final remainingMs = orderPlacementCooldown.inMilliseconds - elapsed;
    return remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;
  }

  /// Checks if an order can be placed by this customer.
  bool canPlaceOrder(String customerId) {
    return getRemainingOrderCooldownSeconds(customerId) <= 0;
  }

  /// Records an order placement event.
  Future<void> recordOrderPlaced(String customerId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _setInt('$_prefixOrderLast$customerId', now);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final rateLimitServiceProvider = Provider<RateLimitService>((ref) {
  return RateLimitService();
});
