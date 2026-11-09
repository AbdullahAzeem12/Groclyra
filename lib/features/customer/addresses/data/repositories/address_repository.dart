import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/features/customer/addresses/domain/entities/delivery_address_entity.dart';
import 'package:groclyra/features/customer/addresses/domain/services/delivery_serviceability_engine.dart';

/// Groclyra SQL-backed AddressRepository (SQLite)
class AddressRepository {
  final AppDatabase _database;
  final List<DeliveryAddressEntity> _localMemoryCache = [];
  final StreamController<List<DeliveryAddressEntity>> _localStreamController =
      StreamController<List<DeliveryAddressEntity>>.broadcast();

  AddressRepository({dynamic firestore, AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  String _resolveEffectiveUserId(String requestedUserId) {
    if (requestedUserId.isNotEmpty && requestedUserId != 'usr_guest') {
      return requestedUserId;
    }
    final activeId = AppDatabase.instance.activeSessionUserId;
    if (activeId != null && activeId.isNotEmpty) {
      return activeId;
    }
    return requestedUserId.isNotEmpty ? requestedUserId : 'usr_guest';
  }

  /// Real-time stream of all saved delivery addresses for the user from SQLite.
  Stream<List<DeliveryAddressEntity>> streamAddresses(String userId) async* {
    final effectiveUserId = _resolveEffectiveUserId(userId);
    yield await getAddresses(effectiveUserId);

    yield* _database.watchTable('addresses').asyncMap((_) async {
      return await getAddresses(effectiveUserId);
    });
  }

  /// One-shot fetch of addresses for user from SQLite
  Future<List<DeliveryAddressEntity>> getAddresses(String userId) async {
    final effectiveUserId = _resolveEffectiveUserId(userId);
    try {
      final rows = await _database.query(
        'addresses',
        where: 'userId = ?',
        whereArgs: [effectiveUserId],
        orderBy: 'isDefault DESC, createdAt DESC',
      );

      final list = rows.map(_addressFromRow).whereType<DeliveryAddressEntity>().toList();

      list.sort((a, b) {
        if (a.isDefault != b.isDefault) {
          return a.isDefault ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      _localMemoryCache.clear();
      _localMemoryCache.addAll(list);
      _localStreamController.add(List<DeliveryAddressEntity>.unmodifiable(_localMemoryCache));
      return List<DeliveryAddressEntity>.unmodifiable(list);
    } catch (e) {
      debugPrint('[AddressRepository] getAddresses error: $e');
      return List<DeliveryAddressEntity>.unmodifiable(_localMemoryCache);
    }
  }

  /// Save or update an address in SQLite with exact coordinates and words
  Future<void> saveAddress(DeliveryAddressEntity address) async {
    final effectiveUserId = _resolveEffectiveUserId(address.userId);

    // 1. Calculate live serviceability for Pakistan pin point
    final serviceability = DeliveryServiceabilityEngine.checkServiceability(
      latitude: address.latitude,
      longitude: address.longitude,
      city: address.city,
    );

    // If first address ever saved, make it default automatically
    final existingList = await getAddresses(effectiveUserId);
    final makeDefault = address.isDefault || existingList.isEmpty;

    final validatedAddress = address.copyWith(
      userId: effectiveUserId,
      isDefault: makeDefault,
      serviceabilityStatus: serviceability,
      updatedAt: DateTime.now(),
    );

    // 2. If this address is default, reset others in SQLite
    if (makeDefault) {
      await _database.update(
        'addresses',
        {'isDefault': 0},
        where: 'userId = ?',
        whereArgs: [effectiveUserId],
      );
    }

    // 3. Persist to SQLite
    final map = validatedAddress.toMap();
    final row = <String, dynamic>{
      'id': validatedAddress.id,
      'userId': effectiveUserId,
      'label': validatedAddress.label.name,
      'recipientName': validatedAddress.recipientName,
      'recipientPhone': validatedAddress.recipientPhone,
      'provinceOrTerritory': validatedAddress.provinceOrTerritory,
      'district': validatedAddress.district,
      'city': validatedAddress.city,
      'locality': validatedAddress.locality,
      'societyOrScheme': validatedAddress.societyOrScheme,
      'sectorOrBlock': validatedAddress.sectorOrBlock,
      'street': validatedAddress.street,
      'houseOrFlat': validatedAddress.houseOrFlat,
      'landmark': validatedAddress.landmark,
      'deliveryInstructions': validatedAddress.deliveryInstructions,
      'formattedAddress': validatedAddress.formattedAddress,
      'latitude': validatedAddress.latitude,
      'longitude': validatedAddress.longitude,
      'isDefault': makeDefault ? 1 : 0,
      'serviceabilityStatus': validatedAddress.serviceabilityStatus.name,
      'createdAt': validatedAddress.createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'fullDataJson': jsonEncode(map),
    };

    await _database.insertOrReplace('addresses', row);

    // Update in-memory list
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

    // Also sync to user root record in SQLite
    if (makeDefault) {
      await _database.update(
        'users',
        {
          'deliveryAddress': validatedAddress.formattedAddress,
          'deliveryZone': validatedAddress.city,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [effectiveUserId],
      );
      _database.notifyTable('users');
    }

    _database.notifyTable('addresses');
  }

  /// Mark an address as default in SQLite
  Future<void> setDefaultAddress(String userId, String addressId) async {
    final effectiveUserId = _resolveEffectiveUserId(userId);

    await _database.update(
      'addresses',
      {'isDefault': 0},
      where: 'userId = ?',
      whereArgs: [effectiveUserId],
    );

    await _database.update(
      'addresses',
      {'isDefault': 1},
      where: 'id = ? AND userId = ?',
      whereArgs: [addressId, effectiveUserId],
    );

    final addresses = await getAddresses(effectiveUserId);
    final chosen = addresses.where((a) => a.id == addressId).firstOrNull;
    if (chosen != null) {
      await _database.update(
        'users',
        {
          'deliveryAddress': chosen.formattedAddress,
          'deliveryZone': chosen.city,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [effectiveUserId],
      );
      _database.notifyTable('users');
    }

    _database.notifyTable('addresses');
  }

  /// Delete an address from SQLite
  Future<void> deleteAddress(String userId, String addressId) async {
    final effectiveUserId = _resolveEffectiveUserId(userId);
    _localMemoryCache.removeWhere((a) => a.id == addressId);
    _localStreamController.add(List<DeliveryAddressEntity>.unmodifiable(_localMemoryCache));

    await _database.delete(
      'addresses',
      where: 'id = ? AND userId = ?',
      whereArgs: [addressId, effectiveUserId],
    );

    _database.notifyTable('addresses');
  }

  DeliveryAddressEntity? _addressFromRow(Map<String, dynamic> row) {
    try {
      final isDefaultCol = (row['isDefault'] is int
          ? (row['isDefault'] as int) == 1
          : (row['isDefault'] as bool? ?? false));
      final fullJson = row['fullDataJson'] as String?;
      if (fullJson != null && fullJson.isNotEmpty) {
        final map = jsonDecode(fullJson) as Map<String, dynamic>;
        final entity = DeliveryAddressEntity.fromMap(map, row['id'] as String);
        return entity.copyWith(isDefault: isDefaultCol);
      }
      final entity = DeliveryAddressEntity.fromMap(row, row['id'] as String);
      return entity.copyWith(isDefault: isDefaultCol);
    } catch (e) {
      debugPrint('_addressFromRow parse error: $e');
      return null;
    }
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository();
});
