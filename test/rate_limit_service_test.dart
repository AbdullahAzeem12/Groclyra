import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/core/services/rate_limit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RateLimitService rateLimitService;

  setUp(() {
    rateLimitService = RateLimitService();
  });

  group('RateLimitService - Login Tests', () {
    const email = 'user@example.com';

    test('Initial state allows login with 0 failed attempts', () {
      expect(rateLimitService.isLoginLockedOut(email), isFalse);
      expect(rateLimitService.getRemainingLoginLockoutSeconds(email), 0);
      expect(rateLimitService.getFailedLoginCount(email), 0);
    });

    test('Locks out after 5 consecutive failed attempts', () async {
      for (int i = 1; i <= 4; i++) {
        final count = await rateLimitService.recordFailedLogin(email);
        expect(count, i);
        expect(rateLimitService.isLoginLockedOut(email), isFalse);
      }

      // 5th attempt triggers 15-minute lockout
      final finalCount = await rateLimitService.recordFailedLogin(email);
      expect(finalCount, 5);
      expect(rateLimitService.isLoginLockedOut(email), isTrue);

      final remainingSeconds = rateLimitService.getRemainingLoginLockoutSeconds(email);
      expect(remainingSeconds, greaterThanOrEqualTo(890));
      expect(remainingSeconds, lessThanOrEqualTo(900));
    });

    test('Resetting login attempts clears failed attempts and lockout', () async {
      for (int i = 0; i < 5; i++) {
        await rateLimitService.recordFailedLogin(email);
      }
      expect(rateLimitService.isLoginLockedOut(email), isTrue);

      await rateLimitService.resetFailedLogins(email);
      expect(rateLimitService.isLoginLockedOut(email), isFalse);
      expect(rateLimitService.getRemainingLoginLockoutSeconds(email), 0);
      expect(rateLimitService.getFailedLoginCount(email), 0);
    });
  });

  group('RateLimitService - Phone OTP Tests', () {
    const phone = '+923001234567';

    test('First OTP request is permitted', () {
      expect(rateLimitService.canSendOtp(phone), isTrue);
      expect(rateLimitService.getRemainingOtpCooldownSeconds(phone), 0);
    });

    test('Enforces 60-second cooldown after sending OTP', () async {
      await rateLimitService.recordOtpSent(phone);
      expect(rateLimitService.canSendOtp(phone), isFalse);

      final remainingSeconds = rateLimitService.getRemainingOtpCooldownSeconds(phone);
      expect(remainingSeconds, greaterThanOrEqualTo(58));
      expect(remainingSeconds, lessThanOrEqualTo(60));
    });

    test('Enforces maximum 5 OTPs per hour', () async {
      for (int i = 0; i < 5; i++) {
        await rateLimitService.recordOtpSent(phone);
      }
      expect(rateLimitService.canSendOtp(phone), isFalse);
    });
  });

  group('RateLimitService - Password Reset Tests', () {
    const email = 'reset@example.com';

    test('First reset request is permitted', () {
      expect(rateLimitService.canSendPasswordReset(email), isTrue);
      expect(rateLimitService.getRemainingPasswordResetCooldownSeconds(email), 0);
    });

    test('Enforces 60-second cooldown after sending reset email', () async {
      await rateLimitService.recordPasswordResetSent(email);
      expect(rateLimitService.canSendPasswordReset(email), isFalse);

      final remainingSeconds = rateLimitService.getRemainingPasswordResetCooldownSeconds(email);
      expect(remainingSeconds, greaterThanOrEqualTo(58));
      expect(remainingSeconds, lessThanOrEqualTo(60));
    });

    test('Enforces maximum 3 resets per hour', () async {
      for (int i = 0; i < 3; i++) {
        await rateLimitService.recordPasswordResetSent(email);
      }
      expect(rateLimitService.canSendPasswordReset(email), isFalse);
    });
  });

  group('RateLimitService - Email Verification Tests', () {
    const uid = 'cust_12345';

    test('Initial verification send is permitted', () {
      expect(rateLimitService.canResendEmailVerification(uid), isTrue);
      expect(rateLimitService.getRemainingEmailVerificationCooldownSeconds(uid), 0);
    });

    test('Enforces 60-second cooldown after sending verification email', () async {
      await rateLimitService.recordEmailVerificationSent(uid);
      expect(rateLimitService.canResendEmailVerification(uid), isFalse);

      final remainingSeconds = rateLimitService.getRemainingEmailVerificationCooldownSeconds(uid);
      expect(remainingSeconds, greaterThanOrEqualTo(58));
      expect(remainingSeconds, lessThanOrEqualTo(60));
    });
  });

  group('RateLimitService - Customer Order Cooldown Tests', () {
    const customerId = 'cust_order_test';

    test('First order placement is permitted', () {
      expect(rateLimitService.canPlaceOrder(customerId), isTrue);
      expect(rateLimitService.getRemainingOrderCooldownSeconds(customerId), 0);
    });

    test('Enforces 15-second cooldown against order rapid double-tap', () async {
      await rateLimitService.recordOrderPlaced(customerId);
      expect(rateLimitService.canPlaceOrder(customerId), isFalse);

      final remainingSeconds = rateLimitService.getRemainingOrderCooldownSeconds(customerId);
      expect(remainingSeconds, greaterThanOrEqualTo(13));
      expect(remainingSeconds, lessThanOrEqualTo(15));
    });
  });

  group('RateLimitService - Device Registration Tests', () {
    test('Initial registration attempt is permitted', () {
      expect(rateLimitService.canRegister(), isTrue);
      expect(rateLimitService.getRemainingRegistrationCooldownSeconds(), 0);
    });

    test('Enforces 30-second cooldown after registration', () async {
      await rateLimitService.recordRegistrationAttempt();
      expect(rateLimitService.canRegister(), isFalse);

      final remainingSeconds = rateLimitService.getRemainingRegistrationCooldownSeconds();
      expect(remainingSeconds, greaterThanOrEqualTo(28));
      expect(remainingSeconds, lessThanOrEqualTo(30));
    });

    test('Enforces maximum 3 registrations per hour', () async {
      for (int i = 0; i < 3; i++) {
        await rateLimitService.recordRegistrationAttempt();
      }
      expect(rateLimitService.canRegister(), isFalse);
    });
  });
}
