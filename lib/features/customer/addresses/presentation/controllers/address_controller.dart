import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseAuth? _explicitAuth;

  FirebaseAuth? get _auth {
    if (_explicitAuth != null) return _explicitAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// StreamSubscription for the Firestore address collection
  StreamSubscription<List<DeliveryAddressEntity>>? _addressSub;

  /// StreamSubscription watching FirebaseAuth sign-in state
  StreamSubscription<User?>? _authSub;

  AddressController(this._repository, {FirebaseAuth? firebaseAuth})
      : _explicitAuth = firebaseAuth,
        super(const AddressState(isLoading: true)) {
    // 1. Immediately initialize with current Firebase Auth user if available
    final currentUid = _auth?.currentUser?.uid ?? '';
    _reInitStream(currentUid);

    // 2. Listen to Firebase Auth state changes
    _authSub = _auth?.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    final uid = user?.uid ?? '';
    if (uid == state.activeUserId && _addressSub != null) return;
    debugPrint('[AddressController] Auth changed → uid=$uid. Re-initializing stream.');
    _reInitStream(uid);
  }

  void _reInitStream(String uid) {
    _addressSub?.cancel();
    _addressSub = null;

    // Retain existing addresses during re-initialization so UI never blinks or clears
    state = state.copyWith(
      isLoading: state.addresses.isEmpty,
      activeUserId: uid,
    );

    _addressSub = _repository.streamAddresses(uid).listen(
      (list) {
        if (!mounted) return;
        final defaultAddr = list.cast<DeliveryAddressEntity?>().firstWhere(
              (a) => a?.isDefault == true,
              orElse: () => list.isNotEmpty ? list.first : null,
            );
        state = state.copyWith(
          addresses: list,
          defaultAddress: defaultAddr,
          isLoading: false,
          clearError: true,
        );
        debugPrint('[AddressController] Stream update: ${list.length} addresses for uid=$uid');
      },
      onError: (dynamic e) {
        if (!mounted) return;
        debugPrint('[AddressController] Stream error: $e');
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      },
    );
  }

  Future<void> saveAddress(DeliveryAddressEntity address) async {
    // 1. Resolve effective uid — use address.userId, else live Firebase Auth uid
    final effectiveUid = address.userId.isNotEmpty && address.userId != 'usr_guest'
        ? address.userId
        : (_auth?.currentUser?.uid ?? '');

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
    );

    // 3. If stream wasn't yet open for this uid, connect it now (preserving addresses)
    if (state.activeUserId != effectiveUid && effectiveUid.isNotEmpty) {
      _reInitStream(effectiveUid);
    }

    // 4. Persist to Firestore
    try {
      await _repository.saveAddress(readyAddress);
      debugPrint('[AddressController] saveAddress() → Firestore write OK: ${readyAddress.formattedAddress}');
    } catch (e) {
      debugPrint('[AddressController] saveAddress() error: $e');
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Manually re-sync addresses from Firestore
  Future<void> refresh() async {
    final uid = state.activeUserId.isNotEmpty
        ? state.activeUserId
        : (_auth?.currentUser?.uid ?? '');
    if (uid.isNotEmpty) {
      _reInitStream(uid);
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    final uid = state.activeUserId.isNotEmpty
        ? state.activeUserId
        : (_auth?.currentUser?.uid ?? '');

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
    final uid = state.activeUserId.isNotEmpty
        ? state.activeUserId
        : (_auth?.currentUser?.uid ?? '');

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
    _authSub?.cancel();
    _addressSub?.cancel();
    super.dispose();
  }
}

final addressControllerProvider =
    StateNotifierProvider<AddressController, AddressState>((ref) {
  final repo = ref.watch(addressRepositoryProvider);
  return AddressController(repo);
});
