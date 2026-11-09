import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/shared/widgets/custom_text_field.dart';

import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';
import 'package:groclyra/features/customer/addresses/domain/entities/delivery_address_entity.dart';
import 'package:groclyra/features/customer/addresses/domain/services/delivery_serviceability_engine.dart';
import 'package:groclyra/features/customer/addresses/domain/services/pakistan_geo_data.dart';
import 'package:groclyra/features/customer/addresses/domain/services/pakistan_geocoding_service.dart';
import 'package:groclyra/features/customer/addresses/presentation/controllers/address_controller.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';


class AddEditAddressScreen extends ConsumerStatefulWidget {
  final DeliveryAddressEntity? existingAddress;

  const AddEditAddressScreen({super.key, this.existingAddress});

  @override
  ConsumerState<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends ConsumerState<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  late final MapController _mapController;
  late LatLng _selectedLocation;

  // Form controllers - clean & empty on new address entry
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _societyController = TextEditingController();
  final _sectorController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _selectedProvince = 'Punjab';
  AddressLabel _selectedLabel = AddressLabel.home;
  bool _isDefault = false;
  bool _isLocating = false;
  bool _isResolvingLocation = false;
  ResolvedPakistanLocation? _resolvedLocation;

  List<PakistanLocationSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.existingAddress != null) {
      final a = widget.existingAddress!;
      _selectedLocation = LatLng(a.latitude, a.longitude);
      _nameController.text = a.recipientName;
      _phoneController.text = a.recipientPhone;
      _selectedProvince = a.provinceOrTerritory;
      _cityController.text = a.city;
      _societyController.text = a.societyOrScheme ?? '';
      _sectorController.text = a.sectorOrBlock ?? '';
      _streetController.text = a.street;
      _houseController.text = a.houseOrFlat;
      _landmarkController.text = a.landmark ?? '';
      _instructionsController.text = a.deliveryInstructions ?? '';
      _selectedLabel = a.label;
      _isDefault = a.isDefault;
      _resolvedLocation = ResolvedPakistanLocation(
        latitude: a.latitude,
        longitude: a.longitude,
        province: a.provinceOrTerritory,
        city: a.city,
        societyOrScheme: a.societyOrScheme,
        sectorOrBlock: a.sectorOrBlock,
        roadOrStreet: a.street,
        houseOrNumber: a.houseOrFlat,
        landmark: a.landmark,
        formattedAddress: a.formattedAddress,
        displayName: a.shortDisplay,
      );
    } else {
      // Clean, empty fields for new address input - NEVER PRE-WRITE DUMMY ADDRESS!
      // Default live pin coordinates to Canal Berg, Multan Road, Lahore
      _selectedLocation = const LatLng(31.4771, 74.2467);
      _selectedProvince = 'Punjab';
      _isDefault = true;

      // Only pre-fill user's own profile contact info if logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final auth = ref.read(authControllerProvider);
        if (_nameController.text.isEmpty && auth.user?.name != null) {
          _nameController.text = auth.user!.name;
        }
        if (_phoneController.text.isEmpty && auth.user?.phone != null) {
          _phoneController.text = auth.user!.phone;
        }
        // Reverse geocode default coordinates to words for display
        _reverseGeocodePoint(_selectedLocation, autoFillEmptyFields: false);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _societyController.dispose();
    _sectorController.dispose();
    _streetController.dispose();
    _houseController.dispose();
    _landmarkController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocodePoint(LatLng point, {bool autoFillEmptyFields = false}) async {
    setState(() => _isResolvingLocation = true);
    try {
      final resolved = await PakistanGeocodingService.reverseGeocode(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted) return;
      setState(() {
        _resolvedLocation = resolved;
        _isResolvingLocation = false;
        if (autoFillEmptyFields) {
          if (_cityController.text.trim().isEmpty) {
            _cityController.text = resolved.city;
          }
          if (_societyController.text.trim().isEmpty && resolved.societyOrScheme != null) {
            _societyController.text = resolved.societyOrScheme!;
          }
          if (_streetController.text.trim().isEmpty && resolved.roadOrStreet != null) {
            _streetController.text = resolved.roadOrStreet!;
          }
          if (_houseController.text.trim().isEmpty && resolved.houseOrNumber != null) {
            _houseController.text = resolved.houseOrNumber!;
          }
          _selectedProvince = resolved.province;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isResolvingLocation = false);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );

        final newPos = LatLng(pos.latitude, pos.longitude);
        if (!mounted) return;
        setState(() {
          _selectedLocation = newPos;
        });
        _mapController.move(newPos, 15.0);
        await _reverseGeocodePoint(newPos, autoFillEmptyFields: false);

        if (!mounted) return;
        final words = _resolvedLocation?.shortWords ?? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        AppToggleMessage.success(
          context,
          'Pin located: $words (${pos.latitude.toStringAsFixed(4)}°N, ${pos.longitude.toStringAsFixed(4)}°E)',
          title: 'GPS Location Locked',
        );
      } else {
        if (!mounted) return;
        AppToggleMessage.warning(
          context,
          'Location permission was denied. You can pick your pin on the interactive map.',
          title: 'Permission Denied',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppToggleMessage.error(
        context,
        'Unable to acquire GPS location: $e',
        title: 'GPS Error',
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }

  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final results = PakistanGeoData.search(query);
    setState(() => _suggestions = results);
  }

  void _selectSuggestion(PakistanLocationSuggestion sug) {
    final pos = LatLng(sug.latitude, sug.longitude);
    setState(() {
      _selectedLocation = pos;
      _selectedProvince = sug.province;
      _cityController.text = sug.city;
      if (sug.society != null) {
        _societyController.text = sug.society!;
      }
      _suggestions = [];
      _searchController.text = sug.title;
    });
    _mapController.move(pos, 15.0);
    _reverseGeocodePoint(pos, autoFillEmptyFields: false);
  }

  ServiceabilityStatus get _currentServiceability {
    return DeliveryServiceabilityEngine.checkServiceability(
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      city: _cityController.text,
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authControllerProvider);
    final userId = (authState.user?.id.isNotEmpty == true && authState.user?.id != 'usr_guest')
        ? authState.user!.id
        : (AppDatabase.instance.activeSessionUserId ?? 'usr_guest');

    // Build formatted delivery address in words from what user physically wrote
    final parts = <String>[];
    if (_houseController.text.trim().isNotEmpty) parts.add(_houseController.text.trim());
    if (_streetController.text.trim().isNotEmpty) parts.add(_streetController.text.trim());
    if (_sectorController.text.trim().isNotEmpty) parts.add(_sectorController.text.trim());
    if (_societyController.text.trim().isNotEmpty) parts.add(_societyController.text.trim());
    if (_cityController.text.trim().isNotEmpty) parts.add(_cityController.text.trim());
    if (_selectedProvince.trim().isNotEmpty) parts.add(_selectedProvince.trim());
    final formatted = parts.join(', ');

    final address = DeliveryAddressEntity(
      id: widget.existingAddress?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      label: _selectedLabel,
      recipientName: _nameController.text.trim(),
      recipientPhone: _phoneController.text.trim(),
      provinceOrTerritory: _selectedProvince,
      district: _cityController.text.trim(),
      city: _cityController.text.trim(),
      locality: _societyController.text.trim().isNotEmpty
          ? _societyController.text.trim()
          : _cityController.text.trim(),
      societyOrScheme: _societyController.text.trim(),
      sectorOrBlock: _sectorController.text.trim(),
      street: _streetController.text.trim(),
      houseOrFlat: _houseController.text.trim(),
      landmark: _landmarkController.text.trim(),
      deliveryInstructions: _instructionsController.text.trim(),
      formattedAddress: formatted,
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      isDefault: _isDefault,
      serviceabilityStatus: _currentServiceability,
      createdAt: widget.existingAddress?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Persist to AddressController & Firestore
    await ref.read(addressControllerProvider.notifier).saveAddress(address);

    // Immediately sync to Auth state for user document consistency
    if (_isDefault || authState.user?.deliveryAddress == null) {
      ref.read(authControllerProvider.notifier).updateUserDeliveryAddress(
        deliveryAddress: formatted,
        deliveryZone: _cityController.text.trim(),
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
      );
    }

    if (mounted) {
      AppToggleMessage.success(
        context,
        'Address "$formatted" saved and synchronized successfully!',
        title: 'Address Saved',
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = themeState.palette.primaryColor;
    final serviceability = _currentServiceability;

    return Scaffold(
      appBar: GradientAppBar(
        title: widget.existingAddress != null ? 'Edit Address' : 'Add Delivery Address',
        subtitle: 'Live Pakistan Map & Coverage Verification',
        showBack: true,
        showThemePicker: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Interactive Map Picker
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                child: Container(
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedLocation,
                          initialZoom: 14.0,
                          onTap: (tapPosition, point) {
                            setState(() {
                              _selectedLocation = point;
                            });
                            _reverseGeocodePoint(point, autoFillEmptyFields: false);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.groclyra.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedLocation,
                                width: 50,
                                height: 50,
                                child: Icon(
                                  Icons.location_on_rounded,
                                  size: 46,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // GPS Current Location Floating Button
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'gps_fab',
                          backgroundColor: Colors.white,
                          onPressed: _isLocating ? null : _fetchCurrentLocation,
                          child: _isLocating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.my_location_rounded, color: primaryColor),
                        ),
                      ),

                      // Coordinates Chip Overlay
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '📍 ${_selectedLocation.latitude.toStringAsFixed(4)}°N, ${_selectedLocation.longitude.toStringAsFixed(4)}°E',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Live Pinpoint & Detected Words Card
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F2E) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.pin_drop_rounded, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Pinpoint Location',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_selectedLocation.latitude.toStringAsFixed(4)}°N, ${_selectedLocation.longitude.toStringAsFixed(4)}°E',
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_isResolvingLocation)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Detecting location in words...',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                                ),
                              ],
                            )
                          else
                            Text(
                              _resolvedLocation?.formattedAddress ??
                                  '${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              if (_resolvedLocation != null) {
                                setState(() {
                                  _cityController.text = _resolvedLocation!.city;
                                  if (_resolvedLocation!.societyOrScheme != null) {
                                    _societyController.text = _resolvedLocation!.societyOrScheme!;
                                  }
                                  if (_resolvedLocation!.roadOrStreet != null && _streetController.text.trim().isEmpty) {
                                    _streetController.text = _resolvedLocation!.roadOrStreet!;
                                  }
                                  if (_resolvedLocation!.houseOrNumber != null && _houseController.text.trim().isEmpty) {
                                    _houseController.text = _resolvedLocation!.houseOrNumber!;
                                  }
                                  _selectedProvince = _resolvedLocation!.province;
                                });
                                AppToggleMessage.info(
                                  context,
                                  'Auto-filled from map pin: ${_resolvedLocation!.shortWords}',
                                  title: 'Auto-fill Applied',
                                );
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_fix_high_rounded, size: 13, color: primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Auto-fill City & Society from Pin',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Center(
                child: Text(
                  'Tap anywhere on the map to place the delivery pin accurately',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Search Pakistan Places
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search society, sector or city (e.g. DHA, Clifton, Bahria)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _suggestions = []);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF141923) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF262E3D) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),

              // Suggestions Dropdown
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181E2B) : Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                      color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = _suggestions[idx];
                      return ListTile(
                        leading: Icon(Icons.location_city_rounded, color: primaryColor),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        onTap: () => _selectSuggestion(item),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),

              // 3. Serviceability Verification Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(serviceability.colorValue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: Color(serviceability.colorValue).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      serviceability == ServiceabilityStatus.expressAvailable
                          ? Icons.electric_bolt_rounded
                          : Icons.local_shipping_rounded,
                      color: Color(serviceability.colorValue),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceability.label,
                            style: TextStyle(
                              color: Color(serviceability.colorValue),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            serviceability == ServiceabilityStatus.expressAvailable
                                ? 'Eligible for 30-60 min Instant Express from our nearest micro-hub.'
                                : 'Eligible for reliable 24-48 hr standard delivery across Pakistan.',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Structured Address Fields
              const Text(
                'Delivery Address Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),

              // Province Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedProvince,
                decoration: InputDecoration(
                  labelText: 'Province / Territory',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF141923) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMedium)),
                ),
                items: PakistanGeoData.provinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedProvince = val);
                },
              ),
              const SizedBox(height: 12),

              // City
              CustomTextField(
                controller: _cityController,
                label: 'City / District *',
                hint: 'e.g. Lahore, Karachi, Islamabad, Faisalabad, Rawalpindi',
                prefixIcon: const Icon(Icons.location_city_rounded, size: 20),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter city' : null,
              ),
              const SizedBox(height: 12),

              // Housing Society / Scheme / Locality
              CustomTextField(
                controller: _societyController,
                label: 'Housing Society / Scheme / Locality *',
                hint: 'e.g. Canal Berg Housing Scheme, DHA Phase 5, Bahria Town, Gulberg',
                prefixIcon: const Icon(Icons.holiday_village_rounded, size: 20),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter society or area' : null,
              ),
              const SizedBox(height: 12),

              // Sector / Block
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _sectorController,
                      label: 'Sector / Block / Phase',
                      hint: 'e.g. 9-H, Sector C, Block 5, Phase 6',
                      prefixIcon: const Icon(Icons.grid_view_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _streetController,
                      label: 'Street / Road *',
                      hint: 'e.g. Multan Road, Canal Bank Road, Main Boulevard, Street 14',
                      prefixIcon: const Icon(Icons.signpost_rounded, size: 20),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter street' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // House / Flat No & Landmark
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _houseController,
                      label: 'House / Flat # *',
                      hint: 'e.g. 9-H, House 14-B, Flat 402, Villa 21',
                      prefixIcon: const Icon(Icons.home_rounded, size: 20),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter house number' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _landmarkController,
                      label: 'Nearest Landmark',
                      hint: 'e.g. Near Thokar Niaz Baig / Jamia Masjid',
                      prefixIcon: const Icon(Icons.flag_rounded, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),


              // Delivery Instructions
              CustomTextField(
                controller: _instructionsController,
                label: 'Delivery Instructions (Optional)',
                hint: 'e.g. Ring bell twice, leave with security guard, call on arrival',
                prefixIcon: const Icon(Icons.note_alt_rounded, size: 20),
              ),
              const SizedBox(height: 16),

              // Recipient Details
              const Text(
                'Contact Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _nameController,
                      label: 'Recipient Name *',
                      hint: 'e.g. Muhammad Ali',
                      prefixIcon: const Icon(Icons.person_rounded, size: 20),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _phoneController,
                      label: 'Phone Number *',
                      hint: 'e.g. 0300 1234567',
                      prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter phone' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),


              // Address Label Radio Chips (Home, Work, Other)
              const Text(
                'Save As Label',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: AddressLabel.values.map((label) {
                  final isSelected = _selectedLabel == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label.icon),
                          const SizedBox(width: 6),
                          Text(label.displayName),
                        ],
                      ),
                      selectedColor: primaryColor.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.3),
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedLabel = label);
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Default Address Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as Default Delivery Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Use this address automatically during checkout', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _isDefault,
                activeThumbColor: primaryColor,
                onChanged: (val) => setState(() => _isDefault = val),
              ),
              const SizedBox(height: 24),

              // Save Button
              GradientButton(
                text: widget.existingAddress != null ? 'Update Address' : 'Save Delivery Address',
                onPressed: _saveAddress,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
