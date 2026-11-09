import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/core/database/backup/database_backup_service.dart';
import 'package:groclyra/core/security/device_session_service.dart';
import 'package:groclyra/core/security/totp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AppDatabase.instance.init();
  });

  group('1. RFC 6238 TOTP Two-Factor Authentication Tests', () {
    test('Base32 encode and decode handles arbitrary bytes accurately', () {
      const text = 'Hello Groclyra 2026!';
      final bytes = utf8.encode(text);
      final encoded = Base32.encode(bytes);

      expect(encoded, isNotEmpty);
      expect(encoded, isNot(contains(' ')));

      final decoded = Base32.decode(encoded);
      expect(utf8.decode(decoded), equals(text));
    });

    test('TotpEngine generates valid 6-digit rolling codes and verifies with time window', () {
      const engine = TotpEngine(timeStepSeconds: 30, codeDigits: 6);
      final secret = TotpEngine.generateRandomSecret();

      final now = DateTime.now();
      final code = engine.generateTotp(secret, time: now);

      expect(code.length, equals(6));
      expect(int.tryParse(code), isNotNull);

      // Verify immediate code
      expect(engine.verifyTotp(secret, code, time: now), isTrue);

      // Verify code with 15s forward drift (still within 30s window)
      final slightDrift = now.add(const Duration(seconds: 15));
      expect(engine.verifyTotp(secret, code, time: slightDrift), isTrue);

      // Verify wrong code fails
      expect(engine.verifyTotp(secret, '999999', time: now), isFalse);
    });

    test('TwoFactorAuthService lifecycle: setup, activation, backup codes & redemption', () async {
      final service = TwoFactorAuthService();
      const testUserId = 'usr_test_totp_2026';
      const testEmail = 'totp_user@groclyra.pk';

      // 1. Initially disabled
      expect(await service.is2faEnabled(testUserId), isFalse);

      // 2. Initiate setup
      final setupData = await service.initiateSetup(
        userId: testUserId,
        userEmail: testEmail,
      );

      expect(setupData.secretKey, isNotEmpty);
      expect(setupData.formattedSecret, contains(' '));
      expect(setupData.otpAuthUri, contains('otpauth://totp/'));
      expect(setupData.temporaryBackupCodes.length, equals(8));

      // 3. Confirm activation with valid rolling code
      const engine = TotpEngine();
      final validCode = engine.generateTotp(setupData.secretKey);
      final activated = await service.confirmActivation(
        userId: testUserId,
        code: validCode,
      );
      expect(activated, isTrue);
      expect(await service.is2faEnabled(testUserId), isTrue);

      // 4. Verify login with valid rolling code
      final freshCode = engine.generateTotp(setupData.secretKey);
      expect(await service.verifyLoginCode(userId: testUserId, code: freshCode), isTrue);

      // 5. Verify login with single-use backup recovery code
      final backupCodes = await service.getRemainingBackupCodes(testUserId);
      expect(backupCodes.length, equals(8));
      final firstBackup = backupCodes.first;

      // Redeem backup code
      expect(await service.verifyLoginCode(userId: testUserId, code: firstBackup), isTrue);

      // Verify that used backup code was burned permanently
      final remainingCodes = await service.getRemainingBackupCodes(testUserId);
      expect(remainingCodes.length, equals(7));
      expect(remainingCodes.contains(firstBackup), isFalse);

      // 6. Disable 2FA
      await service.disable2fa(testUserId);
      expect(await service.is2faEnabled(testUserId), isFalse);
    });
  });

  group('2. Session Revocation & Multi-Device Management Tests', () {
    test('DeviceSessionService registers, lists, and revokes sessions', () async {
      final service = DeviceSessionService();
      const testUserId = 'usr_device_test_01';

      // 1. Register current device session
      await service.registerSession(testUserId);
      final sessions = await service.getUserSessions(testUserId);

      expect(sessions, isNotEmpty);
      expect(sessions.first.userId, equals(testUserId));
      expect(sessions.first.isCurrent, isTrue);

      // 2. Validate current session is active
      expect(await service.isCurrentSessionValid(testUserId), isTrue);

      // 3. Simulate a secondary device session (e.g. tablet)
      await AppDatabase.instance.insertOrReplace('user_sessions', {
        'id': 'sess_${testUserId}_secondary_tablet',
        'userId': testUserId,
        'deviceId': 'dev_secondary_ipad',
        'deviceName': 'Apple iPad Pro',
        'platform': 'ios',
        'ipAddress': '192.168.1.15 (Islamabad)',
        'lastActiveAt': DateTime.now().toIso8601String(),
        'isCurrent': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final multiSessions = await service.getUserSessions(testUserId);
      expect(multiSessions.length, equals(2));

      // 4. Revoke secondary session
      await service.revokeSession('sess_${testUserId}_secondary_tablet');
      final afterRevoke = await service.getUserSessions(testUserId);
      expect(afterRevoke.length, equals(1));
      expect(afterRevoke.first.isCurrent, isTrue);

      // 5. Revoke all other sessions helper
      await AppDatabase.instance.insertOrReplace('user_sessions', {
        'id': 'sess_${testUserId}_desktop',
        'userId': testUserId,
        'deviceId': 'dev_office_pc',
        'deviceName': 'Office Windows Workstation',
        'platform': 'windows',
        'ipAddress': '192.168.1.50 (Lahore)',
        'lastActiveAt': DateTime.now().toIso8601String(),
        'isCurrent': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });

      expect((await service.getUserSessions(testUserId)).length, equals(2));
      await service.revokeAllOtherSessions(testUserId);

      final finalSessions = await service.getUserSessions(testUserId);
      expect(finalSessions.length, equals(1));
      expect(finalSessions.first.isCurrent, isTrue);
    });
  });

  group('3. Encrypted Database Backup & Disaster Recovery Tests', () {
    test('DatabaseBackupService creates encrypted AES-256 snapshot and verifies checksum', () async {
      final service = DatabaseBackupService();

      // Ensure some test records exist in SQLite
      await AppDatabase.instance.insertOrReplace('users', {
        'id': 'usr_backup_test_01',
        'name': 'Backup Test User',
        'email': 'backup_test@groclyra.pk',
        'role': 'customer',
        'accountStatus': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // 1. Create encrypted backup snapshot
      final backup = await service.createEncryptedBackup(
        userPassphrase: 'SuperSecretCustomPassphrase2026!',
      );

      expect(backup.fileName, contains('groclyra_backup_'));
      expect(backup.fileName.endsWith('.gbackup'), isTrue);
      expect(backup.fileSizeBytes, greaterThan(0));
      expect(backup.checksum, isNotEmpty);
      expect(backup.isEncrypted, isTrue);

      // 2. Verify stored in SQLite backup registry
      final backupsList = await service.listBackups();
      expect(backupsList.any((b) => b.id == backup.id), isTrue);

      // 3. Restore from backup
      final restored = await service.restoreBackupFromFile(
        backup.filePath,
        userPassphrase: 'SuperSecretCustomPassphrase2026!',
      );
      expect(restored, isTrue);

      // 4. Verify user was preserved through restoration
      final userRows = await AppDatabase.instance.query(
        'users',
        where: 'id = ?',
        whereArgs: ['usr_backup_test_01'],
      );
      expect(userRows.isNotEmpty, isTrue);
      expect(userRows.first['email'], equals('backup_test@groclyra.pk'));

      // 5. Cleanup backup file and SQLite row
      await service.deleteBackup(backup);
      final afterDelete = await service.listBackups();
      expect(afterDelete.any((b) => b.id == backup.id), isFalse);
    });
  });
}

