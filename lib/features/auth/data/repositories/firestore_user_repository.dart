import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/user_entity.dart';

class FirestoreUserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Fetches the user profile document for a given UID
  Future<UserEntity?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return UserEntity.fromFirestore(doc.data()!, uid);
    } catch (e) {
      return null;
    }
  }

  /// Looks up a user profile by email address across the users collection
  Future<UserEntity?> findUserByEmail(String email) async {
    try {
      final query = await _usersCollection
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        // Also check case-insensitive match by raw email
        final rawQuery = await _usersCollection
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();
        if (rawQuery.docs.isEmpty) return null;
        return UserEntity.fromFirestore(rawQuery.docs.first.data(), rawQuery.docs.first.id);
      }
      return UserEntity.fromFirestore(query.docs.first.data(), query.docs.first.id);
    } catch (_) {
      return null;
    }
  }

  /// Fetches paginated users based on role
  Future<List<UserEntity>> getUsersByRole(UserRole role, {int limit = 20, DocumentSnapshot? startAfter}) async {
    try {
      var query = _usersCollection
          .where('role', isEqualTo: role.name)
          .orderBy('createdAt', descending: true)
          .limit(limit);
          
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => UserEntity.fromFirestore(doc.data(), doc.id)).toList();
    } catch (_) {
      return [];
    }
  }



  /// Looks up a user profile by phone number across the users collection
  Future<UserEntity?> findUserByPhone(String phone) async {
    try {
      final cleanPhone = phone.trim();
      final query = await _usersCollection
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return UserEntity.fromFirestore(query.docs.first.data(), query.docs.first.id);
    } catch (_) {
      return null;
    }
  }

  /// Creates a primary user record and role-specific profile document
  Future<void> createUserProfile({
    required UserEntity user,
    Map<String, dynamic>? additionalRoleData,
  }) async {
    // 1. Primary user doc in 'users/{uid}'
    final userDocRef = _usersCollection.doc(user.id);
    await userDocRef.set(user.toFirestore(), SetOptions(merge: true));

    // 2. Role-specific collection documents (both profile and plural collections for complete segmentation)
    final roleCollectionName = _getRoleCollectionName(user.role);
    final roleDocRef = _firestore.collection(roleCollectionName).doc(user.id);

    final roleAliasName = _getRoleCollectionAlias(user.role);
    final aliasDocRef = _firestore.collection(roleAliasName).doc(user.id);

    final roleData = <String, dynamic>{
      'uid': user.id,
      'displayName': user.name,
      'email': user.email,
      'phone': user.phone,
      'role': user.role.name,
      'createdAt': user.createdAt.toIso8601String(),
      'accountStatus': user.accountStatus.name,
      ...?additionalRoleData,
    };

    if (user.role == UserRole.seller && user.storeName != null) {
      roleData['storeName'] = user.storeName;
      roleData['businessCategory'] = user.businessCategory;
    } else if (user.role == UserRole.rider && user.vehicleNumber != null) {
      roleData['vehicleNumber'] = user.vehicleNumber;
      roleData['deliveryZone'] = user.deliveryZone;
      if (user.cnicNumber != null) roleData['cnicNumber'] = user.cnicNumber;
      if (user.drivingLicenseNumber != null) {
        roleData['drivingLicenseNumber'] = user.drivingLicenseNumber;
      }
    } else if (user.role == UserRole.admin) {
      if (user.adminDepartment != null) {
        roleData['adminDepartment'] = user.adminDepartment;
      }
      if (user.adminId != null) {
        roleData['adminId'] = user.adminId;
      }
    }

    // Set role-specific profile document
    await roleDocRef.set(roleData, SetOptions(merge: true));

    // Set alias collection document
    try {
      await aliasDocRef.set(roleData, SetOptions(merge: true));
    } catch (_) {
      // Alias is complementary; do not fail registration if alias fails
    }
  }

  /// Verifies if user belongs to the designated role's segmented collection
  Future<bool> verifyUserInRoleSegment({
    required String uid,
    required UserRole role,
  }) async {
    try {
      final doc = await _firestore.collection(_getRoleCollectionName(role)).doc(uid).get();
      if (doc.exists) return true;

      final aliasDoc = await _firestore.collection(_getRoleCollectionAlias(role)).doc(uid).get();
      return aliasDoc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Finds which role segmented collection the user belongs to
  Future<UserRole?> findUserRoleAcrossSegments(String uid) async {
    for (final role in UserRole.values) {
      if (await verifyUserInRoleSegment(uid: uid, role: role)) {
        return role;
      }
    }
    return null;
  }

  /// Updates specific user fields
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Updates account status (active, pending, suspended, disabled)
  Future<void> updateAccountStatus(String uid, AccountStatus status) async {
    await updateUser(uid, {'accountStatus': status.name});
  }

  /// Updates email verified flag
  Future<void> updateEmailVerification(String uid, bool verified) async {
    await updateUser(uid, {'emailVerified': verified, 'isVerified': verified});
  }

  /// Updates a user's profile details including photo
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
      updates['displayName'] = newName; // for role-specific collections
    }
    
    if (newPhone != null && newPhone != user.phone) {
      updates['phone'] = newPhone;
    }
    
    if (newProfileImageBase64 != null) {
      updates['profileImageBase64'] = newProfileImageBase64;
    }

    if (updates.length > 1) { // more than just updatedAt
      // Update primary user doc
      await _usersCollection.doc(user.id).set(updates, SetOptions(merge: true));

      // Update role-specific docs
      final roleCollectionName = _getRoleCollectionName(user.role);
      await _firestore.collection(roleCollectionName).doc(user.id).set(updates, SetOptions(merge: true));

      final roleAliasName = _getRoleCollectionAlias(user.role);
      try {
        await _firestore.collection(roleAliasName).doc(user.id).set(updates, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Real-time stream of the user profile document
  Stream<UserEntity?> streamUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserEntity.fromFirestore(snapshot.data()!, uid);
    });
  }

  String _getRoleCollectionName(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'customerProfiles';
      case UserRole.seller:
        return 'sellerProfiles';
      case UserRole.rider:
        return 'riderProfiles';
      case UserRole.admin:
        return 'adminProfiles';
    }
  }

  String _getRoleCollectionAlias(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'customers';
      case UserRole.seller:
        return 'sellers';
      case UserRole.rider:
        return 'riders';
      case UserRole.admin:
        return 'admins';
    }
  }
}

final firestoreUserRepositoryProvider =
    Provider<FirestoreUserRepository>((ref) {
  return FirestoreUserRepository();
});

final userStreamProvider =
    StreamProvider.autoDispose.family<UserEntity?, String>((ref, uid) {
  final repo = ref.watch(firestoreUserRepositoryProvider);
  return repo.streamUser(uid);
});

