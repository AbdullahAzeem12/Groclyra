import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorMapper {
  static String mapFirebaseAuthException(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-email':
        return 'The email address is invalid. Please check and try again.';
      case 'user-disabled':
        return 'This account has been deactivated. Please contact Groclyra support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please verify your details.';
      case 'email-already-in-use':
        return 'An account with this email address already exists. Please sign in instead.';
      case 'operation-not-allowed':
        if (exception.message?.contains('SMS') == true ||
            exception.message?.contains('region') == true) {
          return 'Phone Authentication is restricted by SMS Region Policy. Enable Phone Sign-In and your region (e.g. Pakistan +92) in Firebase Console under Authentication > Settings > SMS Region Policy.';
        }
        return 'This authentication method is currently disabled. Please enable it in Firebase Console under Authentication > Sign-in method.';
      case 'invalid-phone-number':
        return 'The phone number is invalid. Please enter a valid number with country code (e.g. +92 300 1234567).';
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'Device verification failed. Ensure SHA-1 and SHA-256 fingerprints are added in Firebase Project Settings.';
      case 'invalid-verification-code':
        return 'The SMS OTP code entered is incorrect. Please verify and try again.';
      case 'session-expired':
        return 'The verification code has expired. Please tap resend to request a new code.';
      case 'weak-password':
        return 'The password is too weak. Please choose a password with at least 8 characters including numbers and symbols.';
      case 'network-request-failed':
        return 'Network connection issue. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few moments before trying again.';
      case 'requires-recent-login':
        return 'For your security, please sign in again before completing this action.';
      case 'expired-action-code':
        return 'The verification or reset link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'The verification or reset link is invalid or has already been used.';
      case 'user-token-expired':
        return 'Your session has expired. Please sign in again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for today. Please try again tomorrow.';
      default:
        return exception.message ?? 'An unexpected authentication error occurred. Please try again.';
    }
  }

  static String mapGeneralException(Object error) {
    if (error is FirebaseAuthException) {
      return mapFirebaseAuthException(error);
    }
    final message = error.toString();
    if (message.contains('12501') ||
        message.contains('canceled') ||
        message.contains('cancelled') ||
        message.contains('sign_in_canceled')) {
      return 'Google sign-in was canceled.';
    }
    if (message.contains('12500') ||
        message.contains('sign_in_failed') ||
        message.contains('ApiException')) {
      return 'Google Sign-In failed (Error 12500). Ensure SHA-1 fingerprint is registered and Google Sign-In is enabled with support email in Firebase Console.';
    }
    if (message.contains('SocketException') || message.contains('HandshakeException')) {
      return 'Network error: Please check your internet connection and try again.';
    }
    return message.replaceFirst(RegExp(r'^Exception: '), '');
  }
}
