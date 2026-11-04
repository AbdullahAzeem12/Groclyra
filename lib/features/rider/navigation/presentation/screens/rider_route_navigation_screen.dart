import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/services/maps_service.dart' hide LatLngPoint;
import 'package:groclyra/core/services/maps_service.dart' as ms;
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/rider/domain/entities/delivery_task_entity.dart';
import 'package:groclyra/features/rider/presentation/controllers/rider_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';

class RiderRouteNavigationScreen extends ConsumerStatefulWidget {
  final String taskId;

  const RiderRouteNavigationScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<RiderRouteNavigationScreen> createState() =>
      _RiderRouteNavigationScreenState();
}

class _RiderRouteNavigationScreenState
    extends ConsumerState<RiderRouteNavigationScreen> {
  final MapController _mapController = MapController();

  // Live GPS
  Position? _currentPosition;
  StreamSubscription<Position>? _locationSub;

  // Route data
  ms.RouteResult? _route;
  bool _routeLoading = true;
  int _currentStepIndex = 0;

  // Map elements
  List<Polyline> _polylines = [];
  final List<Marker> _markers = [];

  // Delivery task
  DeliveryTaskEntity? _task;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Resolve task
    final riderState = ref.read(riderControllerProvider);
    final task = riderState.tasks.firstWhere(
      (t) => t.id == widget.taskId,
      orElse: () => riderState.tasks.isNotEmpty
          ? riderState.tasks.first
          : _placeholder(),
    );
    setState(() => _task = task);

    // Get initial GPS fix
    final pos = await MapsService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _currentPosition = pos);
      _addRiderMarker(LatLng(pos.latitude, pos.longitude));
      await _loadRoute(pos, task);
    }

    // Start live GPS tracking
    _locationSub = MapsService.streamLocation().listen((pos) async {
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _advanceStep(pos);
      });
      _addRiderMarker(LatLng(pos.latitude, pos.longitude));
      _mapController.move(
        LatLng(pos.latitude, pos.longitude),
        _mapController.camera.zoom,
      );

      // Sync to Firestore
      final riderId = ref.read(authControllerProvider).user?.id ?? '';
      if (riderId.isNotEmpty) {
        MapsService.updateRiderLocation(riderId, pos);
      }
    });
  }

  Future<void> _loadRoute(Position riderPos, DeliveryTaskEntity task) async {
    setState(() => _routeLoading = true);

    final origin = ms.LatLngPoint(lat: riderPos.latitude, lng: riderPos.longitude);
    final destination = await _resolveDestination(task);

    if (destination == null) {
      if (mounted) setState(() => _routeLoading = false);
      return;
    }

    final route = await MapsService.getDirections(
      origin: origin,
      destination: destination,
    );

    if (!mounted) return;
    setState(() {
      _route = route;
      _routeLoading = false;
    });

    if (route != null) {
      _buildPolylines(route);
      _addDestinationMarker(LatLng(destination.lat, destination.lng), task);
      _fitBounds(
        LatLng(riderPos.latitude, riderPos.longitude),
        LatLng(destination.lat, destination.lng),
      );
    }
  }

  Future<ms.LatLngPoint?> _resolveDestination(DeliveryTaskEntity task) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('deliveryTasks')
          .doc(task.id)
          .get();
      final data = doc.data();
      if (data != null) {
        final lat = (data['customerLat'] as num?)?.toDouble();
        final lng = (data['customerLng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return ms.LatLngPoint(lat: lat, lng: lng);
        }
      }
    } catch (_) {}

    return const ms.LatLngPoint(lat: 24.8607, lng: 67.0011);
  }

  void _buildPolylines(ms.RouteResult route) {
    final points = route.polylinePoints
        .map((p) => LatLng(p.lat, p.lng))
        .toList();

    setState(() {
      _polylines = [
        Polyline(
          points: points,
          color: const Color(0xFF6366F1),
          strokeWidth: 5,
        ),
      ];
    });
  }

  void _addRiderMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.key == const Key('rider'));
      _markers.add(
        Marker(
          key: const Key('rider'),
          point: position,
          width: 40,
          height: 40,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
          ),
        ),
      );
    });
  }

  void _addDestinationMarker(LatLng position, DeliveryTaskEntity task) {
    setState(() {
      _markers.removeWhere((m) => m.key == const Key('destination'));
      _markers.add(
        Marker(
          key: const Key('destination'),
          point: position,
          width: 40,
          height: 40,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
          ),
        ),
      );
    });
  }

  void _fitBounds(LatLng sw, LatLng ne) {
    final bounds = LatLngBounds(
      LatLng(
          sw.latitude < ne.latitude ? sw.latitude : ne.latitude,
          sw.longitude < ne.longitude ? sw.longitude : ne.longitude),
      LatLng(
          sw.latitude > ne.latitude ? sw.latitude : ne.latitude,
          sw.longitude > ne.longitude ? sw.longitude : ne.longitude),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50.0),
      ),
    );
  }

  void _advanceStep(Position pos) {
    final route = _route;
    if (route == null) return;
    if (_currentStepIndex >= route.steps.length - 1) return;

    final nextStep = route.steps[_currentStepIndex];
    final dist = MapsService.haversineKm(
      ms.LatLngPoint(lat: pos.latitude, lng: pos.longitude),
      ms.LatLngPoint(lat: nextStep.startLat, lng: nextStep.startLng),
    );

    if (dist < 0.03) {
      setState(() => _currentStepIndex++);
    }
  }

  DeliveryTaskEntity _placeholder() => DeliveryTaskEntity(
        id: widget.taskId,
        subOrderId: '',
        orderNumber: '---',
        sellerStoreName: '',
        sellerAddress: '',
        sellerPhone: '',
        customerName: 'Customer',
        customerAddress: 'Loading...',
        customerPhone: '',
        distanceKm: 0,
        codAmount: 0,
        estimatedEarnings: 0,
        status: DeliveryTaskStatus.accepted,
        customerOtp: '',
        assignedAt: DateTime.now(),
      );

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final task = _task;
    final route = _route;
    final currentStep =
        (route != null && route.steps.isNotEmpty && _currentStepIndex < route.steps.length)
            ? route.steps[_currentStepIndex]
            : null;

    final initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(24.8607, 67.0011); // Karachi

    // For dark mode, use CartoDB Dark Matter free tiles. Otherwise standard OSM.
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: Text(
          task != null ? 'Route #${task.orderNumber}' : 'Navigation',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (task != null)
            IconButton(
              icon: const Icon(Icons.phone_rounded, color: Colors.green),
              tooltip: 'Call Customer',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Calling ${task.customerName}: ${task.customerPhone}',
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Re-centre',
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  16,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── FLUTTER MAP (OSM) ──────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 15.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileUrl,
                      userAgentPackageName: 'com.example.groclyra',
                    ),
                    PolylineLayer(
                      polylines: _polylines,
                    ),
                    MarkerLayer(
                      markers: _markers,
                    ),
                  ],
                ),

                // Loading overlay
                if (_routeLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black38,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Calculating Route…',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Turn-by-turn banner
                if (currentStep != null && !_routeLoading)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _TurnBanner(
                      step: currentStep,
                      palette: themeState.palette,
                      stepIndex: _currentStepIndex,
                      totalSteps: route?.steps.length ?? 0,
                    ),
                  ),
              ],
            ),
          ),

          // ── BOTTOM PANEL ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121722) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ETA + distance row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (task != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                task.customerAddress,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      if (route != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              route.formattedDuration,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              route.formattedDistance,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // COD badge
                  if (task != null && task.isCod)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.payments_rounded,
                                  color: Colors.green, size: 18),
                              SizedBox(width: 6),
                              Text('Collect Cash (COD):',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.format(task.codAmount),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ],
                      ),
                    ),

                  // Arrived button → POD
                  GradientButton(
                    text: 'Arrived — Verify Delivery (OTP/POD)',
                    icon: Icons.qr_code_scanner_rounded,
                    onPressed: task != null
                        ? () => context.push('${RouteNames.riderPod}/${task.id}')
                        : null,
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

// ─────────────────────────────────────────────────────────────────────────────
// TURN BANNER WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _TurnBanner extends StatelessWidget {
  final ms.DirectionsStep step;
  final dynamic palette;
  final int stepIndex;
  final int totalSteps;

  const _TurnBanner({
    required this.step,
    required this.palette,
    required this.stepIndex,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: palette.linearGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(step.maneuverIcon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${step.formattedDistance} · ${step.formattedDuration}'
                  '  (Step ${stepIndex + 1}/$totalSteps)',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
