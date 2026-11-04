import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'pakistan_geo_data.dart';

/// Structured result of reverse geocoding within Pakistan.
class ResolvedPakistanLocation {
  final double latitude;
  final double longitude;
  final String province;
  final String city;
  final String? societyOrScheme;
  final String? sectorOrBlock;
  final String? roadOrStreet;
  final String? houseOrNumber;
  final String? landmark;
  final String formattedAddress;
  final String displayName;
  final bool isAccurate;

  const ResolvedPakistanLocation({
    required this.latitude,
    required this.longitude,
    required this.province,
    required this.city,
    this.societyOrScheme,
    this.sectorOrBlock,
    this.roadOrStreet,
    this.houseOrNumber,
    this.landmark,
    required this.formattedAddress,
    required this.displayName,
    this.isAccurate = true,
  });

  /// Short human-readable location in words (e.g. "Canal Berg Housing Scheme, Lahore")
  String get shortWords {
    if (societyOrScheme != null && societyOrScheme!.isNotEmpty) {
      return '$societyOrScheme, $city';
    }
    if (roadOrStreet != null && roadOrStreet!.isNotEmpty) {
      return '$roadOrStreet, $city';
    }
    return '$city, $province';
  }

  /// Complete human-readable location in words including house/block if provided
  String toDisplayWords({String? house, String? block, String? customStreet}) {
    final parts = <String>[];
    final h = (house != null && house.trim().isNotEmpty) ? house.trim() : houseOrNumber;
    if (h != null && h.isNotEmpty) parts.add(h);

    final b = (block != null && block.trim().isNotEmpty) ? block.trim() : sectorOrBlock;
    if (b != null && b.isNotEmpty) parts.add(b);

    final s = (customStreet != null && customStreet.trim().isNotEmpty) ? customStreet.trim() : roadOrStreet;
    if (s != null && s.isNotEmpty && !parts.contains(s)) parts.add(s);

    if (societyOrScheme != null && societyOrScheme!.isNotEmpty && !parts.contains(societyOrScheme)) {
      parts.add(societyOrScheme!);
    }

    if (!parts.contains(city)) parts.add(city);
    if (province.isNotEmpty && province != city && !parts.contains(province)) {
      parts.add(province);
    }

    return parts.join(', ');
  }

  /// Coordinate pin text (e.g. "31.4771°N, 74.2467°E")
  String get coordinatesText {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lngDir = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(4)}°$latDir, ${longitude.abs().toStringAsFixed(4)}°$lngDir';
  }
}

/// Deep intelligent reverse geocoding engine tailored for Pakistan addresses,
/// supporting housing societies, sectors, roads, and cities.
class PakistanGeocodingService {
  static final Map<String, ResolvedPakistanLocation> _memoryCache = {};

  /// Key for in-memory caching to avoid redundant network hits for nearby taps (~30m radius).
  static String _cacheKey(double lat, double lng) {
    return '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
  }

  /// Reverse geocode given coordinates into structured Pakistan location in words.
  static Future<ResolvedPakistanLocation> reverseGeocode({
    required double latitude,
    required double longitude,
    http.Client? httpClient,
  }) async {
    final key = _cacheKey(latitude, longitude);
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key]!;
    }

    // 1. Try Native Geocoder (Google Play Services / iOS CoreLocation)
    try {
      final placemarks = await geo.Geocoding().placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final resolved = _fromPlacemark(p, latitude, longitude);
        if (resolved != null && resolved.city.isNotEmpty) {
          _memoryCache[key] = resolved;
          return resolved;
        }
      }
    } catch (e) {
      debugPrint('Native geocoding failed or not supported in this environment: $e');
    }

    // 2. Try OpenStreetMap Nominatim with Pakistan geospatial details
    try {
      final client = httpClient ?? http.Client();
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );
      final response = await client
          .get(url, headers: {'User-Agent': 'GroclyraPakistanApp/1.0 (contact@groclyra.pk)'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final resolved = _fromNominatim(data, latitude, longitude);
        if (resolved != null) {
          _memoryCache[key] = resolved;
          return resolved;
        }
      }
    } catch (e) {
      debugPrint('OSM Nominatim reverse geocode lookup failed: $e');
    }

    // 3. Fallback to Offline Pakistan GIS Proximity Engine
    final fallback = _fromOfflineGis(latitude, longitude);
    _memoryCache[key] = fallback;
    return fallback;
  }

  static ResolvedPakistanLocation? _fromPlacemark(
    geo.Placemark p,
    double lat,
    double lng,
  ) {
    final city = p.locality?.isNotEmpty == true
        ? p.locality!
        : (p.subAdministrativeArea?.isNotEmpty == true ? p.subAdministrativeArea! : 'Lahore');

    final province = p.administrativeArea?.isNotEmpty == true
        ? _normalizeProvince(p.administrativeArea!)
        : _inferProvinceForCity(city);

    // Extract society / scheme from subLocality or thoroughfare
    String? society = p.subLocality?.isNotEmpty == true ? p.subLocality : null;
    String? street = p.thoroughfare?.isNotEmpty == true
        ? p.thoroughfare
        : (p.street?.isNotEmpty == true ? p.street : null);

    // Check specific Pakistan known areas if near Canal Berg
    if (_isNearCanalBerg(lat, lng)) {
      society = 'Canal Berg Housing Scheme';
      street = street ?? 'Multan Road';
    }

    final formatted = [
      if (street != null && street.isNotEmpty) street,
      if (society != null && society.isNotEmpty && society != street) society,
      city,
      province,
    ].join(', ');

    return ResolvedPakistanLocation(
      latitude: lat,
      longitude: lng,
      province: province,
      city: city,
      societyOrScheme: society,
      roadOrStreet: street,
      landmark: p.name?.isNotEmpty == true && p.name != street ? p.name : null,
      formattedAddress: formatted,
      displayName: '$society, $city',
    );
  }

  static ResolvedPakistanLocation? _fromNominatim(
    Map<String, dynamic> data,
    double lat,
    double lng,
  ) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return null;

    final rawCity = (address['city'] ??
            address['town'] ??
            address['county'] ??
            address['municipality'] ??
            (address['state_district'] ?? 'Lahore'))
        .toString();

    final isCanal = _isNearCanalBerg(lat, lng);
    final city = isCanal ? 'Lahore' : _normalizeCity(rawCity);

    final province = isCanal
        ? 'Punjab'
        : _normalizeProvince(
            (address['state'] ?? _inferProvinceForCity(city)).toString(),
          );

    // Society / Scheme candidate keys
    String? society = (address['housing_estate'] ??
            address['residential'] ??
            address['suburb'] ??
            address['neighbourhood'] ??
            address['quarter'])
        ?.toString();

    // Specific Canal Berg recognition
    final rawDisplayName = (data['display_name'] ?? '').toString();
    if (isCanal ||
        rawDisplayName.toLowerCase().contains('canal berg') ||
        rawDisplayName.contains('کینال')) {
      society = 'Canal Berg Housing Scheme';
    }

    final road = (address['road'] ?? address['street'])?.toString();
    final houseNumber = address['house_number']?.toString();

    final parts = <String>[];
    if (houseNumber != null && houseNumber.isNotEmpty) parts.add(houseNumber);
    if (road != null && road.isNotEmpty) parts.add(road);
    if (society != null && society.isNotEmpty && !parts.contains(society)) parts.add(society);
    if (!parts.contains(city)) parts.add(city);
    if (province.isNotEmpty && !parts.contains(province)) parts.add(province);

    final formatted = parts.isNotEmpty ? parts.join(', ') : (data['display_name'] as String? ?? '$city, $province');

    return ResolvedPakistanLocation(
      latitude: lat,
      longitude: lng,
      province: province,
      city: city,
      societyOrScheme: society,
      roadOrStreet: road,
      houseOrNumber: houseNumber,
      landmark: address['amenity']?.toString(),
      formattedAddress: formatted,
      displayName: society != null ? '$society, $city' : '$city, $province',
    );
  }

  /// Offline GIS distance calculation based on Pakistan cities and societies.
  static ResolvedPakistanLocation _fromOfflineGis(double lat, double lng) {
    // 1. Canal Berg specific check (Lat ~ 31.477, Lng ~ 74.246)
    if (_isNearCanalBerg(lat, lng)) {
      return ResolvedPakistanLocation(
        latitude: lat,
        longitude: lng,
        province: 'Punjab',
        city: 'Lahore',
        societyOrScheme: 'Canal Berg Housing Scheme',
        roadOrStreet: 'Multan Road',
        sectorOrBlock: '9-H',
        landmark: 'Near Thokar Niaz Baig / Canal Bank Road',
        formattedAddress: 'Canal Berg Housing Scheme, Multan Road, Lahore, Punjab',
        displayName: 'Canal Berg Housing Scheme, Lahore',
      );
    }

    // 2. Find closest Pakistan city in dataset
    PakistanCityData? closestCity;
    double minCityDistance = double.infinity;

    for (final c in PakistanGeoData.cities) {
      final d = _calculateDistanceKm(lat, lng, c.defaultLat, c.defaultLng);
      if (d < minCityDistance) {
        minCityDistance = d;
        closestCity = c;
      }
    }

    final city = closestCity?.name ?? 'Lahore';
    final province = closestCity?.province ?? 'Punjab';

    // If within 40 km of the city, find nearest society or default
    String? society;
    if (closestCity != null && closestCity.societies.isNotEmpty) {
      // Pick first or best matching society if within urban range
      if (minCityDistance < 20.0) {
        society = closestCity.societies.first;
      }
    }

    final formatted = [
      if (society != null) society,
      city,
      province,
      'Pakistan',
    ].join(', ');

    return ResolvedPakistanLocation(
      latitude: lat,
      longitude: lng,
      province: province,
      city: city,
      societyOrScheme: society,
      roadOrStreet: 'Main Road',
      formattedAddress: formatted,
      displayName: society != null ? '$society, $city' : '$city, $province',
      isAccurate: minCityDistance < 35.0,
    );
  }

  static bool _isNearCanalBerg(double lat, double lng) {
    // Canal Berg Housing Scheme Lahore boundaries:
    // Lat ~ 31.465 to 31.488, Lng ~ 74.235 to 74.258
    return (lat >= 31.465 && lat <= 31.488) && (lng >= 74.235 && lng <= 74.258);
  }

  static String _normalizeCity(String input) {
    var clean = input
        .replaceAll('ضلع', '')
        .replaceAll('شہر', '')
        .replaceAll('District', '')
        .replaceAll('City', '')
        .trim();
    final lower = clean.toLowerCase();

    // Check Urdu / English matches
    if (clean.contains('لاہور') || clean.contains('لاھور') || lower.contains('lahore')) return 'Lahore';
    if (clean.contains('کراچی') || lower.contains('karachi')) return 'Karachi';
    if (clean.contains('اسلام آباد') || lower.contains('islamabad')) return 'Islamabad';
    if (clean.contains('راولپنڈی') || lower.contains('rawalpindi')) return 'Rawalpindi';
    if (clean.contains('فیصل آباد') || lower.contains('faisalabad')) return 'Faisalabad';
    if (clean.contains('ملتان') || lower.contains('multan')) return 'Multan';
    if (clean.contains('پشاور') || lower.contains('peshawar')) return 'Peshawar';
    if (clean.contains('کوئٹہ') || lower.contains('quetta')) return 'Quetta';
    if (clean.contains('گوجرانوالہ') || lower.contains('gujranwala')) return 'Gujranwala';
    if (clean.contains('سیالکوٹ') || lower.contains('sialkot')) return 'Sialkot';
    if (clean.contains('حیدرآباد') || lower.contains('hyderabad')) return 'Hyderabad';

    for (final c in PakistanGeoData.cities) {
      if (lower.contains(c.name.toLowerCase())) {
        return c.name;
      }
    }
    return clean.isNotEmpty ? clean : 'Lahore';
  }

  static String _normalizeProvince(String input) {
    final lower = input.toLowerCase();
    if (input.contains('پنجاب') || lower.contains('punjab')) return 'Punjab';
    if (input.contains('سندھ') || lower.contains('sindh')) return 'Sindh';
    if (input.contains('خیبر') || lower.contains('khyber') || lower.contains('kpk')) return 'Khyber Pakhtunkhwa';
    if (input.contains('بلوچستان') || lower.contains('baloch')) return 'Balochistan';
    if (input.contains('اسلام آباد') || lower.contains('islamabad')) return 'Islamabad Capital Territory';
    if (input.contains('گلگت') || lower.contains('gilgit')) return 'Gilgit-Baltistan';
    if (input.contains('کشمیر') || lower.contains('kashmir') || lower.contains('ajk')) return 'Azad Jammu and Kashmir';

    for (final p in PakistanGeoData.provinces) {
      if (lower.contains(p.toLowerCase())) return p;
    }
    return input;
  }

  static String _inferProvinceForCity(String city) {
    for (final c in PakistanGeoData.cities) {
      if (c.name.toLowerCase() == city.toLowerCase()) {
        return c.province;
      }
    }
    return 'Punjab';
  }

  static double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }
}
