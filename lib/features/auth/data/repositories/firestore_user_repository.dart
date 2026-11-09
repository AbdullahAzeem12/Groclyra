import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/user_entity.dart';

/// SQL-backed UserRepository (SQLite) maintaining full backward compatibility
/// with previous Firestore interface and Riverpod providers.
class FirestoreUserRepository {
  final AppDatabase _database;

  FirestoreUserRepository({
    dynamic firestore, // Kept dynamic for backward compatibility with legacy test callers
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  /// Fetches the user profile document for a given UID from SQLite
  Future<UserEntity?> getUser(String uid) async {
    try {
      final rows = await _database.query(
        'users',
        where: 'id = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return _userFromRow(rows.first);
    } catch (e) {
      return null;
    }
  }

  /// Looks up a user profile by email address across the users table in SQLite
  Future<UserEntity?> findUserByEmail(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final rows = await _database.query(
        'users',
        where: 'LOWER(email) = ?',
        whereArgs: [cleanEmail],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _userFromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  /// Fetches paginated users based on role from SQLite
  Future<List<UserEntity>> getUsersByRole(
    UserRole role, {
    int limit = 20,
    dynamic startAfter,
  }) async {
    try {
      final rows = await _database.query(
        'users',
        where: 'role = ?',
        whereArgs: [role.name],
        orderBy: 'createdAt DESC',
        limit: limit,
      );
      return rows.map(_userFromRow).whereType<UserEntity>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Looks up a user profile by phone number across the users table in SQLite
  Future<UserEntity?> findUserByPhone(String phone) async {
    try {
      final cleanPhone = phone.trim();
      final rows = await _database.query(
        'users',
        where: 'phone = ?',
        whereArgs: [cleanPhone],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _userFromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  /// Creates a primary user record and role-specific profile document in SQLite
  Future<void> createUserProfile({
    required UserEntity user,
    Map<String, dynamic>? additionalRoleData,
    String? passwordHash,
    String? oauthProvider,
  }) async {
    final now = DateTime.now().toIso8601String();
    final rawMap = user.toFirestore();
    if (additionalRoleData != null) {
      rawMap.addAll(additionalRoleData);
    }

    final userRow = <String, dynamic>{
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'role': user.role.name,
      'accountStatus': user.accountStatus.name,
      'photoUrl': user.avatarUrl,
      'vehicleNumber': user.vehicleNumber,
      'licenseNumber': user.drivingLicenseNumber,
      'fcmToken': null,
      'passwordHash': passwordHash,
      'oauthProvider': oauthProvider ?? 'password',
      'isOnline': 1,
      'deliveryAddress': user.deliveryAddress,
      'deliveryZone': user.deliveryZone,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': now,
    };

    await _database.insertOrReplace('users', userRow);

    // Save into role-specific tables in SQLite
    if (user.role == UserRole.seller) {
      await _database.insertOrReplace('seller_profiles', {
        'sellerId': user.id,
        'storeName': user.storeName ?? user.name,
        'businessCategory': user.businessCategory ?? 'Grocery & Crockery',
        'ownerName': user.name,
        'phone': user.phone,
        'address': user.deliveryAddress ?? 'Registered Hub Warehouse',
        'isKycApproved': user.accountStatus == AccountStatus.active ? 1 : 0,
        'updatedAt': now,
      });
      _database.notifyTable('seller_profiles');
    } else if (user.role == UserRole.rider) {
      await _database.insertOrReplace('rider_profiles', {
        'riderId': user.id,
        'name': user.name,
        'phone': user.phone,
        'vehicleNumber': user.vehicleNumber ?? 'KHI-0000',
        'deliveryZone': user.deliveryZone ?? 'Karachi',
        'isKycApproved': user.accountStatus == AccountStatus.active ? 1 : 0,
        'updatedAt': now,
      });
      _database.notifyTable('rider_profiles');
    }

    _database.notifyTable('users');
  }

  /// Verifies if user belongs to the designated role's segmented table in SQLite
  Future<bool> verifyUserInRoleSegment({
    required String uid,
    required UserRole role,
  }) async {
    try {
      final rows = await _database.query(
        'users',
        where: 'id = ? AND role = ?',
        whereArgs: [uid, role.name],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Finds which role segmented collection the user belongs to
  Future<UserRole?> findUserRoleAcrossSegments(String uid) async {
    final user = await getUser(uid);
    return user?.role;
  }

  /// Retrieves the stored password hash for the user from SQLite
  Future<String?> getPasswordHash(String uid) async {
    try {
      final rows = await _database.query(
        'users',
        columns: ['passwordHash'],
        where: 'id = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['passwordHash'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves the OAuth provider (e.g. 'google', 'password') from SQLite
  Future<String?> getOauthProvider(String uid) async {
    try {
      final rows = await _database.query(
        'users',
        columns: ['oauthProvider'],
        where: 'id = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['oauthProvider'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Updates specific user fields in SQLite
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      final rows = await _database.query('users', where: 'id = ?', whereArgs: [uid], limit: 1);
      if (rows.isNotEmpty) {
        final existing = Map<String, dynamic>.from(rows.first);
        existing.addAll(data);
        existing['updatedAt'] = DateTime.now().toIso8601String();

        await _database.update(
          'users',
          existing,
          where: 'id = ?',
          whereArgs: [uid],
        );
        _database.notifyTable('users');
      }
    } catch (_) {}
  }

  /// Updates account status (active, pending, suspended, disabled) in SQLite
  Future<void> updateAccountStatus(String uid, AccountStatus status) async {
    await updateUser(uid, {'accountStatus': status.name});
    try {
      await _database.update(
        'seller_profiles',
        {
          'isKycApproved': status == AccountStatus.active ? 1 : 0,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'sellerId = ?',
        whereArgs: [uid],
      );
      _database.notifyTable('seller_profiles');
    } catch (_) {}
    try {
      await _database.update(
        'rider_profiles',
        {
          'isKycApproved': status == AccountStatus.active ? 1 : 0,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'riderId = ?',
        whereArgs: [uid],
      );
      _database.notifyTable('rider_profiles');
    } catch (_) {}
  }

  /// Updates email verified flag in SQLite
  Future<void> updateEmailVerification(String uid, bool verified) async {
    await updateUser(uid, {'emailVerified': verified ? 1 : 0, 'isVerified': verified ? 1 : 0});
  }

  /// Updates a user's profile details including photo in SQLite
  Future<void> updateUserProfile(
    UserEntity user, {
    String? newName,
    String? newPhone,
    String? newProfileImageBase64,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (newName != null && newName != user.name) {
      updates['name'] = newName;
    }

    if (newPhone != null && newPhone != user.phone) {
      updates['phone'] = newPhone;
    }

    if (newProfileImageBase64 != null) {
      updates['photoUrl'] = newProfileImageBase64;
    }

    if (updates.length > 1) {
      await updateUser(user.id, updates);
    }
  }

  /// Real-time stream of the user profile document from SQLite
  Stream<UserEntity?> streamUser(String uid) async* {
    yield await getUser(uid);

    yield* _database.watchTable('users').asyncMap((_) async {
      return await getUser(uid);
    });
  }

  UserEntity? _userFromRow(Map<String, dynamic> row) {
    try {
      return UserEntity(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        email: row['email'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        role: UserRole.fromString(row['role'] as String?),
        avatarUrl: row['photoUrl'] as String?,
        profileImageBase64: row['photoUrl'] as String?,
        isVerified: true,
        emailVerified: true,
        accountStatus: AccountStatus.fromString(row['accountStatus'] as String?),
        profileCompleted: true,
        createdAt: DateTime.tryParse(row['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: row['updatedAt'] != null ? DateTime.tryParse(row['updatedAt']!.toString()) : null,
        vehicleNumber: row['vehicleNumber'] as String?,
        deliveryZone: row['deliveryZone'] as String?,
        deliveryAddress: row['deliveryAddress'] as String?,
        drivingLicenseNumber: row['licenseNumber'] as String?,
      );
    } catch (e) {
      return null;
    }
  }
}

final firestoreUserRepositoryProvider = Provider<FirestoreUserRepository>((ref) {
  return FirestoreUserRepository();
});

final userStreamProvider =
    StreamProvider.autoDispose.family<UserEntity?, String>((ref, uid) {
  final repo = ref.watch(firestoreUserRepositoryProvider);
  return repo.streamUser(uid);
});
