import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../database/app_database.dart';

class RiderLocationState {
  final bool isTracking;
  final Position? currentPosition;
  final String? activeRiderId;
  final String? statusMessage;

  const RiderLocationState({
    this.isTracking = false,
    this.currentPosition,
    this.activeRiderId,
    this.statusMessage,
  });

  RiderLocationState copyWith({
    bool? isTracking,
    Position? currentPosition,
    String? activeRiderId,
    String? statusMessage,
  }) {
    return RiderLocationState(
      isTracking: isTracking ?? this.isTracking,
      currentPosition: currentPosition ?? this.currentPosition,
      activeRiderId: activeRiderId ?? this.activeRiderId,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

final riderBackgroundLocationProvider =
    StateNotifierProvider<RiderBackgroundLocationNotifier, RiderLocationState>((ref) {
  return RiderBackgroundLocationNotifier();
});

class RiderBackgroundLocationNotifier extends StateNotifier<RiderLocationState> {
  StreamSubscription<Position>? _positionSub;

  RiderBackgroundLocationNotifier() : super(const RiderLocationState());

  /// Starts persistent foreground GPS tracking for the active rider
  Future<bool> startTracking(String riderId) async {
    if (state.isTracking) return true;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(statusMessage: 'Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(statusMessage: 'Location permission permanently denied');
        return false;
      }

      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        state = state.copyWith(statusMessage: 'Device GPS is disabled');
        return false;
      }

      // Configure Foreground Notification for Android background operation
      final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 4,
          intervalDuration: const Duration(seconds: 4),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Groclyra Express Fulfillment',
            notificationText: 'Live route sharing active • Updating delivery milestones',
            enableWakeLock: true,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 4,
        );
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) => _onPositionUpdate(riderId, position),
        onError: (err) {
          debugPrint('[RiderBackgroundLocation] Stream error: $err');
          state = state.copyWith(statusMessage: 'GPS Error: $err');
        },
      );

      // Immediately fetch current position
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _onPositionUpdate(riderId, initial);

      state = state.copyWith(
        isTracking: true,
        activeRiderId: riderId,
        currentPosition: initial,
        statusMessage: 'Foreground GPS Active',
      );

      return true;
    } catch (e) {
      debugPrint('[RiderBackgroundLocation] Start failed: $e');
      state = state.copyWith(
        isTracking: false,
        statusMessage: 'Failed to start GPS tracking: $e',
      );
      return false;
    }
  }

  Future<void> _onPositionUpdate(String riderId, Position position) async {
    state = state.copyWith(currentPosition: position);

    final now = DateTime.now().toIso8601String();
    final db = AppDatabase.instance;

    try {
      // 1. Update rider_profiles
      await db.update(
        'rider_profiles',
        {
          'currentLat': position.latitude,
          'currentLng': position.longitude,
          'updatedAt': now,
        },
        where: 'riderId = ?',
        whereArgs: [riderId],
      );

      // 2. Update active delivery_tasks assigned to this rider
      await db.update(
        'delivery_tasks',
        {
          'riderLat': position.latitude,
          'riderLng': position.longitude,
          'updatedAt': now,
        },
        where: "riderId = ? AND status IN ('accepted', 'pickedUp', 'inTransit')",
        whereArgs: [riderId],
      );

      // 3. Notify real-time watchers for cross-portal reactivity
      db.notifyTable('rider_profiles');
      db.notifyTable('delivery_tasks');
    } catch (e) {
      debugPrint('[RiderBackgroundLocation] DB Update error: $e');
    }
  }

  Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;

    state = state.copyWith(
      isTracking: false,
      statusMessage: 'GPS Tracking Stopped',
    );
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

