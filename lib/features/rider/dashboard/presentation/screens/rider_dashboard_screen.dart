import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/features/rider/domain/entities/delivery_task_entity.dart';
import 'package:groclyra/features/rider/presentation/controllers/rider_controller.dart';

import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:geolocator/geolocator.dart';
import 'package:groclyra/core/services/maps_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:groclyra/shared/animations/rotating_border_glow_card.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';

class RiderDashboardScreen extends ConsumerStatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  ConsumerState<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends ConsumerState<RiderDashboardScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  
  // Live Map variables
  final MapController _mapController = MapController();
  Position? _currentPosition;
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    
    _initLiveMap();
  }
  
  Future<void> _initLiveMap() async {
    final pos = await MapsService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _currentPosition = pos);
    }
    _locationSub = MapsService.streamLocation().listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _locationSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final riderState = ref.watch(riderControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Express Rider Console',
        // FIX: was the hard-coded "Muhammad Bilal • KHI-LEJ-4821" for every
        // rider; now shows the authenticated rider's real name and vehicle.
        subtitle: '${authState.user?.name ?? 'Rider'}'
            '${(authState.user?.vehicleNumber?.isNotEmpty ?? false) ? ' • ${authState.user!.vehicleNumber}' : ''}',
        // Phase 1B: real-time notification centre
        showNotificationBell: true,
        actions: [
          IconButton(
            tooltip: 'Switch Portal',
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            onPressed: () => context.go(RouteNames.login),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(riderControllerProvider.notifier).loadTasks(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Online / Offline Duty Switch Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: riderState.isOnline ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: riderState.isOnline ? Colors.green : Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      riderState.isOnline ? Icons.radar_rounded : Icons.power_settings_new_rounded,
                      color: riderState.isOnline ? Colors.green : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riderState.isOnline ? 'You Are ON DUTY' : 'You Are OFF DUTY',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: riderState.isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          Text(
                            riderState.isOnline ? 'Active for new pickup & delivery dispatches' : 'Turn on duty to receive delivery assignments',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: riderState.isOnline,
                      activeThumbColor: Colors.green,
                      onChanged: (val) {
                        ref.read(riderControllerProvider.notifier).toggleOnline(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // KPI Earnings & COD Summary
              Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      title: "Today's Earnings",
                      value: CurrencyFormatter.format(riderState.todayEarnings),
                      icon: Icons.payments_rounded,
                      color: Colors.green,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetric(
                      title: 'COD Cash in Hand',
                      value: CurrencyFormatter.format(riderState.codCashInHand),
                      icon: Icons.account_balance_wallet_rounded,
                      color: Colors.amber,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Active Delivery Queue Heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Active Dispatch Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${riderState.tasks.length} Assigned',
                    style: TextStyle(fontSize: 12, color: themeState.palette.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Live Tracking Mini Map
              if (riderState.tasks.isNotEmpty && riderState.isOnline)
                Container(
                  height: 180,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: themeState.palette.primaryColor.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(color: themeState.palette.primaryColor.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 2),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium - 2),
                    child: Stack(
                      children: [
                        if (_currentPosition != null)
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              initialZoom: 15.0,
                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: isDark
                                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                                    : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                    width: 40,
                                    height: 40,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                      ),
                                      child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
                                    ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1500.ms),
                                  ),
                                  ...riderState.tasks.map((t) => Marker(
                                        point: LatLng(
                                            t.customerAddress.length > 20 ? 24.86 + (t.hashCode % 100) * 0.0001 : 24.86,
                                            67.00 + (t.hashCode % 100) * 0.0001),
                                        width: 30,
                                        height: 30,
                                        child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                                      )),
                                ],
                              ),
                            ],
                          )
                        else
                          const Center(child: CircularProgressIndicator()),
                        
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.satellite_alt_rounded, color: Colors.greenAccent, size: 12),
                                SizedBox(width: 4),
                                Text('LIVE GPS', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(begin: 0.5, end: 1.0, duration: 800.ms),
                        ),
                      ],
                    ),
                  ),
                ).animate().slideY(begin: -0.1).fadeIn(),

              ...riderState.tasks.map((task) {
                final isAccepted = task.status == DeliveryTaskStatus.accepted;
                return SpringTouchScale(
                  onTap: () => context.push('${RouteNames.riderNavigate}/${task.id}'),
                  enableRipple: true,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: RotatingBorderGlowCard(
                      rotateController: _glowController,
                      color: isAccepted ? themeState.palette.primaryColor : (isDark ? Colors.white24 : Colors.grey),
                      secondaryColor: isAccepted ? Colors.white : Colors.transparent,
                      phaseOffset: (task.hashCode % 100) / 100.0,
                      isDark: isDark,
                      borderRadius: AppDimensions.radiusMedium,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF121722) : Colors.white,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Delivery #${task.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: task.status.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    task.status.label,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: task.status.color),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Seller Pickup Address
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.storefront_rounded, size: 18, color: Colors.indigo),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Pickup: ${task.sellerStoreName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(task.sellerAddress, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Customer Drop-off Address
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 18, color: Colors.redAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Drop-off: ${task.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(task.customerAddress, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Distance, COD & Action
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.isCod ? 'Collect COD: ${CurrencyFormatter.format(task.codAmount)}' : 'Prepaid (No Cash)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: task.isCod ? Colors.green : Colors.blue,
                                      ),
                                    ),
                                    Text('Distance: ${task.distanceKm} km • Earning: ${CurrencyFormatter.format(task.estimatedEarnings)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.navigation_rounded, size: 16),
                                  label: const Text('Start Route', style: TextStyle(fontSize: 12)),
                                  onPressed: () => context.push('${RouteNames.riderNavigate}/${task.id}'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
