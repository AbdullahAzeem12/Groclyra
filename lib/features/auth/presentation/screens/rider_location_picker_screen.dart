import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/features/auth/domain/entities/rider_location.dart';

class RiderLocationPickerScreen extends StatefulWidget {
  const RiderLocationPickerScreen({super.key});

  @override
  State<RiderLocationPickerScreen> createState() => _RiderLocationPickerScreenState();
}

class _RiderLocationPickerScreenState extends State<RiderLocationPickerScreen> {
  final MapController _mapController = MapController();
  
  // Default to Pakistan's geographical center roughly
  final LatLng _initialPosition = const LatLng(30.3753, 69.3451);

  LatLng? _selectedLocation;
  String? _addressName;
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndGetLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    setState(() => _isLoading = true);
    
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Location services are disabled.');
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permissions are denied');
        setState(() => _isLoading = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _showError('Location permissions are permanently denied, we cannot request permissions.');
      setState(() => _isLoading = false);
      return;
    } 

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );
      
      final currentLatLng = LatLng(position.latitude, position.longitude);
      await _moveToLocation(currentLatLng);
      await _updateAddressFromLatLng(currentLatLng);
    } catch (e) {
      _showError('Failed to get current location: \$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _moveToLocation(LatLng location) async {
    _mapController.move(location, 16.0);
    setState(() {
      _selectedLocation = location;
    });
  }

  Future<void> _updateAddressFromLatLng(LatLng location) async {
    try {
      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _addressName = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
          // Clean up empty fields
          _addressName = _addressName!.replaceAll(RegExp(r', \s*,'), ',').replaceAll(RegExp(r'^[,\s]+|[,\s]+\$'), '');
        });
      }
    } catch (e) {
      setState(() {
        _addressName = 'Coordinates: \${location.latitude.toStringAsFixed(4)}, \${location.longitude.toStringAsFixed(4)}';
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _confirmLocation() {
    if (_selectedLocation == null || _addressName == null) {
      _showError('Please wait for the location to load or tap on the map to select.');
      return;
    }

    final locationResult = RiderLocation(
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      formattedAddress: _addressName!,
      source: 'map',
    );

    context.pop(locationResult);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Delivery Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _checkPermissionsAndGetLocation,
              tooltip: 'Current Location',
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 5.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _selectedLocation = position.center;
                    _addressName = "Searching...";
                  });
                  
                  if (_debounce?.isActive ?? false) _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    if (_selectedLocation != null) {
                      _updateAddressFromLatLng(_selectedLocation!);
                    }
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.groclyra',
              ),
            ],
          ),
          
          // Center Marker (Static pin while map moves underneath)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 35.0), // Offset to point to exact center
              child: Icon(Icons.location_on, size: 40, color: Colors.red),
            ),
          ),
          
          // Bottom Info Sheet
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Selected Zone',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _addressName ?? 'Move the map to select a zone...',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _confirmLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                      ),
                    ),
                    child: const Text('Confirm Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
