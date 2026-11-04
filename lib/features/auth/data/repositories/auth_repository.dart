import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/services/rate_limit_service.dart';
import '../../../../core/utils/validator_utils.dart';
import '../../../../firebase_options.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/rider_location.dart';
import '../auth_error_mapper.dart';
import 'firestore_user_repository.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirestoreUserRepository _firestoreRepo;
  final SecureStorageService _secureStorage;
  final PreferencesService? _prefs;
  final RateLimitService _rateLimitService;

  // Configurable owner admin override (debug builds only, never hardcoded in plaintext)
  static const String _ownerAdminEmail =
      String.fromEnvironment('OWNER_ADMIN_EMAIL', defaultValue: '');
  static const String _ownerAdminPhone =
      String.fromEnvironment('OWNER_ADMIN_PHONE', defaultValue: '');

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    required FirestoreUserRepository firestoreRepo,
    required SecureStorageService secureStorage,
    PreferencesService? prefs,
    RateLimitService? rateLimitService,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestoreRepo = firestoreRepo,
        _secureStorage = secureStorage,
        _prefs = prefs,
        _rateLimitService = rateLimitService ?? RateLimitService.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Restores user session from Firebase and local cache
  Future<UserEntity?> restoreSession() async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        // Try fetching fresh data from Firestore
        final firestoreUser = await _firestoreRepo.getUser(firebaseUser.uid);
        if (firestoreUser != null) {
          await _persistUserLocally(firestoreUser);
          return firestoreUser;
        }
      }

      // Fallback to local secure storage
      final payload = await _secureStorage.getUserPayload();
      if (payload != null) {
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          return UserEntity.fromJson(map);
        } catch (_) {
          return null;
        }
      }
    } catch (e) {
      debugPrint('Session restore error: $e');
    }
    return null;
  }

  /// Real Firebase login with role verification, rate limiting, and account status checks
  Future<AuthResult> login({
    required String emailOrPhone,
    required String password,
    required UserRole role,
  }) async {
    try {
      final cleanEmail = emailOrPhone.trim();
      if (!cleanEmail.contains('@')) {
        return AuthResult.failure(
          'Please enter a valid email address.',
          errorCode: 'invalid-email',
        );
      }

      // Rate limit check: Prevent brute-force / credential stuffing
      if (_rateLimitService.isLoginLockedOut(cleanEmail)) {
        final remainingSec =
            _rateLimitService.getRemainingLoginLockoutSeconds(cleanEmail);
        final remainingMin = (remainingSec / 60).ceil();
        return AuthResult.failure(
          'Too many failed login attempts. For your security, this account is temporarily locked. Please try again in $remainingMin minute${remainingMin > 1 ? 's' : ''}.',
          errorCode: 'account-locked',
        );
      }

      // 1. Authenticate with Firebase Auth
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return AuthResult.failure('Authentication failed. No user returned.');
      }

      // 2. Fetch User Profile from Firestore to verify role
      UserEntity? userEntity = await _firestoreRepo.getUser(firebaseUser.uid);

      if (userEntity == null) {
        // Cross-segment lookup to verify if the account is registered under a different role
        final actualRole = await _firestoreRepo.findUserRoleAcrossSegments(firebaseUser.uid);
        await _firebaseAuth.signOut();
        await _secureStorage.clearTokens();

        if (actualRole != null && actualRole != role) {
          return AuthResult.roleMismatch(
            expectedRole: role,
            actualRole: actualRole,
          );
        }

        return AuthResult.failure(
          'No ${role.displayName} profile found for this account. Please register first or check your portal selection.',
          errorCode: 'user-not-found',
        );
      }

      // 3. STRICT ROLE ISOLATION: Disallow logging into a different role portal
      final existsInSegment = await _firestoreRepo.verifyUserInRoleSegment(
        uid: firebaseUser.uid,
        role: role,
      );

      if (userEntity.role != role || !existsInSegment) {
        // Sign out Firebase session immediately - NEVER allow credentials mixing
        await _firebaseAuth.signOut();
        await _secureStorage.clearTokens();
        return AuthResult.roleMismatch(
          expectedRole: role,
          actualRole: userEntity.role,
          user: userEntity,
        );
      }

      // 4. ACCOUNT STATUS CHECK
      if (userEntity.accountStatus == AccountStatus.pending) {
        await _rateLimitService.resetFailedLogins(cleanEmail);
        await _persistUserLocally(userEntity);
        return AuthResult.pendingApproval(userEntity);
      } else if (userEntity.accountStatus == AccountStatus.suspended) {
        await _firebaseAuth.signOut();
        return AuthResult.suspended(userEntity);
      } else if (userEntity.accountStatus == AccountStatus.disabled) {
        await _firebaseAuth.signOut();
        return AuthResult.disabled(userEntity);
      }

      // 5. EMAIL VERIFICATION CHECK (optional soft/hard gate)
      if (!firebaseUser.emailVerified && !userEntity.emailVerified) {
        if (role == UserRole.customer) {
          // We can notify or enforce verification
          await _persistUserLocally(userEntity);
          // Return success or email verification based on policy
        }
      }

      // 6. Save valid session and clear failed login attempts
      await _rateLimitService.resetFailedLogins(cleanEmail);
      final token = await firebaseUser.getIdToken() ?? 'token_${firebaseUser.uid}';
      await _secureStorage.saveTokens(
        token: token,
        refreshToken: firebaseUser.refreshToken ?? '',
      );
      await _persistUserLocally(userEntity);

      return AuthResult.success(userEntity);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-not-found') {
        final failedCount =
            await _rateLimitService.recordFailedLogin(emailOrPhone.trim());
        if (failedCount >= RateLimitService.maxFailedLogins) {
          return AuthResult.failure(
            'Too many failed login attempts. For your security, this account is temporarily locked for 15 minutes.',
            errorCode: 'account-locked',
          );
        }
      }
      return AuthResult.failure(
        AuthErrorMapper.mapFirebaseAuthException(e),
        errorCode: e.code,
      );
    } catch (e) {
      return AuthResult.failure(
        AuthErrorMapper.mapGeneralException(e),
      );
    }
  }

  /// Real Firebase registration with role-specific profiles
  Future<AuthResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    String? storeName,
    String? businessCategory,
    String? vehicleNumber,
    String? deliveryZone,
    RiderLocation? deliveryLocation,
    String? adminDepartment,
    String? adminId,
    String? cnicNumber,
    String? drivingLicenseNumber,
  }) async {
    try {
      // 1. Admin registration verification: requires valid unlocked unique adminId
      if (role == UserRole.admin) {
        if (adminId == null || adminId.trim().isEmpty) {
          return AuthResult.failure(
            'Admin accounts cannot be registered publicly without a verified Unique Admin ID.',
            errorCode: 'admin-registration-blocked',
          );
        }
      }

      final cleanEmail = email.trim();
      final cleanName = name.trim();
      final cleanPhone = phone.trim();

      // Rate limit check: Prevent bulk fake account creation / spam registrations
      if (!_rateLimitService.canRegister()) {
        final remaining =
            _rateLimitService.getRemainingRegistrationCooldownSeconds();
        if (remaining > 0) {
          return AuthResult.failure(
            'Too many registration attempts. Please wait $remaining seconds before trying again.',
            errorCode: 'rate-limited',
          );
        }
        return AuthResult.failure(
          'Maximum account creation attempts reached for this session. Please try again later.',
          errorCode: 'rate-limit-exceeded',
        );
      }
      await _rateLimitService.recordRegistrationAttempt();

      // 2. Create user with Firebase Auth (or recover if created during a previously failed Firestore write)
      UserCredential userCredential;
      try {
        userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          try {
            final existingCred = await _firebaseAuth.signInWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
            final existingUid = existingCred.user?.uid;
            if (existingUid != null) {
              final existingDoc = await _firestoreRepo.getUser(existingUid);
              if (existingDoc == null) {
                // Auth user exists from interrupted attempt without Firestore doc. Self-heal and continue!
                userCredential = existingCred;
              } else {
                return AuthResult.failure(
                  'An account with this email already exists. Please sign in instead.',
                  errorCode: 'email-already-in-use',
                );
              }
            } else {
              rethrow;
            }
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return AuthResult.failure('Registration failed. Unable to create user.');
      }

      // 3. Update Firebase display name
      await firebaseUser.updateDisplayName(cleanName);

      // 4. Send email verification
      try {
        await firebaseUser.sendEmailVerification();
      } catch (e) {
        debugPrint('Notice sending verification email: $e');
      }

      // 5. Determine initial status: Seller/Rider start as pending approval, Admin & Customer active
      final initialStatus = (role == UserRole.seller || role == UserRole.rider)
          ? AccountStatus.pending
          : AccountStatus.active;

      // 6. Create UserEntity & store profile in Firestore
      final userEntity = UserEntity(
        id: firebaseUser.uid,
        name: cleanName,
        email: cleanEmail,
        phone: cleanPhone,
        role: role,
        isVerified: false,
        emailVerified: false,
        accountStatus: initialStatus,
        createdAt: DateTime.now(),
        storeName: storeName?.trim(),
        businessCategory: businessCategory?.trim(),
        vehicleNumber: vehicleNumber?.trim(),
        deliveryZone: deliveryZone?.trim(),
        deliveryLocation: deliveryLocation,
        adminDepartment: adminDepartment?.trim(),
        adminId: adminId?.trim(),
        cnicNumber: cnicNumber?.trim(),
        drivingLicenseNumber: drivingLicenseNumber?.trim(),
      );

      await _firestoreRepo.createUserProfile(user: userEntity);

      // 7. Save session locally
      final token = await firebaseUser.getIdToken() ?? 'token_${firebaseUser.uid}';
      await _secureStorage.saveTokens(
        token: token,
        refreshToken: firebaseUser.refreshToken ?? '',
      );
      await _persistUserLocally(userEntity);

      // 8. Return appropriate result
      if (initialStatus == AccountStatus.pending) {
        return AuthResult.pendingApproval(userEntity);
      }

      return AuthResult.success(userEntity);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        AuthErrorMapper.mapFirebaseAuthException(e),
        errorCode: e.code,
      );
    } catch (e) {
      return AuthResult.failure(
        AuthErrorMapper.mapGeneralException(e),
      );
    }
  }

  /// Sign In with Google Credentials and role verification.
  /// google_sign_in_android v6.x uses Credential Manager and reads the web
  /// client ID from google-services.json automatically — do NOT pass
  /// serverClientId unless the first attempt fails.
  Future<AuthResult> signInWithGoogle({required UserRole role}) async {
    try {
      // Phase 1: Standard flow — Credential Manager reads config from
      // google-services.json automatically (google_sign_in_android ≥ 6.x)
      GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );

      // Clear stale session state
      try { await googleSignIn.signOut(); } catch (_) {}
      try { await googleSignIn.disconnect(); } catch (_) {}

      GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.signIn();
      } catch (e) {
        final errStr = e.toString().toLowerCase();

        // User canceled
        if (errStr.contains('12501') || errStr.contains('canceled') ||
            errStr.contains('cancelled') || errStr.contains('sign_in_cancelled')) {
          return AuthResult.failure('Google sign-in was canceled.');
        }

        debugPrint('🟡 [Google Sign-In] Phase 1 failed: $e');
        debugPrint('🟡 [Google Sign-In] Attempting Phase 2 with explicit serverClientId...');

        // Phase 2: Fallback — pass serverClientId explicitly for devices
        // with older Play Services or where Credential Manager lookup fails
        try {
          googleSignIn = GoogleSignIn(
            scopes: ['email'],
            serverClientId: DefaultFirebaseOptions.googleWebClientId,
          );
          try { await googleSignIn.signOut(); } catch (_) {}
          try { await googleSignIn.disconnect(); } catch (_) {}
          googleUser = await googleSignIn.signIn();
        } catch (e2) {
          final errStr2 = e2.toString().toLowerCase();
          if (errStr2.contains('12501') || errStr2.contains('canceled') ||
              errStr2.contains('cancelled')) {
            return AuthResult.failure('Google sign-in was canceled.');
          }
          debugPrint(
            '🔴 [Google Sign-In] Both phases failed.\n'
            '   Phase 1 error: $e\n'
            '   Phase 2 error: $e2\n'
            '   Checklist to fix:\n'
            '   1. Ensure SHA-1 fingerprint D0:69:16:55:55:4E:97:A9:5C:68:1B:F0:54:FC:99:B1:31:DE:AA:CB is in Firebase Console\n'
            '   2. Ensure OAuth Consent Screen has a support email set\n'
            '   3. Re-download google-services.json from Firebase Console\n'
            '   4. Run: flutter clean && flutter run\n'
            '   5. Ensure Google Play Services is up to date on device'
          );
          return AuthResult.failure(
            'Google sign-in failed. Please ensure:\n'
            '• SHA-1 fingerprint is registered in Firebase Console\n'
            '• OAuth Consent Screen has a support email\n'
            '• google-services.json is up to date\n'
            '• Google Play Services is updated on your device\n'
            'Run "flutter clean" and rebuild after updating.',
          );
        }
      }

      if (googleUser == null) {
        return AuthResult.failure('Google sign-in was canceled.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        debugPrint('🔴 [Google Sign-In] No tokens received from Google.');
        return AuthResult.failure(
          'Failed to obtain authentication tokens from Google. '
          'Please verify your SHA-1 fingerprints in Firebase Console.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return AuthResult.failure('Failed to obtain user profile from Google.');
      }

      // 1. Fetch user profile from Firestore (by UID or email)
      UserEntity? userEntity = await _firestoreRepo.getUser(firebaseUser.uid);
      if (userEntity == null && firebaseUser.email != null) {
        userEntity = await _firestoreRepo.findUserByEmail(firebaseUser.email!);
      }

      if (userEntity == null) {
        // User registering via Google
        final initialStatus = (role == UserRole.seller || role == UserRole.rider)
            ? AccountStatus.pending
            : AccountStatus.active;

        final String? adminId = (role == UserRole.admin)
            ? 'ADM-${firebaseUser.uid.substring(0, 6).toUpperCase()}'
            : null;
        final String? adminDept = (role == UserRole.admin)
            ? 'Platform Operations & Governance'
            : null;

        userEntity = UserEntity(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? googleUser.displayName ?? (role == UserRole.admin ? 'Platform Administrator' : 'Groclyra User'),
          email: firebaseUser.email ?? googleUser.email,
          phone: firebaseUser.phoneNumber ?? '',
          role: role,
          avatarUrl: firebaseUser.photoURL ?? googleUser.photoUrl,
          isVerified: true,
          emailVerified: true,
          accountStatus: initialStatus,
          adminId: adminId,
          adminDepartment: adminDept,
          createdAt: DateTime.now(),
        );

        await _firestoreRepo.createUserProfile(
          user: userEntity,
          additionalRoleData: role == UserRole.admin
              ? {
                  'adminId': adminId,
                  'adminDepartment': adminDept,
                  'accessLevel': 'superadmin',
                }
              : null,
        );
      } else {
        // Strict role validation with owner override for Admin portal.
        // Upgraded (security): the owner back-door is now active only in
        // debug builds — release builds always enforce the profile role.
        if (userEntity.role != role) {
          final isOwner = kDebugMode &&
              _ownerAdminEmail.isNotEmpty &&
              (firebaseUser.email?.toLowerCase() == _ownerAdminEmail.toLowerCase() ||
               userEntity.email.toLowerCase() == _ownerAdminEmail.toLowerCase());
          if (role == UserRole.admin && isOwner) {
            final adminId = userEntity.adminId ?? 'ADM-${firebaseUser.uid.substring(0, 6).toUpperCase()}';
            userEntity = userEntity.copyWith(
              role: UserRole.admin,
              adminId: adminId,
              adminDepartment: userEntity.adminDepartment ?? 'Platform Operations & Governance',
              accountStatus: AccountStatus.active,
            );
            await _firestoreRepo.createUserProfile(
              user: userEntity,
              additionalRoleData: {
                'adminId': adminId,
                'adminDepartment': userEntity.adminDepartment,
              },
            );
          } else {
            await _firebaseAuth.signOut();
            return AuthResult.roleMismatch(
              expectedRole: role,
              actualRole: userEntity.role,
              user: userEntity,
            );
          }
        }
      }

      // Check account status
      if (userEntity.accountStatus == AccountStatus.pending) {
        await _persistUserLocally(userEntity);
        return AuthResult.pendingApproval(userEntity);
      } else if (userEntity.accountStatus == AccountStatus.suspended) {
        await _firebaseAuth.signOut();
        return AuthResult.suspended(userEntity);
      } else if (userEntity.accountStatus == AccountStatus.disabled) {
        await _firebaseAuth.signOut();
        return AuthResult.disabled(userEntity);
      }

      await _persistUserLocally(userEntity);
      return AuthResult.success(userEntity);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        AuthErrorMapper.mapFirebaseAuthException(e),
        errorCode: e.code,
      );
    } catch (e) {
      debugPrint('🔴 [Google Sign-In] Unhandled error: $e');
      return AuthResult.failure(AuthErrorMapper.mapGeneralException(e));
    }
  }

  /// Sends Phone OTP via Firebase Auth with 60s timeout and E.164 standardization
  /// conforming to PhoneAuthOptions specification
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    int? forceResendingToken,
  }) async {
    final formattedPhone = ValidatorUtils.formatToE164(phoneNumber);

    // Rate-limiting check: SMS bombing & cost abuse control
    if (!_rateLimitService.canSendOtp(formattedPhone)) {
      final remaining =
          _rateLimitService.getRemainingOtpCooldownSeconds(formattedPhone);
      onVerificationFailed(
        FirebaseAuthException(
          code: 'too-many-requests',
          message: remaining > 0
              ? 'Please wait $remaining seconds before requesting another SMS code.'
              : 'SMS verification limit reached for this number. Please try again later.',
        ),
      );
      return;
    }
    
    // Explicitly apply the default app language (equivalent to auth.useAppLanguage() in Java)
    // or you can set a specific language code like auth.setLanguageCode("en") if preferred.
    await _firebaseAuth.setLanguageCode('en');

    // FORCE REAL SMS DELIVERY: 
    // Disabling app verification testing ensures Firebase attempts to send an actual SMS
    // instead of simulating it, provided the number is not in the "Phone numbers for testing" list.
    await _firebaseAuth.setSettings(appVerificationDisabledForTesting: false);

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      timeout: const Duration(seconds: 60), // equivalent to .setTimeout(60L, TimeUnit.SECONDS)
      verificationCompleted: onVerificationCompleted, // equivalent to OnVerificationStateChangedCallbacks.onVerificationCompleted
      verificationFailed: onVerificationFailed,
      codeSent: (String id, int? token) {
        _rateLimitService.recordOtpSent(formattedPhone);
        onCodeSent(id, token);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      forceResendingToken: forceResendingToken,
    );
  }

  /// Signs in directly with a verified PhoneAuthCredential (e.g. from verificationCompleted or OTP)
  Future<AuthResult> signInWithPhoneCredential({
    required PhoneAuthCredential credential,
    required UserRole role,
    String? name,
  }) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return AuthResult.failure('Failed to sign in with phone verification.');
      }

      UserEntity? userEntity = await _firestoreRepo.getUser(firebaseUser.uid);
      if (userEntity == null && firebaseUser.phoneNumber != null && firebaseUser.phoneNumber!.isNotEmpty) {
        userEntity = await _firestoreRepo.findUserByPhone(firebaseUser.phoneNumber!);
      }

      if (userEntity == null) {
        final initialStatus = (role == UserRole.seller || role == UserRole.rider)
            ? AccountStatus.pending
            : AccountStatus.active;

        final String? adminId = (role == UserRole.admin)
            ? 'ADM-${firebaseUser.uid.substring(0, 6).toUpperCase()}'
            : null;
        final String? adminDept = (role == UserRole.admin)
            ? 'Platform Operations & Governance'
            : null;

        userEntity = UserEntity(
          id: firebaseUser.uid,
          name: name ?? firebaseUser.displayName ?? (role == UserRole.admin ? 'Platform Administrator' : 'Phone User'),
          email: firebaseUser.email ?? '',
          phone: firebaseUser.phoneNumber ?? '',
          role: role,
          isVerified: true,
          emailVerified: true,
          accountStatus: initialStatus,
          adminId: adminId,
          adminDepartment: adminDept,
          createdAt: DateTime.now(),
        );

        await _firestoreRepo.createUserProfile(
          user: userEntity,
          additionalRoleData: role == UserRole.admin
              ? {
                  'adminId': adminId,
                  'adminDepartment': adminDept,
                  'accessLevel': 'superadmin',
                }
              : null,
        );
      } else {
        if (userEntity.role != role) {
          // Upgraded (security): owner back-door active in debug builds only with configured credentials.
          final isOwner = kDebugMode &&
              ((_ownerAdminEmail.isNotEmpty &&
                      userEntity.email.toLowerCase() == _ownerAdminEmail.toLowerCase()) ||
                  (_ownerAdminPhone.isNotEmpty &&
                      firebaseUser.phoneNumber == _ownerAdminPhone));
          if (role == UserRole.admin && isOwner) {
            final adminId = userEntity.adminId ?? 'ADM-${firebaseUser.uid.substring(0, 6).toUpperCase()}';
            userEntity = userEntity.copyWith(
              role: UserRole.admin,
              adminId: adminId,
              adminDepartment: userEntity.adminDepartment ?? 'Platform Operations & Governance',
              accountStatus: AccountStatus.active,
            );
            await _firestoreRepo.createUserProfile(
              user: userEntity,
              additionalRoleData: {
                'adminId': adminId,
                'adminDepartment': userEntity.adminDepartment,
              },
            );
          } else {
            await _firebaseAuth.signOut();
            return AuthResult.roleMismatch(
              expectedRole: role,
              actualRole: userEntity.role,
              user: userEntity,
            );
          }
        }
      }

      if (userEntity.accountStatus == AccountStatus.pending) {
        await _persistUserLocally(userEntity);
        return AuthResult.pendingApproval(userEntity);
      } else if (userEntity.accountStatus == AccountStatus.suspended) {
        await _firebaseAuth.signOut();
        return AuthResult.suspended(userEntity);
      } else if (userEntity.accountStatus == AccountStatus.disabled) {

        await _firebaseAuth.signOut();
        return AuthResult.disabled(userEntity);
      }

      await _persistUserLocally(userEntity);
      return AuthResult.success(userEntity);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        AuthErrorMapper.mapFirebaseAuthException(e),
        errorCode: e.code,
      );
    } catch (e) {
      return AuthResult.failure(AuthErrorMapper.mapGeneralException(e));
    }
  }

  /// Verifies SMS OTP and signs in using PhoneAuthProvider credential
  Future<AuthResult> signInWithPhoneOtp({
    required String verificationId,
    required String smsCode,
    required UserRole role,
    String? name,
  }) async {
    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    return signInWithPhoneCredential(
      credential: credential,
      role: role,
      name: name,
    );
  }

  /// Sends a Firebase password reset email with anti-enumeration protection and rate limiting
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      if (!cleanEmail.contains('@')) {
        return AuthResult.failure('Please enter a valid email address.');
      }

      // Rate limit check: Prevent email bombing & rapid reset spam
      if (!_rateLimitService.canSendPasswordReset(cleanEmail)) {
        final remainingSec =
            _rateLimitService.getRemainingPasswordResetCooldownSeconds(cleanEmail);
        if (remainingSec > 0) {
          return AuthResult.failure(
            'Please wait $remainingSec second${remainingSec > 1 ? 's' : ''} before requesting another password reset link.',
            errorCode: 'rate-limited',
          );
        }
        return AuthResult.failure(
          'Maximum password reset attempts reached for this hour. Please try again later.',
          errorCode: 'rate-limit-exceeded',
        );
      }

      await _firebaseAuth.sendPasswordResetEmail(email: cleanEmail);
      await _rateLimitService.recordPasswordResetSent(cleanEmail);

      return const AuthResult(
        status: AuthResultStatus.success,
        message:
            'If an account exists with this email, password reset instructions have been sent.',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Anti-enumeration protection: return generic success so attackers
        // cannot probe which email addresses exist on the platform.
        await _rateLimitService.recordPasswordResetSent(email.trim().toLowerCase());
        return const AuthResult(
          status: AuthResultStatus.success,
          message:
              'If an account exists with this email, password reset instructions have been sent.',
        );
      }
      return AuthResult.failure(
        AuthErrorMapper.mapFirebaseAuthException(e),
        errorCode: e.code,
      );
    } catch (e) {
      return AuthResult.failure(AuthErrorMapper.mapGeneralException(e));
    }
  }

  /// Sends email verification to current user with cooldown guard
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return AuthResult.failure('No active session found.');
      }

      final identifier = user.uid.isNotEmpty ? user.uid : (user.email ?? 'current_user');
      if (!_rateLimitService.canResendEmailVerification(identifier)) {
        final remaining =
            _rateLimitService.getRemainingEmailVerificationCooldownSeconds(identifier);
        return AuthResult.failure(
          'Please wait $remaining second${remaining > 1 ? 's' : ''} before requesting another verification email.',
          errorCode: 'rate-limited',
        );
      }

      await user.sendEmailVerification();
      await _rateLimitService.recordEmailVerificationSent(identifier);

      return const AuthResult(
        status: AuthResultStatus.success,
        message: 'Verification email sent successfully.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        AuthErrorMapper.mapFirebaseAuthException(e),
        errorCode: e.code,
      );
    } catch (e) {
      return AuthResult.failure(AuthErrorMapper.mapGeneralException(e));
    }
  }

  /// Reloads current user and checks if email is verified
  Future<bool> checkEmailVerified() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;
      await user.reload();
      final isVerified = _firebaseAuth.currentUser?.emailVerified ?? false;
      if (isVerified) {
        await _firestoreRepo.updateEmailVerification(user.uid, true);
      }
      return isVerified;
    } catch (e) {
      debugPrint('Check email verified error: $e');
      return false;
    }
  }

  /// Updates a user's profile and syncs local session
  Future<AuthResult> updateUserProfile({
    required UserEntity user,
    String? name,
    String? phone,
    String? profileImageBase64,
  }) async {
    try {
      await _firestoreRepo.updateUserProfile(
        user,
        newName: name,
        newPhone: phone,
        newProfileImageBase64: profileImageBase64,
      );
      
      // Update local Firebase Auth profile if name changed
      if (name != null) {
        await _firebaseAuth.currentUser?.updateDisplayName(name);
      }
      
      // Fetch fresh user to update local session
      final updatedUser = await _firestoreRepo.getUser(user.id);
      if (updatedUser != null) {
        await _persistUserLocally(updatedUser);
        return AuthResult.success(updatedUser);
      }
      
      return AuthResult.failure("Failed to retrieve updated profile.");
    } catch (e) {
      return AuthResult.failure("Profile update failed: $e");
    }
  }

  /// Complete sign out
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Firebase sign out notice: $e');
    }
    await _secureStorage.clearAll();
    await _prefs?.clearSavedRole();
  }

  Future<void> _persistUserLocally(UserEntity user) async {
    try {
      await _secureStorage.saveUserPayload(jsonEncode(user.toJson()));
      await _prefs?.setSavedRole(user.role.name);
    } catch (e) {
      debugPrint('Local persist notice: $e');
    }
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final prefs = ref.watch(preferencesServiceProvider);
  final firestoreRepo = ref.watch(firestoreUserRepositoryProvider);
  final rateLimitService = ref.watch(rateLimitServiceProvider);
  return AuthRepository(
    firestoreRepo: firestoreRepo,
    secureStorage: secureStorage,
    prefs: prefs,
    rateLimitService: rateLimitService,
  );
});
