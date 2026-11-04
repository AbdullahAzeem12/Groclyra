import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central place for security-sensitive, *server-hostile* operations.
///
/// Today the app talks to Firestore directly from the client. Several
/// operations (payment verification, KYC approvals, role changes, COD
/// reconciliation) should eventually move behind trusted infrastructure —
/// Firebase Cloud Functions or a backend proxy — because anything a client
/// can compute can be forged.
///
/// This service is the drop-in seam for that migration: every call site uses
/// these methods instead of touching Firestore/FireAuth directly, so the
/// underlying implementation can switch from "client writes" to "Cloud
/// Function call" with zero refactor of feature code.
///
/// Phase 1 implementation keeps the current client-side behaviour (so every
/// existing flow keeps working) but funnels privilege through this class and
/// adds guardrails + audit logging that will hold up when the server side
/// lands.
class AppSecurityService {
  AppSecurityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  FirebaseAuth get _auth => FirebaseAuth.instance;

 String? get currentUserUid => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────────────
  // AUDIT TRAIL
  // ─────────────────────────────────────────────────────────────────────────

  /// Appends an audit entry for any privileged action performed from this
  /// device. Call sites stage these locally; once Cloud Functions exist the
  /// same payload shape moves server-side.
  Future<void> logSecurityEvent({
    required String action,
    required String actorUid,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _firestore.collection('adminAuditLogs').add({
        'action': action,
        'actorUid': actorUid,
        'actorIsClient': true,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Never let logging break the guarded operation itself.
      debugPrint('AppSecurityService.logSecurityEvent notice: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAYMENT VERIFICATION (future: callable Cloud Function)
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether a trusted (server-side) payment verification worker is active.
  /// Until the backend proxy ships, the client-side `PaymentService` flow
  /// remains in charge — but the caller can branch on this flag so the
  /// upgrade path requires no new call sites.
  static const bool kServerVerificationAvailable = false;

  // ─────────────────────────────────────────────────────────────────────────
  // ROLE / KYC GUARDS (future: custom claims)
  // ─────────────────────────────────────────────────────────────────────────

  /// Reads the signed-in user's role from the Firestore profile. Used by
  /// guards that must double-check server state before showing privileged
  /// UI (defence-in-depth in addition to router guards).
  Future<String?> readUserRole() async {
    final uid = currentUserUid;
    if (uid == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['role'] as String?;
    } catch (e) {
      debugPrint('AppSecurityService.readUserRole error: $e');
      return null;
    }
  }

  Future<String?> verifySelfRole({
    required String expectedRole,
    required String action,
  }) async {
    final uid = currentUserUid;
    final role = await readUserRole();
    if (uid == null || role != expectedRole) {
      await logSecurityEvent(
        action: '$action (role mismatch)',
        actorUid: uid ?? 'unauthenticated',
        details: {
          'expected': expectedRole,
          'actual': role ?? 'null',
        },
      );
      return null;
    }
    return uid;
  }
}

final appSecurityServiceProvider = Provider<AppSecurityService>((ref) {
  return AppSecurityService();
});
