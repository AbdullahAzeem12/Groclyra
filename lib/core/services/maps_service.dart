import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:groclyra/core/database/app_database.dart';

/// Wraps the Google Maps Directions API and device GPS.
///
/// Provides:
///  - `getCurrentPosition()` — one-shot GPS fix
///  - `streamLocation()` — continuous GPS updates
///  - `getDirections()` — full route (polyline + steps + ETA) via Directions API
///  - `updateRiderLocation()` — persists lat/lng to Firestore for live tracking
class MapsService {
  // Upgraded: the public OSRM demo server also has an HTTPS endpoint. Plain
  // HTTP blocks webs traffic on Android 9+ (cleartext denial) and is
  // unprotected in transit — before this fix the base URL was non-HTTPS.
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  // ── GPS ───────────────────────────────────────────────────────────────────

  /// Requests location permission if not granted and returns current position.
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );
    } catch (e) {
      debugPrint('MapsService.getCurrentPosition error: $e');
      return null;
    }
  }

  /// Continuous GPS stream — emits updates every ~5 m of movement.
  static Stream<Position> streamLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).handleError((e) {
      // FIX: was `\$e` (escaped) — the literal text "\$e" was printed instead
      // of the actual error.
      debugPrint('MapsService.streamLocation error: $e');
    });
  }

  // ── DIRECTIONS API (OSRM) ────────────────────────────────────────────────

  /// Fetches a driving route between [origin] and [destination] using OSRM.
  ///
  /// Returns a [RouteResult] with encoded polyline, step-by-step instructions,
  /// total distance (metres) and total duration (seconds).
  static Future<RouteResult?> getDirections({
    required LatLngPoint origin,
    required LatLngPoint destination,
    List<LatLngPoint> waypoints = const [],
  }) async {
    try {
      // OSRM coordinates are in longitude,latitude order
      final List<String> coords = [];
      coords.add('${origin.lng},${origin.lat}');
      for (final w in waypoints) {
        coords.add('${w.lng},${w.lat}');
      }
      coords.add('${destination.lng},${destination.lat}');

      final coordsString = coords.join(';');

      final url = Uri.parse(
        '$_osrmBaseUrl/$coordsString?overview=full&geometries=polyline&steps=true',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('MapsService.getDirections HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') {
        debugPrint('MapsService.getDirections API status: ${data['code']}');
        return null;
      }

      final routes = data['routes'] as List;
      if (routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List;

      int totalDistanceM = (route['distance'] as num).toInt();
      int totalDurationS = (route['duration'] as num).toInt();
      final List<DirectionsStep> steps = [];

      for (final l in legs) {
        final rawSteps = l['steps'] as List;
        for (final s in rawSteps) {
          final maneuver = s['maneuver'] as Map<String, dynamic>;
          final loc = maneuver['location'] as List; // [lon, lat]
          steps.add(
            DirectionsStep(
              instruction: s['name'] != null && s['name'].toString().isNotEmpty
                  ? "${maneuver['type']} onto ${s['name']}"
                  : maneuver['type'] as String? ?? 'Proceed',
              distanceM: (s['distance'] as num).toInt(),
              durationS: (s['duration'] as num).toInt(),
              startLat: (loc[1] as num).toDouble(),
              startLng: (loc[0] as num).toDouble(),
              maneuver: maneuver['modifier'] as String? ?? maneuver['type'] as String? ?? '',
            ),
          );
        }
      }

      final overviewPolyline = route['geometry'] as String? ?? '';

      return RouteResult(
        encodedPolyline: overviewPolyline,
        steps: steps,
        totalDistanceM: totalDistanceM,
        totalDurationS: totalDurationS,
      );
    } catch (e) {
      // FIX: was `\$e` (escaped) — no real error was ever printed.
      debugPrint('MapsService.getDirections error: $e');
      return null;
    }
  }

  // ── SQL LOCATION SYNC ───────────────────────────────────────────────

  /// Updates rider's current lat/lng in SQLite for live multi-portal tracking
  static Future<void> updateRiderLocation(
      String riderId, Position pos) async {
    try {
      final now = DateTime.now().toIso8601String();

      // 1. Persist exact GPS in rider_profiles table
      await AppDatabase.instance.insertOrReplace('rider_profiles', {
        'riderId': riderId,
        'currentLat': pos.latitude,
        'currentLng': pos.longitude,
        'isOnline': 1,
        'updatedAt': now,
      });

      // 2. Persist live coordinates in all active delivery tasks
      final activeTasks = await AppDatabase.instance.query(
        'delivery_tasks',
        where: "riderId = ? AND status IN ('accepted', 'pickedUp', 'inTransit')",
        whereArgs: [riderId],
      );

      for (final task in activeTasks) {
        await AppDatabase.instance.update(
          'delivery_tasks',
          {
            'riderLat': pos.latitude,
            'riderLng': pos.longitude,
            'updatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [task['id']],
        );
      }

      // 3. Keep user profile zone updated
      await AppDatabase.instance.update(
        'users',
        {
          'deliveryZone': '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [riderId],
      );

      // Broadcast changes across all connected portals
      AppDatabase.instance.notifyTable('rider_profiles');
      AppDatabase.instance.notifyTable('delivery_tasks');
      AppDatabase.instance.notifyTable('users');
    } catch (e) {
      debugPrint('MapsService.updateRiderLocation error: $e');
    }
  }

  /// Streams real-time rider GPS coordinates from SQLite
  static Stream<LatLngPoint?> streamRiderLiveCoordinates(String riderId) async* {
    Future<LatLngPoint?> fetch() async {
      final rows = await AppDatabase.instance.query(
        'rider_profiles',
        where: 'riderId = ?',
        whereArgs: [riderId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final lat = (rows.first['currentLat'] as num?)?.toDouble();
        final lng = (rows.first['currentLng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return LatLngPoint(lat: lat, lng: lng);
        }
      }
      return null;
    }

    yield await fetch();

    yield* AppDatabase.instance.watchTable('rider_profiles').asyncMap((_) async {
      return await fetch();
    });
  }

  // ── POLYLINE DECODER ──────────────────────────────────────────────────────

  /// Decodes a Google Maps encoded polyline into a list of lat/lng points.
  static List<LatLngPoint> decodePolyline(String encoded) {
    final List<LatLngPoint> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLngPoint(lat: lat / 1e5, lng: lng / 1e5));
    }

    return points;
  }

  /// Calculates the straight-line distance in kilometres between two points.
  static double haversineKm(LatLngPoint a, LatLngPoint b) {
    const r = 6371.0;
    final dLat = _toRad(b.lat - a.lat);
    final dLng = _toRad(b.lng - a.lng);
    final hav = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.lat)) * cos(_toRad(b.lat)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(hav));
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  static double _toRad(double deg) => deg * pi / 180;
}

// ── DATA CLASSES ──────────────────────────────────────────────────────────────

class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint({required this.lat, required this.lng});
}

class DirectionsStep {
  final String instruction;
  final int distanceM;
  final int durationS;
  final double startLat;
  final double startLng;
  final String maneuver;

  const DirectionsStep({
    required this.instruction,
    required this.distanceM,
    required this.durationS,
    required this.startLat,
    required this.startLng,
    required this.maneuver,
  });

  String get formattedDistance {
    if (distanceM >= 1000) {
      return '${(distanceM / 1000).toStringAsFixed(1)} km';
    }
    return '$distanceM m';
  }

  String get formattedDuration {
    if (durationS >= 3600) {
      final h = durationS ~/ 3600;
      final m = (durationS % 3600) ~/ 60;
      return '${h}h ${m}m';
    }
    final m = durationS ~/ 60;
    return m < 1 ? '<1 min' : '$m min';
  }

  IconData get maneuverIcon {
    switch (maneuver) {
      case 'turn-right':
      case 'turn-sharp-right':
        return Icons.turn_right_rounded;
      case 'turn-left':
      case 'turn-sharp-left':
        return Icons.turn_left_rounded;
      case 'roundabout-right':
        return Icons.roundabout_right_rounded;
      case 'roundabout-left':
        return Icons.roundabout_left_rounded;
      case 'straight':
        return Icons.straight_rounded;
      case 'uturn-right':
      case 'uturn-left':
        return Icons.u_turn_right_rounded;
      case 'ramp-right':
      case 'merge':
        return Icons.merge_rounded;
      default:
        return Icons.navigation_rounded;
    }
  }
}

class RouteResult {
  final String encodedPolyline;
  final List<DirectionsStep> steps;
  final int totalDistanceM;
  final int totalDurationS;

  const RouteResult({
    required this.encodedPolyline,
    required this.steps,
    required this.totalDistanceM,
    required this.totalDurationS,
  });

  String get formattedDistance {
    if (totalDistanceM >= 1000) {
      return '${(totalDistanceM / 1000).toStringAsFixed(1)} km';
    }
    return '$totalDistanceM m';
  }

  String get formattedDuration {
    if (totalDurationS >= 3600) {
      final h = totalDurationS ~/ 3600;
      final m = (totalDurationS % 3600) ~/ 60;
      return '${h}h ${m}m';
    }
    final m = totalDurationS ~/ 60;
    return m < 1 ? '<1 min' : '$m min';
  }

  List<LatLngPoint> get polylinePoints =>
      MapsService.decodePolyline(encodedPolyline);
}
