import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_error_mapper.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/rider_location.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/database/app_database.dart';

class AuthState {
  final UserEntity? user;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final bool isInitialized;
  final UserRole selectedRole;
  final AuthResultStatus? status;
  final UserRole? actualRole;
  final AuthResult? lastResult;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.isInitialized = false,
    this.selectedRole = UserRole.customer,
    this.status,
    this.actualRole,
    this.lastResult,
  });

  bool get isAuthenticated => user != null;
  UserRole? get currentRole => user?.role;
  bool get isPending => user?.isPending ?? (status == AuthResultStatus.pendingApproval);
  bool get isSuspended => user?.isSuspended ?? (status == AuthResultStatus.suspended);
  bool get isDisabled => user?.isDisabled ?? (status == AuthResultStatus.disabled);
  bool get isRoleMismatch => status == AuthResultStatus.roleMismatch;
  bool get requiresEmailVerification =>
      status == AuthResultStatus.emailVerificationRequired;
  bool get requiresTwoFactor => status == AuthResultStatus.twoFactorRequired;

  AuthState copyWith({
    UserEntity? user,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool? isInitialized,
    UserRole? selectedRole,
    AuthResultStatus? status,
    UserRole? actualRole,
    AuthResult? lastResult,
    bool clearUser = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      isInitialized: isInitialized ?? this.isInitialized,
      selectedRole: selectedRole ?? this.selectedRole,
      status: status ?? this.status,
      actualRole: actualRole ?? this.actualRole,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AuthState()) {
    _initSession();
    _listenAuthState();
  }

  void _listenAuthState() {
    _repository.authStateChanges.listen((user) async {
      if (user == null) {
        // User is logged out
        if (state.user != null) {
          state = state.copyWith(clearUser: true);
        }
      } else {
        if (state.user?.id != user.id || state.user != user) {
          state = state.copyWith(
            user: user,
            selectedRole: user.role,
            status: AuthResultStatus.success,
          );
        }
      }
    });

    // Real-time table watcher on SQLite users
    AppDatabase.instance.watchTable('users').listen((_) async {
      final uid = state.user?.id ?? AppDatabase.instance.activeSessionUserId;
      if (uid != null && uid.isNotEmpty) {
        final row = await AppDatabase.instance.userDao.getUserById(uid);
        if (row != null && mounted) {
          final updated = UserEntity.fromJson(row);
          if (updated != state.user) {
            state = state.copyWith(user: updated);
          }
        }
      }
    });
  }

  Future<void> _initSession() async {
    try {
      final user = await _repository.restoreSession();
      state = state.copyWith(
        user: user,
        isInitialized: true,
        selectedRole: user?.role ?? state.selectedRole,
        status: user != null ? AuthResultStatus.success : null,
      );
    } catch (_) {
      state = state.copyWith(isInitialized: true);
    }
  }

  void selectRole(UserRole role) {
    if (state.selectedRole != role) {
      state = state.copyWith(
        selectedRole: role,
        clearError: true,
        status: null,
      );
    }
  }

  void clearError() {
    if (state.errorMessage != null || state.status == AuthResultStatus.roleMismatch) {
      state = state.copyWith(clearError: true, status: null);
    }
  }

  void updateUserDeliveryAddress({
    required String deliveryAddress,
    required String deliveryZone,
    double? latitude,
    double? longitude,
  }) {
    if (state.user != null) {
      final updated = state.user!.copyWith(
        deliveryAddress: deliveryAddress,
        deliveryZone: deliveryZone,
        deliveryLocation: latitude != null && longitude != null
            ? RiderLocation(
                latitude: latitude,
                longitude: longitude,
                source: 'map',
                formattedAddress: deliveryAddress,
              )
            : state.user!.deliveryLocation,
      );
      state = state.copyWith(user: updated);
    }
  }

  Future<AuthResult> login({
    required String emailOrPhone,
    required String password,
    required UserRole role,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      selectedRole: role,
    );

    final result = await _repository.login(
      emailOrPhone: emailOrPhone,
      password: password,
      role: role,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.success,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.isRoleMismatch) {
      state = state.copyWith(
        isLoading: false,
        status: AuthResultStatus.roleMismatch,
        actualRole: result.actualRole,
        errorMessage: result.message,
        lastResult: result,
      );
    } else if (result.requiresTwoFactor) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.twoFactorRequired,
        errorMessage: null,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.isPendingApproval) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.pendingApproval,
        errorMessage: result.message,
        lastResult: result,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        status: result.status,
        errorMessage: result.message,
        lastResult: result,
      );
    }

    return result;
  }

  /// Verifies the 6-digit TOTP code or backup code for 2FA-protected accounts
  Future<AuthResult> submitTwoFactorCode(String code) async {
    final pendingUser = state.user ?? state.lastResult?.user;
    if (pendingUser == null) {
      return AuthResult.failure('No pending login session found.');
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.completeTwoFactorLogin(
      userEntity: pendingUser,
      code: code,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.success,
        successMessage: 'Two-factor verification confirmed ✓',
        lastResult: result,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        status: AuthResultStatus.twoFactorRequired,
        errorMessage: result.message,
        lastResult: result,
      );
    }

    return result;
  }

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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      selectedRole: role,
    );

    final result = await _repository.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: role,
      storeName: storeName,
      businessCategory: businessCategory,
      vehicleNumber: vehicleNumber,
      deliveryZone: deliveryZone,
      deliveryLocation: deliveryLocation,
      adminDepartment: adminDepartment,
      adminId: adminId,
      cnicNumber: cnicNumber,
      drivingLicenseNumber: drivingLicenseNumber,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.success,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.requiresTwoFactor) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.twoFactorRequired,
        errorMessage: null,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.isPendingApproval) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.pendingApproval,
        successMessage: result.message,
        lastResult: result,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        status: result.status,
        errorMessage: result.message,
        lastResult: result,
      );
    }

    return result;
  }

  Future<AuthResult> signInWithGoogle({required UserRole role}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      selectedRole: role,
    );

    final result = await _repository.signInWithGoogle(role: role);

    if (result.isSuccess) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.success,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.isRoleMismatch) {
      state = state.copyWith(
        isLoading: false,
        status: AuthResultStatus.roleMismatch,
        actualRole: result.actualRole,
        errorMessage: result.message,
        lastResult: result,
      );
    } else if (result.requiresTwoFactor) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.twoFactorRequired,
        errorMessage: null,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.isPendingApproval) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.pendingApproval,
        errorMessage: result.message,
        lastResult: result,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        status: result.status,
        errorMessage: result.message,
        lastResult: result,
      );
    }

    return result;
  }

  /// Fast-path biometric vault sign-in
  Future<AuthResult> signInWithBiometricVault({
    required String email,
    required UserRole role,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      selectedRole: role,
    );

    try {
      final rows = await AppDatabase.instance.query(
        'users',
        where: 'LOWER(email) = ?',
        whereArgs: [email.trim().toLowerCase()],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final user = UserEntity.fromJson(rows.first);
        AppDatabase.instance.activeSessionUserId = user.id;
        state = state.copyWith(
          user: user,
          isLoading: false,
          status: AuthResultStatus.success,
          successMessage: 'Biometric authentication verified ✓',
        );
        return AuthResult.success(user, message: 'Welcome back, ${user.name}');
      }
    } catch (_) {}

    state = state.copyWith(
      isLoading: false,
      errorMessage: 'No registered account found matching biometric enrollment for $email.',
    );
    return AuthResult.failure(
      'No registered account found matching biometric credentials. Please sign in with email and password.',
    );
  }

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException error) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    int? forceResendingToken,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.sendPhoneOtp(
        phoneNumber: phoneNumber,
        forceResendingToken: forceResendingToken,
        onCodeSent: (verificationId, token) {
          state = state.copyWith(isLoading: false);
          onCodeSent(verificationId, token);
        },
        onVerificationFailed: (error) {
          final message = AuthErrorMapper.mapFirebaseAuthException(error);
          state = state.copyWith(
            isLoading: false,
            errorMessage: message,
          );
          onVerificationFailed(error);
        },
        onVerificationCompleted: (credential) {
          state = state.copyWith(isLoading: false);
          onVerificationCompleted(credential);
        },
      );
    } catch (e) {
      final error = e is FirebaseAuthException
          ? e
          : FirebaseAuthException(code: 'unknown', message: e.toString());
      final message = AuthErrorMapper.mapFirebaseAuthException(error);
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
      onVerificationFailed(error);
    }
  }

  Future<AuthResult> signInWithPhoneCredential({
    required PhoneAuthCredential credential,
    required UserRole role,
    String? name,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      selectedRole: role,
    );

    final result = await _repository.signInWithPhoneCredential(
      credential: credential,
      role: role,
      name: name,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.success,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.isRoleMismatch) {
      state = state.copyWith(
        isLoading: false,
        status: AuthResultStatus.roleMismatch,
        actualRole: result.actualRole,
        errorMessage: result.message,
        lastResult: result,
      );
    } else if (result.requiresTwoFactor) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.twoFactorRequired,
        errorMessage: null,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.isPendingApproval) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.pendingApproval,
        errorMessage: result.message,
        lastResult: result,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        status: result.status,
        errorMessage: result.message,
        lastResult: result,
      );
    }

    return result;
  }

  Future<AuthResult> signInWithPhoneOtp({
    required String verificationId,
    required String smsCode,
    required UserRole role,
    String? name,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      selectedRole: role,
    );

    final result = await _repository.signInWithPhoneOtp(
      verificationId: verificationId,
      smsCode: smsCode,
      role: role,
      name: name,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.success,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.isRoleMismatch) {
      state = state.copyWith(
        isLoading: false,
        status: AuthResultStatus.roleMismatch,
        actualRole: result.actualRole,
        errorMessage: result.message,
        lastResult: result,
      );
    } else if (result.requiresTwoFactor) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.twoFactorRequired,
        errorMessage: null,
        successMessage: result.message,
        lastResult: result,
      );
    } else if (result.isPendingApproval) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        status: AuthResultStatus.pendingApproval,
        errorMessage: result.message,
        lastResult: result,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        status: result.status,
        errorMessage: result.message,
        lastResult: result,
      );
    }

    return result;
  }

  Future<AuthResult> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _repository.sendPasswordReset(email);
    state = state.copyWith(
      isLoading: false,
      errorMessage: result.isSuccess ? null : result.message,
      successMessage: result.isSuccess ? result.message : null,
      lastResult: result,
    );
    return result;
  }

  Future<AuthResult> sendEmailVerification() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.sendEmailVerification();
    state = state.copyWith(
      isLoading: false,
      errorMessage: result.isSuccess ? null : result.message,
      successMessage: result.isSuccess ? result.message : null,
      lastResult: result,
    );
    return result;
  }

  Future<bool> checkEmailVerified() async {
    final verified = await _repository.checkEmailVerified();
    if (verified && state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(emailVerified: true, isVerified: true),
        status: AuthResultStatus.success,
      );
    }
    return verified;
  }

  /// Updates live user state from Firestore snapshots
  void updateUserSession(UserEntity user) {
    state = state.copyWith(
      user: user,
      status: user.isActive
          ? AuthResultStatus.success
          : (user.isPending ? AuthResultStatus.pendingApproval : state.status),
    );
  }

  /// Kept for safe demo role switching in profile testing.
  /// Upgraded (security): a no-op in release builds — role changes must come
  /// from the approved access flow, never raw client mutation.
  Future<void> switchRoleQuickDemo(UserRole newRole) async {
    if (!kDebugMode) return;
    if (state.user != null) {
      final updatedUser = state.user!.copyWith(role: newRole);
      state = state.copyWith(user: updatedUser, selectedRole: newRole);
    }
  }

  Future<AuthResult> requestRoleSwitch(UserRole targetRole) async {
    final user = state.user;
    if (user == null) {
      return AuthResult.failure("You must be logged in to switch roles.");
    }

    if (user.authorizedRoles.contains(targetRole)) {
      // Switch active role
      final updatedUser = user.copyWith(role: targetRole);
      state = state.copyWith(
        user: updatedUser,
        selectedRole: targetRole,
        status: AuthResultStatus.success,
      );
      return AuthResult.success(updatedUser);
    } else {
      return AuthResult.failure("Access Denied: You do not have permission for the ${targetRole.displayName} portal.");
    }
  }

  Future<AuthResult> updateProfile({
    String? name,
    String? phone,
    String? profileImageBase64,
  }) async {
    final user = state.user;
    if (user == null) return AuthResult.failure("No user signed in.");

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    
    final result = await _repository.updateUserProfile(
      user: user,
      name: name,
      phone: phone,
      profileImageBase64: profileImageBase64,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        user: result.user,
        isLoading: false,
        successMessage: "Profile updated successfully.",
        status: AuthResultStatus.success,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.message,
      );
    }
    
    return result;
  }

  Future<void> logout() async {
    await _repository.logout();
    state = state.copyWith(
      clearUser: true,
      isInitialized: true,
      status: null,
      clearError: true,
      clearSuccess: true,
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});
