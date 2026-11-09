import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/address_repository.dart';
import '../../domain/entities/delivery_address_entity.dart';

class AddressState {
  final List<DeliveryAddressEntity> addresses;
  final DeliveryAddressEntity? defaultAddress;
  final bool isLoading;
  final String? errorMessage;
  final String activeUserId;

  const AddressState({
    this.addresses = const [],
    this.defaultAddress,
    this.isLoading = false,
    this.errorMessage,
    this.activeUserId = '',
  });

  AddressState copyWith({
    List<DeliveryAddressEntity>? addresses,
    DeliveryAddressEntity? defaultAddress,
    bool? isLoading,
    String? errorMessage,
    String? activeUserId,
    bool clearDefault = false,
    bool clearError = false,
  }) {
    return AddressState(
      addresses: addresses ?? this.addresses,
      defaultAddress: clearDefault ? null : (defaultAddress ?? this.defaultAddress),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activeUserId: activeUserId ?? this.activeUserId,
    );
  }
}

class AddressController extends StateNotifier<AddressState> {
  final AddressRepository _repository;

  /// StreamSubscription for the SQLite address table
  StreamSubscription<List<DeliveryAddressEntity>>? _addressSub;

  AddressController(this._repository, {String? initialUserId, dynamic firebaseAuth})
      : super(const AddressState(isLoading: true)) {
    final currentUid = initialUserId ?? AppDatabase.instance.activeSessionUserId ?? '';
    if (currentUid.isNotEmpty) {
      _reInitStream(currentUid);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void updateActiveUser(String? uid) {
    final effectiveUid = uid ?? AppDatabase.instance.activeSessionUserId ?? '';
    if (effectiveUid == state.activeUserId && _addressSub != null) return;
    debugPrint('[AddressController] User changed → uid=$effectiveUid. Re-initializing address stream.');
    _reInitStream(effectiveUid);
  }

  void _reInitStream(String uid) {
    _addressSub?.cancel();
    _addressSub = null;

    // Retain existing addresses during re-initialization so UI never blinks or clears
    state = state.copyWith(
      isLoading: state.addresses.isEmpty,
      activeUserId: uid,
    );

    if (uid.isEmpty) return;

    _addressSub = _repository.streamAddresses(uid).listen(
      (list) {
        if (!mounted) return;
        final merged = List<DeliveryAddressEntity>.from(list);
        for (final item in state.addresses) {
          if (item.userId == uid && !merged.any((a) => a.id == item.id)) {
            merged.add(item);
          }
        }
        final defaultAddr = merged.cast<DeliveryAddressEntity?>().firstWhere(
              (a) => a?.isDefault == true,
              orElse: () => merged.isNotEmpty ? merged.first : null,
            );
        state = state.copyWith(
          addresses: merged,
          defaultAddress: defaultAddr,
          isLoading: false,
          clearError: true,
        );
        debugPrint('[AddressController] Stream update: ${merged.length} addresses for uid=$uid');
      },
      onError: (dynamic e) {
        if (!mounted) return;
        debugPrint('[AddressController] Stream error: $e');
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      },
    );
  }

  String _resolveUserId([String? passedUid]) {
    if (passedUid != null && passedUid.isNotEmpty && passedUid != 'usr_guest') {
      return passedUid;
    }
    if (state.activeUserId.isNotEmpty && state.activeUserId != 'usr_guest') {
      return state.activeUserId;
    }
    return AppDatabase.instance.activeSessionUserId ?? '';
  }

  Future<void> saveAddress(DeliveryAddressEntity address) async {
    // 1. Resolve effective uid — use address.userId, else session uid
    final effectiveUid = _resolveUserId(address.userId);

    final readyAddress = address.copyWith(
      userId: effectiveUid,
      isDefault: address.isDefault || state.addresses.isEmpty,
    );

    // 2. Optimistic immediate update: add to state right now so UI displays it instantaneously
    final updatedList = List<DeliveryAddressEntity>.from(state.addresses);
    final idx = updatedList.indexWhere((a) => a.id == readyAddress.id);
    final shouldBeDefault = readyAddress.isDefault;

    if (shouldBeDefault) {
      for (int i = 0; i < updatedList.length; i++) {
        updatedList[i] = updatedList[i].copyWith(isDefault: false);
      }
    }
    if (idx >= 0) {
      updatedList[idx] = readyAddress;
    } else {
      updatedList.insert(0, readyAddress);
    }

    state = state.copyWith(
      addresses: updatedList,
      defaultAddress: shouldBeDefault ? readyAddress : (state.defaultAddress ?? readyAddress),
      isLoading: false,
      activeUserId: effectiveUid,
    );

    // 3. Persist to SQLite
    try {
      await _repository.saveAddress(readyAddress);
      debugPrint('[AddressController] saveAddress() → SQLite write OK: ${readyAddress.formattedAddress}');
    } catch (e) {
      debugPrint('[AddressController] saveAddress() error: $e');
      state = state.copyWith(errorMessage: e.toString());
    }

    // 4. If stream wasn't yet open for this uid, connect it now (preserving addresses)
    if (_addressSub == null && effectiveUid.isNotEmpty) {
      _reInitStream(effectiveUid);
    }
  }

  /// Manually re-sync addresses from SQLite
  Future<void> refresh() async {
    final uid = _resolveUserId();
    if (uid.isNotEmpty) {
      _reInitStream(uid);
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    final uid = _resolveUserId();

    final updatedList = List<DeliveryAddressEntity>.from(state.addresses);
    DeliveryAddressEntity? chosen;
    for (int i = 0; i < updatedList.length; i++) {
      if (updatedList[i].id == addressId) {
        updatedList[i] = updatedList[i].copyWith(isDefault: true);
        chosen = updatedList[i];
      } else {
        updatedList[i] = updatedList[i].copyWith(isDefault: false);
      }
    }
    if (chosen != null) {
      state = state.copyWith(addresses: updatedList, defaultAddress: chosen);
    }
    try {
      await _repository.setDefaultAddress(uid, addressId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteAddress(String addressId) async {
    final uid = _resolveUserId();

    final updatedList = List<DeliveryAddressEntity>.from(state.addresses)
      ..removeWhere((a) => a.id == addressId);
    final newDefault = state.defaultAddress?.id == addressId
        ? (updatedList.isNotEmpty ? updatedList.first : null)
        : state.defaultAddress;

    state = state.copyWith(
      addresses: updatedList,
      defaultAddress: newDefault,
      clearDefault: newDefault == null,
    );

    try {
      await _repository.deleteAddress(uid, addressId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  @override
  void dispose() {
    _addressSub?.cancel();
    super.dispose();
  }
}

final addressControllerProvider =
    StateNotifierProvider<AddressController, AddressState>((ref) {
  final repo = ref.watch(addressRepositoryProvider);
  final user = ref.watch(authControllerProvider).user;
  final effectiveUid = user?.id ?? AppDatabase.instance.activeSessionUserId;
  final controller = AddressController(repo, initialUserId: effectiveUid);
  ref.listen(authControllerProvider.select((s) => s.user?.id), (prev, next) {
    controller.updateActiveUser(next);
  });
  return controller;
});
