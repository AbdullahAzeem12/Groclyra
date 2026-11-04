import 'dart:math' as math;
import '../entities/delivery_address_entity.dart';

enum DeliveryTier {
  express30m('Express (30-45 Mins)', 0xFF10B981),
  standardSameDay('Same-Day Delivery', 0xFF3B82F6),
  nationwide3To5Days('Nationwide Courier (3-5 Business Days)', 0xFF8B5CF6),
  outsideCoverage('Outside Coverage', 0xFFEF4444);

  final String label;
  final int colorValue;
  const DeliveryTier(this.label, this.colorValue);
}

class ServiceabilityResult {
  final bool isServiceable;
  final DeliveryTier tier;
  final int? estimatedMinutes;
  final String closestHubName;
  final double distanceKm;
  final String displayEstimate;

  const ServiceabilityResult({
    required this.isServiceable,
    required this.tier,
    this.estimatedMinutes,
    required this.closestHubName,
    required this.distanceKm,
    required this.displayEstimate,
  });
}

class DeliveryHub {
  final String name;
  final double latitude;
  final double longitude;
  final double radiusKm;

  const DeliveryHub({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });
}

class DeliveryServiceabilityEngine {
  static const List<DeliveryHub> activeHubs = [
    DeliveryHub(name: 'Karachi South & Clifton Express Hub', latitude: 24.8138, longitude: 67.0299, radiusKm: 18.0),
    DeliveryHub(name: 'Karachi Central & North Hub', latitude: 24.9200, longitude: 67.0800, radiusKm: 20.0),
    DeliveryHub(name: 'Lahore Urban Hub (Gulberg/DHA)', latitude: 31.5204, longitude: 74.3587, radiusKm: 25.0),
    DeliveryHub(name: 'Islamabad & Rawalpindi Twin Cities Hub', latitude: 33.7294, longitude: 73.0551, radiusKm: 25.0),
    DeliveryHub(name: 'Faisalabad Hub', latitude: 31.4504, longitude: 73.1350, radiusKm: 20.0),
    DeliveryHub(name: 'Multan City Hub', latitude: 30.1575, longitude: 71.5249, radiusKm: 20.0),
    DeliveryHub(name: 'Peshawar Hub', latitude: 34.0151, longitude: 71.5249, radiusKm: 20.0),
    DeliveryHub(name: 'Gujranwala Hub', latitude: 32.1877, longitude: 74.1945, radiusKm: 18.0),
    DeliveryHub(name: 'Hyderabad Hub', latitude: 25.3960, longitude: 68.3578, radiusKm: 18.0),
  ];

  static double calculateDistanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0; // Earth's radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  /// Comprehensive serviceability evaluation with tier, distance and time estimate
  static ServiceabilityResult evaluateServiceability({
    required double latitude,
    required double longitude,
    String? city,
  }) {
    DeliveryHub? closestHub;
    double minDistance = double.infinity;

    for (final hub in activeHubs) {
      final dist = calculateDistanceKm(latitude, longitude, hub.latitude, hub.longitude);
      if (dist < minDistance) {
        minDistance = dist;
        closestHub = hub;
      }
    }

    final hubName = closestHub?.name ?? 'Pakistan Central Fulfillment';

    // 1. Express 30m Check
    if (closestHub != null && minDistance <= closestHub.radiusKm) {
      final minutes = (30 + (minDistance * 0.8).round()).clamp(30, 45);
      return ServiceabilityResult(
        isServiceable: true,
        tier: DeliveryTier.express30m,
        estimatedMinutes: minutes,
        closestHubName: hubName,
        distanceKm: minDistance,
        displayEstimate: 'Express Delivery ($minutes mins)',
      );
    }

    // 2. Standard Same-Day (Outer metro or within 80km of active hub)
    if (minDistance <= 80.0 || (city != null && ['karachi', 'lahore', 'islamabad', 'rawalpindi', 'faisalabad'].contains(city.toLowerCase()))) {
      return ServiceabilityResult(
        isServiceable: true,
        tier: DeliveryTier.standardSameDay,
        estimatedMinutes: 360,
        closestHubName: hubName,
        distanceKm: minDistance,
        displayEstimate: 'Standard Same-Day Delivery',
      );
    }

    // 3. Pakistan Nationwide 3-5 days
    final isWithinPakistan = latitude >= 23.5 && latitude <= 37.5 && longitude >= 60.5 && longitude <= 78.0;
    if (isWithinPakistan) {
      return ServiceabilityResult(
        isServiceable: true,
        tier: DeliveryTier.nationwide3To5Days,
        estimatedMinutes: 4320,
        closestHubName: hubName,
        distanceKm: minDistance,
        displayEstimate: 'Nationwide Courier (3-5 Business Days)',
      );
    }

    // 4. Outside Coverage
    return ServiceabilityResult(
      isServiceable: false,
      tier: DeliveryTier.outsideCoverage,
      closestHubName: hubName,
      distanceKm: minDistance,
      displayEstimate: 'Outside Coverage Area',
    );
  }

  /// Check whether coordinates are serviced by Groclyra
  static ServiceabilityStatus checkServiceability({
    required double latitude,
    required double longitude,
    String? city,
  }) {
    final eval = evaluateServiceability(latitude: latitude, longitude: longitude, city: city);
    if (eval.tier == DeliveryTier.express30m) {
      return ServiceabilityStatus.expressAvailable;
    } else if (eval.isServiceable) {
      return ServiceabilityStatus.standardOnly;
    }
    return ServiceabilityStatus.unserviceable;
  }
}
