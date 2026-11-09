import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/features/customer/addresses/domain/entities/delivery_address_entity.dart';
import 'package:groclyra/features/customer/addresses/data/repositories/address_repository.dart';
import 'package:groclyra/features/customer/addresses/presentation/controllers/address_controller.dart';

void main() {
  group('AddressController & AddressRepository Realtime Sync Tests', () {
    late AddressRepository repository;
    late AddressController controller;

    setUp(() {
      AppDatabase.instance.resetForTest();
      repository = AddressRepository();
      controller = AddressController(repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial state is loading or starts with cached list without error', () {
      expect(controller.state.addresses, isEmpty);
      expect(controller.state.errorMessage, isNull);
    });

    test('Saving an address immediately updates controller state and marks as default if first', () async {
      final address = DeliveryAddressEntity(
        id: 'addr_canal_berg_1',
        userId: 'usr_test_123',
        recipientName: 'Ali Khan',
        recipientPhone: '+923001234567',
        houseOrFlat: '9-H',
        street: 'Canal Bank Road',
        sectorOrBlock: 'Block H',
        societyOrScheme: 'Canal Berg Housing Scheme',
        city: 'Lahore',
        provinceOrTerritory: 'Punjab',
        latitude: 31.4771,
        longitude: 74.2467,
        createdAt: DateTime.now(),
      );

      await controller.saveAddress(address);

      expect(controller.state.addresses.length, equals(1));
      final saved = controller.state.addresses.first;
      expect(saved.id, equals('addr_canal_berg_1'));
      expect(saved.houseOrFlat, equals('9-H'));
      expect(saved.societyOrScheme, equals('Canal Berg Housing Scheme'));
      expect(saved.city, equals('Lahore'));
      expect(saved.latitude, equals(31.4771));
      expect(saved.longitude, equals(74.2467));
      expect(saved.isDefault, isTrue);
      expect(controller.state.defaultAddress?.id, equals('addr_canal_berg_1'));
    });

    test('Saving a second address preserves existing address and list ordering', () async {
      final addr1 = DeliveryAddressEntity(
        id: 'addr_1',
        userId: 'usr_test_123',
        recipientName: 'Ali Khan',
        recipientPhone: '+923001234567',
        houseOrFlat: '9-H',
        street: 'Canal Bank Road',
        societyOrScheme: 'Canal Berg Housing Scheme',
        city: 'Lahore',
        provinceOrTerritory: 'Punjab',
        latitude: 31.4771,
        longitude: 74.2467,
        createdAt: DateTime.now(),
      );

      final addr2 = DeliveryAddressEntity(
        id: 'addr_2',
        userId: 'usr_test_123',
        recipientName: 'Ali Khan',
        recipientPhone: '+923001234567',
        houseOrFlat: 'Flat 402',
        street: 'Khayaban-e-Iqbal',
        societyOrScheme: 'DHA Phase 5',
        city: 'Lahore',
        provinceOrTerritory: 'Punjab',
        latitude: 31.4697,
        longitude: 74.3855,
        isDefault: false,
        createdAt: DateTime.now().add(const Duration(seconds: 1)),
      );

      await controller.saveAddress(addr1);
      await controller.saveAddress(addr2);

      expect(controller.state.addresses.length, equals(2));
      expect(controller.state.defaultAddress?.id, equals('addr_1'));

      // Now set addr2 as default
      await controller.setDefaultAddress('addr_2');
      expect(controller.state.defaultAddress?.id, equals('addr_2'));
      final chosen = controller.state.addresses.firstWhere((a) => a.id == 'addr_2');
      expect(chosen.isDefault, isTrue);

      final other = controller.state.addresses.firstWhere((a) => a.id == 'addr_1');
      expect(other.isDefault, isFalse);
    });

    test('Deleting an address removes it immediately from controller state', () async {
      final addr1 = DeliveryAddressEntity(
        id: 'addr_del_1',
        userId: 'usr_test_123',
        recipientName: 'User',
        recipientPhone: '+923001234567',
        houseOrFlat: '12',
        street: 'Street 1',
        city: 'Karachi',
        provinceOrTerritory: 'Sindh',
        latitude: 24.8607,
        longitude: 67.0011,
        createdAt: DateTime.now(),
      );

      await controller.saveAddress(addr1);
      expect(controller.state.addresses.length, equals(1));

      await controller.deleteAddress('addr_del_1');
      expect(controller.state.addresses, isEmpty);
      expect(controller.state.defaultAddress, isNull);
    });
  });
}
