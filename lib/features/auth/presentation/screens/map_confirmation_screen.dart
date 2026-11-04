import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/rider_location.dart';

class MapConfirmationScreen extends ConsumerStatefulWidget {
  final Position initialPosition;

  const MapConfirmationScreen({super.key, required this.initialPosition});

  @override
  ConsumerState<MapConfirmationScreen> createState() => _MapConfirmationScreenState();
}

class _MapConfirmationScreenState extends ConsumerState<MapConfirmationScreen> {
  final MapController mapController = MapController();
  late LatLng currentLatLng;
  String currentAddress = "Fetching address...";
  bool isDragging = false;
  RiderLocation? confirmedLocation;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    currentLatLng = LatLng(widget.initialPosition.latitude, widget.initialPosition.longitude);
    _updateAddress(currentLatLng);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    mapController.dispose();
    super.dispose();
  }

  Future<void> _updateAddress(LatLng position) async {
    final locationService = ref.read(locationServiceProvider);
    final placemark = await locationService.getAddressFromCoordinates(position.latitude, position.longitude);

    if (!mounted) return;

    if (placemark != null) {
      final formattedAddress = '${placemark.street ?? ''}, ${placemark.subLocality ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}, ${placemark.country ?? ''}'.replaceAll(RegExp(r'^,\s*|,\s*(?=,)'), '');
      
      setState(() {
        currentAddress = formattedAddress;
        confirmedLocation = RiderLocation(
          country: placemark.country,
          province: placemark.administrativeArea,
          division: null, // Reverse geocoding usually doesn't give division
          district: placemark.subAdministrativeArea,
          tehsil: null,
          city: placemark.locality,
          locality: placemark.subLocality,
          formattedAddress: formattedAddress,
          latitude: position.latitude,
          longitude: position.longitude,
          source: 'gps',
        );
      });
    } else {
      setState(() {
        currentAddress = "Address not found";
        confirmedLocation = RiderLocation(
          country: 'Pakistan',
          formattedAddress: "${position.latitude}, ${position.longitude}",
          latitude: position.latitude,
          longitude: position.longitude,
          source: 'gps',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirm Location"),
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentLatLng,
              initialZoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  if (!isDragging) {
                    setState(() {
                      isDragging = true;
                      currentAddress = "Dragging...";
                    });
                  }
                  currentLatLng = position.center;
                  
                  if (_debounce?.isActive ?? false) _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      setState(() {
                        isDragging = false;
                      });
                      _updateAddress(currentLatLng);
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
          // Center Pin Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Icon(
                Icons.location_pin,
                size: 40,
                color: isDragging ? Colors.grey : Colors.red,
              ),
            ),
          ),
          // My Location Button
          Positioned(
            bottom: 180,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'my_location',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () async {
                final pos = await Geolocator.getCurrentPosition();
                mapController.move(LatLng(pos.latitude, pos.longitude), 15);
              },
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),
          // Bottom Info Box
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Delivery Address",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentAddress,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isDragging || confirmedLocation == null
                        ? null
                        : () {
                            Navigator.pop(context, confirmedLocation);
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("CONFIRM LOCATION"),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
