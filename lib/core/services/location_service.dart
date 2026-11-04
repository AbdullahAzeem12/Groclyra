import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationService {
  // Check and request location permissions
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled.
      return false;
    }
    permission = await Geolocator.checkPermission();
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
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
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
      // Ignore
    }
    return null;
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
