import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/customer/addresses/domain/entities/delivery_address_entity.dart';
import 'package:groclyra/features/customer/addresses/domain/services/delivery_serviceability_engine.dart';

class AddressRepository {
  final FirebaseFirestore? _explicitFirestore;
  final List<DeliveryAddressEntity> _localMemoryCache = [];
  final StreamController<List<DeliveryAddressEntity>> _localStreamController =
      StreamController<List<DeliveryAddressEntity>>.broadcast();

  AddressRepository({FirebaseFirestore? firestore})
      : _explicitFirestore = firestore;

  FirebaseFirestore? get _firestore {
    if (_explicitFirestore != null) return _explicitFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String _resolveEffectiveUserId(String requestedUserId) {
    if (requestedUserId.isNotEmpty && requestedUserId != 'usr_guest') {
      return requestedUserId;
    }
    try {
      final fbUid = FirebaseAuth.instance.currentUser?.uid;
      if (fbUid != null && fbUid.isNotEmpty) {
        return fbUid;
      }
    } catch (_) {}
    return requestedUserId.isNotEmpty ? requestedUserId : 'usr_guest';
  }

  /// Real-time stream of all saved delivery addresses for the user.
  /// Does NOT use composite indexes, avoiding any index failure in Firestore.
  Stream<List<DeliveryAddressEntity>> streamAddresses(String userId) async* {
    final effectiveUserId = _resolveEffectiveUserId(userId);
    yield List<DeliveryAddressEntity>.unmodifiable(_localMemoryCache);

    if (effectiveUserId.isEmpty || effectiveUserId == 'usr_guest' || _firestore == null) {
      yield* _localStreamController.stream;
      return;
    }

    try {
      yield* _firestore!
          .collection('users')
          .doc(effectiveUserId)
          .collection('addresses')
          .snapshots()
          .map<List<DeliveryAddressEntity>>((snap) {
        final list = snap.docs
            .map((doc) => DeliveryAddressEntity.fromMap(doc.data(), doc.id))
            .toList();

        // Sort in memory: Default address first, then newest createdAt first
        list.sort((a, b) {
          if (a.isDefault != b.isDefault) {
            return a.isDefault ? -1 : 1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });

        _localMemoryCache.clear();
        _localMemoryCache.addAll(list);
        return List<DeliveryAddressEntity>.unmodifiable(list);
      }).handleError((error) {
        debugPrint('[AddressRepository] streamAddresses error handled: $error');
        return List<DeliveryAddressEntity>.unmodifiable(_localMemoryCache);
      });
    } catch (e) {
      debugPrint('[AddressRepository] streamAddresses query setup error: $e');
      yield* _localStreamController.stream;
    }
  }

  /// Save or update an address in Firestore with exact coordinates and words
  Future<void> saveAddress(DeliveryAddressEntity address) async {
    final effectiveUserId = _resolveEffectiveUserId(address.userId);

    // 1. Calculate live serviceability for Pakistan pin point
    final serviceability = DeliveryServiceabilityEngine.checkServiceability(
      latitude: address.latitude,
      longitude: address.longitude,
      city: address.city,
    );

    // If first address ever saved, make it default automatically
    final makeDefault = address.isDefault || _localMemoryCache.isEmpty;

    final validatedAddress = address.copyWith(
      userId: effectiveUserId,
      isDefault: makeDefault,
      serviceabilityStatus: serviceability,
      updatedAt: DateTime.now(),
    );

    // 2. Update local memory cache and broadcast immediately
    if (makeDefault) {
      for (int i = 0; i < _localMemoryCache.length; i++) {
        _localMemoryCache[i] = _localMemoryCache[i].copyWith(isDefault: false);
      }
    }
    final idx = _localMemoryCache.indexWhere((a) => a.id == validatedAddress.id);
    if (idx >= 0) {
      _localMemoryCache[idx] = validatedAddress;
    } else {
      _localMemoryCache.insert(0, validatedAddress);
    }
    _localStreamController.add(List<DeliveryAddressEntity>.unmodifiable(_localMemoryCache));

    // 3. Persist to Firestore: subcollection first, then root user doc
    if (_firestore != null && effectiveUserId.isNotEmpty && effectiveUserId != 'usr_guest') {
      try {
        final userDocRef = _firestore!.collection('users').doc(effectiveUserId);
        final addressCol = userDocRef.collection('addresses');

        // Write address to subcollection with full map including city and cityOrTown
        await addressCol.doc(validatedAddress.id).set(
          validatedAddress.toMap(),
          SetOptions(merge: true),
        );
        debugPrint('[AddressRepository] Subcollection write OK: ${validatedAddress.id} -> ${validatedAddress.formattedAddress}');

        // If this address is default, reset others in Firestore
        if (makeDefault) {
          final snap = await addressCol.where('isDefault', isEqualTo: true).get();
          if (snap.docs.isNotEmpty) {
            final batch = _firestore!.batch();
            for (final doc in snap.docs) {
              if (doc.id != validatedAddress.id) {
                batch.update(doc.reference, {'isDefault': false});
              }
            }
            await batch.commit();
          }

          // Sync full details, location coordinates & formatted address in words to user root doc
          try {
            await userDocRef.set(
              {
                'deliveryAddress': validatedAddress.formattedAddress,
                'deliveryZone': validatedAddress.city,
                'deliveryLocation': {
                  'latitude': validatedAddress.latitude,
                  'longitude': validatedAddress.longitude,
                  'source': 'map',
                  'formattedAddress': validatedAddress.formattedAddress,
                },
                'deliveryAddressDetails': validatedAddress.toMap(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
            debugPrint('[AddressRepository] User root doc synced with deliveryAddress');
          } catch (userErr) {
            debugPrint('[AddressRepository] Warning syncing user root doc: $userErr');
          }
        }
      } catch (e) {
        debugPrint('[AddressRepository] saveAddress Firestore write error: $e');
        rethrow;
      }
    }
  }

  /// Mark an address as default
  Future<void> setDefaultAddress(String userId, String addressId) async {
    final effectiveUserId = _resolveEffectiveUserId(userId);

    DeliveryAddressEntity? chosen;
    for (int i = 0; i < _localMemoryCache.length; i++) {
      if (_localMemoryCache[i].id == addressId) {
        _localMemoryCache[i] = _localMemoryCache[i].copyWith(isDefault: true);
        chosen = _localMemoryCache[i];
      } else {
        _localMemoryCache[i] = _localMemoryCache[i].copyWith(isDefault: false);
      }
    }
    _localStreamController.add(List<DeliveryAddressEntity>.unmodifiable(_localMemoryCache));

    if (effectiveUserId.isNotEmpty && effectiveUserId != 'usr_guest' && chosen != null && _firestore != null) {
      try {
        final userDocRef = _firestore!.collection('users').doc(effectiveUserId);
        final collection = userDocRef.collection('addresses');
        final snap = await collection.get();
        final batch = _firestore!.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'isDefault': doc.id == addressId});
        }
        await batch.commit();

        try {
          await userDocRef.set(
            {
              'deliveryAddress': chosen.formattedAddress,
              'deliveryZone': chosen.city,
              'deliveryLocation': {
                'latitude': chosen.latitude,
                'longitude': chosen.longitude,
                'source': 'map',
                'formattedAddress': chosen.formattedAddress,
              },
              'deliveryAddressDetails': chosen.toMap(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (_) {}
      } catch (e) {
        debugPrint('[AddressRepository] setDefaultAddress error: $e');
      }
    }
  }

  /// Delete an address
  Future<void> deleteAddress(String userId, String addressId) async {
    final effectiveUserId = _resolveEffectiveUserId(userId);
    _localMemoryCache.removeWhere((a) => a.id == addressId);
    _localStreamController.add(List<DeliveryAddressEntity>.unmodifiable(_localMemoryCache));

    if (effectiveUserId.isNotEmpty && effectiveUserId != 'usr_guest' && _firestore != null) {
      try {
        await _firestore!
            .collection('users')
            .doc(effectiveUserId)
            .collection('addresses')
            .doc(addressId)
            .delete();
      } catch (e) {
        debugPrint('[AddressRepository] deleteAddress error: $e');
      }
    }
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository();
});
