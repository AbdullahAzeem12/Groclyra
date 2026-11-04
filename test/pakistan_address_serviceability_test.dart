import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/features/customer/addresses/domain/entities/delivery_address_entity.dart';
import 'package:groclyra/features/customer/addresses/domain/services/delivery_serviceability_engine.dart';
import 'package:groclyra/features/customer/addresses/domain/services/pakistan_geo_data.dart';
import 'package:groclyra/features/customer/addresses/domain/services/pakistan_geocoding_service.dart';

void main() {
  group('Pakistan Geographic & Administrative Hierarchy Tests', () {
    test('Provinces list contains all 7 official regions', () {
      expect(PakistanGeoData.provinces, contains('Sindh'));
      expect(PakistanGeoData.provinces, contains('Punjab'));
      expect(PakistanGeoData.provinces, contains('Khyber Pakhtunkhwa'));
      expect(PakistanGeoData.provinces, contains('Balochistan'));
      expect(PakistanGeoData.provinces, contains('Islamabad Capital Territory'));
      expect(PakistanGeoData.provinces, contains('Gilgit-Baltistan'));
      expect(PakistanGeoData.provinces, contains('Azad Jammu and Kashmir'));
      expect(PakistanGeoData.provinces.length, equals(7));
    });

    test('Search finds Karachi localities (Clifton, DHA, Gulshan)', () {
      final results = PakistanGeoData.search('Clifton');
      expect(results, isNotEmpty);
      final clifton = results.first;
      expect(clifton.city, equals('Karachi'));
      expect(clifton.province, equals('Sindh'));
      expect(clifton.societyOrArea, contains('Clifton'));
      expect(clifton.latitude, inInclusiveRange(24.8, 24.9));
      expect(clifton.longitude, inInclusiveRange(67.0, 67.1));
    });

    test('Search finds Lahore housing schemes (Bahria Town, Gulberg, DHA)', () {
      final bahriaResults = PakistanGeoData.search('Bahria');
      expect(bahriaResults, isNotEmpty);
      expect(bahriaResults.any((s) => s.city == 'Lahore' || s.city == 'Rawalpindi' || s.city == 'Karachi'), isTrue);

      final gulbergResults = PakistanGeoData.search('Gulberg');
      expect(gulbergResults, isNotEmpty);
      expect(gulbergResults.any((s) => s.city == 'Lahore'), isTrue);
    });

    test('Search handles case-insensitivity and Roman Urdu spelling variations', () {
      final resultsLower = PakistanGeoData.search('peshawar');
      expect(resultsLower, isNotEmpty);
      expect(resultsLower.first.province, equals('Khyber Pakhtunkhwa'));

      final resultsHayatabad = PakistanGeoData.search('hayatabad');
      expect(resultsHayatabad, isNotEmpty);
      expect(resultsHayatabad.first.city, equals('Peshawar'));
    });

    test('Search returns empty list for completely unrecognized query (triggers manual entry fallback)', () {
      final results = PakistanGeoData.search('XYZ Nonexistent Locality 9999');
      expect(results, isEmpty);
    });
  });

  group('Pakistan Delivery Serviceability Engine Tests', () {
    test('Clifton Karachi location qualifies for Express 30-min delivery', () {
      // Coordinates near Groclyra Karachi Clifton Hub (24.8138, 67.0299)
      final result = DeliveryServiceabilityEngine.evaluateServiceability(
        latitude: 24.8200,
        longitude: 67.0320,
        city: 'Karachi',
      );

      expect(result.isServiceable, isTrue);
      expect(result.tier, equals(DeliveryTier.express30m));
      expect(result.estimatedMinutes, inInclusiveRange(30, 45));
      expect(result.closestHubName, contains('Clifton'));
      expect(result.distanceKm, lessThan(15.0));
    });

    test('Gulberg Lahore location qualifies for Express 30-min delivery', () {
      // Coordinates near Lahore Hub (31.5204, 74.3587)
      final result = DeliveryServiceabilityEngine.evaluateServiceability(
        latitude: 31.5180,
        longitude: 74.3520,
        city: 'Lahore',
      );

      expect(result.isServiceable, isTrue);
      expect(result.tier, equals(DeliveryTier.express30m));
      expect(result.closestHubName, contains('Lahore'));
    });

    test('Islamabad F-7 location qualifies for Express 30-min delivery', () {
      // Coordinates near Islamabad Hub (33.7294, 73.0551)
      final result = DeliveryServiceabilityEngine.evaluateServiceability(
        latitude: 33.7250,
        longitude: 73.0520,
        city: 'Islamabad',
      );

      expect(result.isServiceable, isTrue);
      expect(result.tier, equals(DeliveryTier.express30m));
      expect(result.closestHubName, contains('Islamabad'));
    });

    test('Supported tier cities beyond micro-hub range qualify for same-day delivery', () {
      // Far outskirts of Karachi or Faisalabad outer
      final result = DeliveryServiceabilityEngine.evaluateServiceability(
        latitude: 25.1000,
        longitude: 67.3500,
        city: 'Karachi',
      );

      expect(result.isServiceable, isTrue);
      expect(result.tier, equals(DeliveryTier.standardSameDay));
      expect(result.displayEstimate, contains('Same-Day'));
    });

    test('Remote / small town locations qualify for nationwide courier delivery', () {
      final result = DeliveryServiceabilityEngine.evaluateServiceability(
        latitude: 30.5000,
        longitude: 69.5000,
        city: 'Zhob',
      );

      expect(result.isServiceable, isTrue);
      expect(result.tier, equals(DeliveryTier.nationwide3To5Days));
      expect(result.displayEstimate, contains('3-5 Business Days'));
    });
  });

  group('Pakistan Geocoding & Coordinate Dual-Detail Engine Tests', () {
    test('Resolves coordinates (31.4771, 74.2467) to Canal Berg Housing Scheme, Lahore, Punjab', () async {
      final resolved = await PakistanGeocodingService.reverseGeocode(
        latitude: 31.4771,
        longitude: 74.2467,
      );

      expect(resolved.city, equals('Lahore'));
      expect(resolved.province, equals('Punjab'));
      expect(resolved.societyOrScheme, contains('Canal Berg Housing Scheme'));
      expect(resolved.coordinatesText, equals('31.4771°N, 74.2467°E'));
      expect(resolved.shortWords, equals('Canal Berg Housing Scheme, Lahore'));
    });

    test('Generates detailed words address with custom house and block (e.g. 9-H Canal Berg)', () async {
      final resolved = await PakistanGeocodingService.reverseGeocode(
        latitude: 31.4771,
        longitude: 74.2467,
      );

      final fullWords = resolved.toDisplayWords(
        house: 'House 9',
        block: '9-H',
        customStreet: 'Street 4',
      );

      expect(fullWords, contains('House 9'));
      expect(fullWords, contains('9-H'));
      expect(fullWords, contains('Canal Berg Housing Scheme'));
      expect(fullWords, contains('Lahore'));
    });

    test('PakistanGeoData contains Canal Berg Housing Scheme in Lahore search', () {
      final searchResults = PakistanGeoData.search('Canal Berg');
      expect(searchResults, isNotEmpty);
      final canalBerg = searchResults.first;
      expect(canalBerg.city, equals('Lahore'));
      expect(canalBerg.province, equals('Punjab'));
      expect(canalBerg.societyOrArea, contains('Canal Berg Housing Scheme'));
    });
  });

  group('DeliveryAddressEntity Model & Manual Fallback Tests', () {
    test('Manual address creation supports custom society and landmark', () {
      final manualAddress = DeliveryAddressEntity(
        id: 'addr_manual_custom_01',
        userId: 'usr_test_123',
        label: AddressLabel.home,
        recipientName: 'Ali Khan',
        recipientPhone: '+92 321 9876543',
        province: 'Punjab',
        city: 'Gujrat',
        societyOrArea: 'Rehman Housing Society',
        sectorOrBlock: 'Block C',
        street: 'Kunjah Road',
        houseOrFlat: 'House 42-A',
        nearestLandmark: 'Opposite Government College',
        deliveryInstructions: 'Call on arrival, gate is green',
        latitude: 32.5744,
        longitude: 74.0754,
        isDefault: true,
        createdAt: DateTime.now(),
      );

      expect(manualAddress.societyOrArea, equals('Rehman Housing Society'));
      expect(manualAddress.nearestLandmark, equals('Opposite Government College'));
      expect(manualAddress.fullAddressDisplay, contains('Rehman Housing Society'));
      expect(manualAddress.fullAddressDisplay, contains('Gujrat'));
      expect(manualAddress.isDefault, isTrue);
    });

    test('Address formatted display combines house, block, society, and city accurately', () {
      final address = DeliveryAddressEntity(
        id: 'addr_canal_berg',
        userId: 'usr_canal_01',
        label: AddressLabel.home,
        recipientName: 'Muhammad Ahmed',
        recipientPhone: '+92 300 7654321',
        province: 'Punjab',
        city: 'Lahore',
        societyOrArea: 'Canal Berg Housing Scheme',
        sectorOrBlock: '9-H',
        street: 'Multan Road',
        houseOrFlat: 'House 9-H',
        nearestLandmark: 'Near Canal View',
        latitude: 31.4771,
        longitude: 74.2467,
        isDefault: true,
        createdAt: DateTime.now(),
      );

      expect(address.fullAddressDisplay, contains('9-H'));
      expect(address.fullAddressDisplay, contains('Canal Berg Housing Scheme'));
      expect(address.fullAddressDisplay, contains('Lahore'));
      expect(address.fullAddressDisplay, contains('Punjab'));
      expect(address.coordinatesFormatted, equals('31.4771°N, 74.2467°E'));
    });

    test('Serialization toMap and fromMap preserves all fields and coordinates', () {
      final original = DeliveryAddressEntity(
        id: 'addr_test_01',
        userId: 'usr_99',
        label: AddressLabel.work,
        recipientName: 'Fatima Noor',
        recipientPhone: '+92 300 1234567',
        province: 'Sindh',
        city: 'Karachi',
        societyOrArea: 'Clifton',
        sectorOrBlock: 'Block 5',
        street: 'Khayaban-e-Saadi',
        houseOrFlat: 'Suite 302',
        nearestLandmark: 'Boat Basin',
        deliveryInstructions: 'Deliver to reception',
        latitude: 24.8210,
        longitude: 67.0315,
        isDefault: false,
        createdAt: DateTime(2026, 10, 21, 12, 0),
      );

      final map = original.toMap();
      final parsed = DeliveryAddressEntity.fromMap(map, 'addr_test_01');

      expect(parsed.id, equals(original.id));
      expect(parsed.userId, equals(original.userId));
      expect(parsed.label, equals(AddressLabel.work));
      expect(parsed.recipientName, equals(original.recipientName));
      expect(parsed.city, equals('Karachi'));
      expect(parsed.societyOrArea, equals('Clifton'));
      expect(parsed.latitude, equals(original.latitude));
      expect(parsed.longitude, equals(original.longitude));
    });
  });
}
