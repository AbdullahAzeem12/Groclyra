import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';

/// Central place for security-sensitive operations backed by Groclyra SQL Database.
class AppSecurityService {
  final AppDatabase _database;

  AppSecurityService({
    dynamic firestore, // Kept dynamic for legacy test compatibility
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get currentUserUid => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────────────
  // AUDIT TRAIL
  // ─────────────────────────────────────────────────────────────────────────

  /// Appends an audit entry into SQLite system_telemetry.
  Future<void> logSecurityEvent({
    required String action,
    required String actorUid,
    required Map<String, dynamic> details,
  }) async {
    try {
      final id = 'sec_${DateTime.now().millisecondsSinceEpoch}_${action.hashCode.abs()}';
      await _database.insertOrReplace('system_telemetry', {
        'id': id,
        'metricName': action,
        'metricValue': 1.0,
        'tagsJson': jsonEncode({
          'action': action,
          'actorUid': actorUid,
          'actorIsClient': true,
          'details': details,
        }),
        'recordedAt': DateTime.now().toIso8601String(),
      });
      _database.notifyTable('system_telemetry');
    } catch (e) {
      debugPrint('AppSecurityService.logSecurityEvent notice: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAYMENT VERIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  static const bool kServerVerificationAvailable = false;

  // ─────────────────────────────────────────────────────────────────────────
  // ROLE / KYC GUARDS
  // ─────────────────────────────────────────────────────────────────────────

  /// Reads signed-in user's role from SQLite users table.
  Future<String?> readUserRole() async {
    final uid = currentUserUid;
    if (uid == null) return null;
    try {
      final rows = await _database.query(
        'users',
        where: 'id = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['role'] as String?;
      }
      return null;
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
