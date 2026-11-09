import 'user_entity.dart';

enum AuthResultStatus {
  success,
  emailVerificationRequired,
  twoFactorRequired,
  pendingApproval,
  suspended,
  disabled,
  roleMismatch,
  failure,
}

class AuthResult {
  final AuthResultStatus status;
  final UserEntity? user;
  final String? message;
  final String? errorCode;
  final UserRole? expectedRole;
  final UserRole? actualRole;

  const AuthResult({
    required this.status,
    this.user,
    this.message,
    this.errorCode,
    this.expectedRole,
    this.actualRole,
  });

  bool get isSuccess => status == AuthResultStatus.success;
  bool get isFailure => status == AuthResultStatus.failure;
  bool get isRoleMismatch => status == AuthResultStatus.roleMismatch;
  bool get isPendingApproval => status == AuthResultStatus.pendingApproval;
  bool get requiresEmailVerification =>
      status == AuthResultStatus.emailVerificationRequired;
  bool get requiresTwoFactor => status == AuthResultStatus.twoFactorRequired;

  factory AuthResult.success(UserEntity user, {String? message}) {
    return AuthResult(
      status: AuthResultStatus.success,
      user: user,
      message: message ?? 'Authentication successful',
    );
  }

  factory AuthResult.twoFactorRequired(UserEntity user, {String? message}) {
    return AuthResult(
      status: AuthResultStatus.twoFactorRequired,
      user: user,
      message: message ?? 'Please enter the 6-digit code from your authenticator app.',
    );
  }

  factory AuthResult.emailVerificationRequired(UserEntity user) {
    return AuthResult(
      status: AuthResultStatus.emailVerificationRequired,
      user: user,
      message: 'Please verify your email address to continue.',
    );
  }

  factory AuthResult.pendingApproval(UserEntity user) {
    return AuthResult(
      status: AuthResultStatus.pendingApproval,
      user: user,
      message:
          'Your account application is under review. You will be notified once approved.',
    );
  }

  factory AuthResult.suspended(UserEntity user) {
    return AuthResult(
      status: AuthResultStatus.suspended,
      user: user,
      message:
          'Your account has been suspended. Please reach out to support for assistance.',
    );
  }

  factory AuthResult.disabled(UserEntity user) {
    return AuthResult(
      status: AuthResultStatus.disabled,
      user: user,
      message:
          'This account has been deactivated. Please contact support.',
    );
  }

  factory AuthResult.roleMismatch({
    required UserRole expectedRole,
    required UserRole actualRole,
    UserEntity? user,
  }) {
    return AuthResult(
      status: AuthResultStatus.roleMismatch,
      user: user,
      expectedRole: expectedRole,
      actualRole: actualRole,
      message:
          'Access restricted: This account is registered as a ${actualRole.displayName}. Please switch to the ${actualRole.displayName} tab to sign in.',
    );
  }

  factory AuthResult.failure(String message, {String? errorCode}) {
    return AuthResult(
      status: AuthResultStatus.failure,
      message: message,
      errorCode: errorCode,
    );
  }
}
