import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/rider_location.dart';
import '../screens/rider_location_picker_screen.dart';
import '../../../../shared/animations/spring_touch_scale.dart';

class LocationSelectorBottomSheet extends ConsumerStatefulWidget {
  const LocationSelectorBottomSheet({super.key});

  @override
  ConsumerState<LocationSelectorBottomSheet> createState() => _LocationSelectorBottomSheetState();
}

class _LocationSelectorBottomSheetState extends ConsumerState<LocationSelectorBottomSheet> {
  bool isSearchingManual = false;
  bool isLoadingGps = false;

  String? selectedProvince;
  String? selectedDistrict;
  String? selectedCity;

  @override
  Widget build(BuildContext context) {
    final locationService = ref.read(locationServiceProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: isSearchingManual ? _buildManualSelector(locationService) : _buildMainMenu(locationService),
    );
  }

  Widget _buildMainMenu(LocationService locationService) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Delivery Zone",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.my_location, color: Colors.green),
          title: const Text("Use My Current Location"),
          subtitle: const Text("Requires GPS permission"),
          trailing: isLoadingGps ? const CircularProgressIndicator() : const Icon(Icons.chevron_right),
          onTap: isLoadingGps ? null : () => _handleGpsLocation(locationService),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.search, color: Colors.blue),
          title: const Text("Select Manually"),
          subtitle: const Text("Browse provinces, districts, and cities"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setState(() {
              isSearchingManual = true;
            });
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildManualSelector(LocationService locationService) {
    List<String> provinces = locationService.getProvinces();
    List<String> districts = selectedProvince != null ? locationService.getDistricts(selectedProvince!) : [];
    List<String> cities = (selectedProvince != null && selectedDistrict != null)
        ? locationService.getCities(selectedProvince!, selectedDistrict!)
        : [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SpringTouchScale(
              navigationDelayMs: 165,
              scaleFactor: 0.88,
              pressDepth: 3.5,
              enableRipple: false,
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (selectedCity != null) {
                  setState(() => selectedCity = null);
                } else if (selectedDistrict != null) {
                  setState(() => selectedDistrict = null);
                } else if (selectedProvince != null) {
                  setState(() => selectedProvince = null);
                } else {
                  setState(() => isSearchingManual = false);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.arrow_back),
              ),
            ),
            Expanded(
              child: Text(
                selectedDistrict != null
                    ? "Select City"
                    : selectedProvince != null
                        ? "Select District"
                        : "Select Province",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: selectedDistrict != null
                ? cities.length
                : selectedProvince != null
                    ? districts.length
                    : provinces.length,
            itemBuilder: (context, index) {
              String itemName = selectedDistrict != null
                  ? cities[index]
                  : selectedProvince != null
                      ? districts[index]
                      : provinces[index];

              return ListTile(
                title: Text(itemName),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () {
                  if (selectedProvince == null) {
                    setState(() => selectedProvince = itemName);
                  } else if (selectedDistrict == null) {
                    setState(() => selectedDistrict = itemName);
                  } else {
                    // City selected, complete!
                    final location = RiderLocation(
                      country: 'Pakistan',
                      province: selectedProvince,
                      district: selectedDistrict,
                      city: itemName,
                      formattedAddress: "$itemName, $selectedDistrict, $selectedProvince",
                      source: 'manual',
                    );
                    Navigator.pop(context, location);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleGpsLocation(LocationService locationService) async {
    setState(() {
      isLoadingGps = true;
    });

    final position = await locationService.getCurrentPosition();
    
    if (!mounted) return;
    
    setState(() {
      isLoadingGps = false;
    });

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get location. Please enable GPS and permissions.')),
      );
      return;
    }

    final RiderLocation? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RiderLocationPickerScreen(),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }
}
