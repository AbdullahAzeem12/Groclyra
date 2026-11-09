import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class GeoCoordinates {
  final double lat;
  final double lng;

  const GeoCoordinates(this.lat, this.lng);

  @override
  String toString() => '$lat, $lng';
}

class LocationService {
  static final LocationService instance = LocationService();

  // ── Exact Pakistan Major City Coordinates ──────────────────────────────
  static const Map<String, GeoCoordinates> pakistanCityCoordinates = {
    'Karachi': GeoCoordinates(24.8607, 67.0011),
    'Lahore': GeoCoordinates(31.5204, 74.3587),
    'Islamabad': GeoCoordinates(33.6844, 73.0479),
    'Rawalpindi': GeoCoordinates(33.5651, 73.0169),
    'Faisalabad': GeoCoordinates(31.4504, 73.1350),
    'Multan': GeoCoordinates(30.1575, 71.5249),
    'Peshawar': GeoCoordinates(34.0151, 71.5249),
    'Quetta': GeoCoordinates(30.1798, 66.9750),
    'Sialkot': GeoCoordinates(32.4945, 74.5229),
    'Gujranwala': GeoCoordinates(32.1877, 74.1945),
    'Hyderabad': GeoCoordinates(25.3960, 68.3578),
    'Abbottabad': GeoCoordinates(34.1688, 73.2215),
    'Bahawalpur': GeoCoordinates(29.3956, 71.6836),
    'Sargodha': GeoCoordinates(32.0836, 72.6711),
    'Sukkur': GeoCoordinates(27.7052, 68.8574),
    'Larkana': GeoCoordinates(27.5590, 68.2120),
    'Sheikhupura': GeoCoordinates(31.7131, 73.9783),
    'Rahim Yar Khan': GeoCoordinates(28.4212, 70.2989),
    'Jhang': GeoCoordinates(31.2781, 72.3317),
    'Dera Ghazi Khan': GeoCoordinates(30.0489, 70.6455),
    'Gujrat': GeoCoordinates(32.5742, 74.0754),
    'Sahiwal': GeoCoordinates(30.6682, 73.1114),
    'Wah Cantonment': GeoCoordinates(33.7715, 72.7511),
    'Mardan': GeoCoordinates(34.1989, 72.0404),
    'Kasur': GeoCoordinates(31.1179, 74.4460),
    'Mingora': GeoCoordinates(34.7758, 72.3626),
    'Nawabshah': GeoCoordinates(26.2483, 68.4096),
    'Chiniot': GeoCoordinates(31.7200, 72.9789),
    'Kotri': GeoCoordinates(25.3670, 68.3083),
    'Hafizabad': GeoCoordinates(32.0679, 73.6857),
    'Sadiqabad': GeoCoordinates(28.3090, 70.1332),
    'Mirpur Khas': GeoCoordinates(25.5276, 69.0125),
    'Burewala': GeoCoordinates(30.1667, 72.6833),
    'Kohat': GeoCoordinates(33.5869, 71.4414),
    'Khanewal': GeoCoordinates(30.3004, 71.9324),
    'Dera Ismail Khan': GeoCoordinates(31.8327, 70.9024),
    'Muzaffarabad': GeoCoordinates(34.3700, 73.4711),
    'Mirpur': GeoCoordinates(33.1489, 73.7519),
    'Gilgit': GeoCoordinates(35.9221, 74.3087),
    'Skardu': GeoCoordinates(35.2971, 75.6333),
    'Gwadar': GeoCoordinates(25.1264, 62.3225),
  };

  // Check and request location permissions
  Future<bool> handleLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('LocationService.handleLocationPermission error: $e');
      return false;
    }
  }

  // Get current position with timeout and fallback
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('LocationService.getCurrentPosition error: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // Reverse geocode coordinates to get address
  Future<Placemark?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks =
          await Geocoding().placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        return placemarks[0];
      }
    } catch (e) {
      debugPrint('LocationService.getAddressFromCoordinates error: $e');
    }
    return null;
  }

  /// Resolves an address string or city into exact geographic coordinates.
  /// Falls back to verified Pakistani city coordinates so coordinates are never null or off-shore.
  Future<GeoCoordinates> resolveAddressCoordinates(
    String addressText, {
    String? city,
  }) async {
    // 1. Try Geocoding API if address is provided
    if (addressText.trim().isNotEmpty) {
      try {
        final locations = await Geocoding().locationFromAddress(addressText);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          // Verify it falls reasonably within Pakistan boundaries (Lat: 23-37, Lng: 60-78)
          if (loc.latitude >= 23.0 &&
              loc.latitude <= 37.5 &&
              loc.longitude >= 60.0 &&
              loc.longitude <= 78.5) {
            return GeoCoordinates(loc.latitude, loc.longitude);
          }
        }
      } catch (_) {}
    }

    // 2. Match city from explicit city parameter or address string
    final queryText = '$city $addressText'.toLowerCase();
    for (final entry in pakistanCityCoordinates.entries) {
      if (queryText.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // 3. Default to Lahore central marketplace if unresolvable
    return const GeoCoordinates(31.5204, 74.3587);
  }

  /// Returns coordinates for a specific city name
  GeoCoordinates getCoordinatesForCity(String cityName) {
    for (final entry in pakistanCityCoordinates.entries) {
      if (entry.key.toLowerCase() == cityName.trim().toLowerCase()) {
        return entry.value;
      }
    }
    return const GeoCoordinates(31.5204, 74.3587); // Default Lahore
  }

  /// Calculates accurate distance in kilometers using the Haversine formula
  double haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  /// Estimates delivery time in minutes based on real Pakistani city traffic
  int estimateDeliveryTimeMinutes(double distanceKm) {
    if (distanceKm <= 0.2) return 10;
    // Base packaging and dispatch: 10 minutes
    // Average urban speed: 20 km/h (~3 minutes per km)
    final travelMinutes = (distanceKm * 3.2).ceil();
    return (10 + travelMinutes).clamp(15, 90);
  }

  // Hierarchical data for Pakistan
  final Map<String, Map<String, List<String>>> pakistanData = {
    'Punjab': {
      'Lahore': ['Lahore City', 'Model Town', 'Cantonment', 'Raiwind', 'Shalimar'],
      'Faisalabad': ['Faisalabad City', 'Jaranwala', 'Samundri', 'Tandlianwala'],
      'Rawalpindi': ['Rawalpindi', 'Gujar Khan', 'Taxila', 'Murree'],
      'Multan': ['Multan City', 'Multan Saddar', 'Shujabad', 'Jalalpur Pirwala'],
    },
    'Sindh': {
      'Karachi': ['South', 'East', 'West', 'Central', 'Malir', 'Korangi'],
      'Hyderabad': ['Hyderabad City', 'Latifabad', 'Qasimabad'],
      'Sukkur': ['Sukkur City', 'Rohri', 'Salehpat'],
    },
    'Khyber Pakhtunkhwa': {
      'Peshawar': ['Peshawar City', 'Peshawar Saddar'],
      'Mardan': ['Mardan', 'Takht Bhai'],
      'Swat': ['Babuzai', 'Matta', 'Khwazakhela', 'Kabal'],
    },
    'Balochistan': {
      'Quetta': ['Quetta City', 'Quetta Saddar'],
      'Gwadar': ['Gwadar', 'Pasni', 'Ormara'],
    },
    'Islamabad Capital Territory': {
      'Islamabad': ['Zone I', 'Zone II', 'Zone III', 'Zone IV', 'Zone V'],
    },
    'Gilgit-Baltistan': {
      'Gilgit': ['Gilgit'],
      'Skardu': ['Skardu'],
    },
    'Azad Jammu & Kashmir': {
      'Muzaffarabad': ['Muzaffarabad'],
      'Mirpur': ['Mirpur'],
    },
  };

  List<String> getProvinces() {
    return pakistanData.keys.toList();
  }

  List<String> getDistricts(String province) {
    if (pakistanData.containsKey(province)) {
      return pakistanData[province]!.keys.toList();
    }
    return [];
  }

  List<String> getCities(String province, String district) {
    if (pakistanData.containsKey(province) &&
        pakistanData[province]!.containsKey(district)) {
      return pakistanData[province]![district]!;
    }
    return [];
  }
}
