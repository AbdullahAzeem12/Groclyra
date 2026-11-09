import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/features/admin/presentation/controllers/admin_controller.dart';
import 'package:groclyra/features/admin/data/repositories/admin_repository.dart';
import 'package:groclyra/features/admin/domain/entities/connection_status.dart';

class SystemHealthTelemetryScreen extends ConsumerStatefulWidget {
  const SystemHealthTelemetryScreen({super.key});

  @override
  ConsumerState<SystemHealthTelemetryScreen> createState() =>
      _SystemHealthTelemetryScreenState();
}

class _SystemHealthTelemetryScreenState
    extends ConsumerState<SystemHealthTelemetryScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Auto-refresh every 30s
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final services = adminState.serviceHealth;
    final events = adminState.liveEvents;
    final analytics = adminState.analytics;

    final healthyCount = services.where((s) => s.status == ServiceHealthStatus.healthy).length;
    final degradedCount = services.where((s) => s.status == ServiceHealthStatus.degraded).length;
    final downCount = services.where((s) => s.status == ServiceHealthStatus.down).length;
    final unknownCount = services.where((s) => s.status == ServiceHealthStatus.unknown).length;
    final overallHealthy = degradedCount == 0 && downCount == 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B101D) : const Color(0xFFF1F5F9),
      appBar: GradientAppBar(
        title: 'System Health & Telemetry',
        subtitle: overallHealthy ? 'All services operational' : '$degradedCount degraded · $downCount down',
        showThemePicker: false,
        actions: [
          IconButton(
            tooltip: 'Manual Refresh',
            icon: AnimatedBuilder(
              animation: _rotateController,
              builder: (_, child) => adminState.isLoading
                  ? Transform.rotate(
                      angle: _rotateController.value * 6.28,
                      child: child,
                    )
                  : child!,
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(adminControllerProvider.notifier).loadDashboard();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.tealAccent,
        onRefresh: () {
          HapticFeedback.mediumImpact();
          return ref.read(adminControllerProvider.notifier).loadDashboard();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── OVERALL STATUS HERO ──────────────────────────────────
                  _OverallStatusHero(
                    healthyCount: healthyCount,
                    degradedCount: degradedCount,
                    downCount: downCount,
                    unknownCount: unknownCount,
                    total: services.length,
                    overallHealthy: overallHealthy,
                    pulseController: _pulseController,
                    connectionStatus: adminState.connectionStatus,
                    isDark: isDark,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 14),

                  // ── PLATFORM METRICS ROW ─────────────────────────────────
                  _PlatformMetricsRow(analytics: analytics, isDark: isDark)
                      .animate().fadeIn(duration: 400.ms, delay: 80.ms),

                  const SizedBox(height: 20),

                  // ── SERVICE LIST HEADER ──────────────────────────────────
                  _SectionHeader(
                    title: 'Service Monitoring',
                    subtitle: '${services.length} services tracked',
                    icon: Icons.monitor_heart_outlined,
                    isDark: isDark,
                  ).animate().fadeIn(duration: 400.ms, delay: 120.ms),

                  const SizedBox(height: 10),

                  // ── SERVICE CARDS ─────────────────────────────────────────
                  ...services.asMap().entries.map((e) {
                    final i = e.key;
                    final service = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ServiceCard(
                        service: service,
                        isDark: isDark,
                        pulseController: _pulseController,
                      ).animate().fadeIn(duration: 350.ms, delay: (120 + i * 60).ms).slideX(begin: 0.04, end: 0),
                    );
                  }),

                  // ── LIVE AUDIT LOG ────────────────────────────────────────
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'Live Audit Log',
                    subtitle: '${events.length} recent events',
                    icon: Icons.history,
                    isDark: isDark,
                    badge: events.isNotEmpty ? events.length : null,
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                  const SizedBox(height: 10),

                  if (events.isEmpty)
                    _EmptyEventState(isDark: isDark)
                        .animate().fadeIn(duration: 400.ms, delay: 350.ms)
                  else
                    ...events.take(20).toList().asMap().entries.map((e) {
                      final i = e.key;
                      final event = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AuditEventTile(event: event, isDark: isDark)
                            .animate().fadeIn(duration: 300.ms, delay: (350 + i * 40).ms),
                      );
                    }),

                  const SizedBox(height: 20),

                  // ── SYNC INFO ─────────────────────────────────────────────
                  _TelemetrySyncInfo(
                    state: adminState,
                    isDark: isDark,
                  ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overall Status Hero
// ─────────────────────────────────────────────────────────────────────────────

class _OverallStatusHero extends StatelessWidget {
  final int healthyCount, degradedCount, downCount, unknownCount, total;
  final bool overallHealthy;
  final AnimationController pulseController;
  final ConnectionStatus connectionStatus;
  final bool isDark;

  const _OverallStatusHero({
    required this.healthyCount,
    required this.degradedCount,
    required this.downCount,
    required this.unknownCount,
    required this.total,
    required this.overallHealthy,
    required this.pulseController,
    required this.connectionStatus,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final heroColor = downCount > 0
        ? Colors.red
        : degradedCount > 0
            ? Colors.orange
            : unknownCount == total
                ? Colors.grey
                : Colors.green;

    final heroLabel = downCount > 0
        ? 'System Incident Detected'
        : degradedCount > 0
            ? 'Partial Degradation'
            : unknownCount == total
                ? 'Awaiting Health Data'
                : 'All Systems Operational';

    final heroIcon = downCount > 0
        ? Icons.error_rounded
        : degradedCount > 0
            ? Icons.warning_amber_rounded
            : unknownCount == total
                ? Icons.sync_problem_rounded
                : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1A2340)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: heroColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [BoxShadow(color: heroColor.withValues(alpha: 0.1), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseController,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: heroColor.withValues(alpha: 0.08 + 0.07 * pulseController.value),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: heroColor.withValues(alpha: 0.2 + 0.15 * pulseController.value),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(heroIcon, color: heroColor, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heroLabel,
                      style: TextStyle(
                        color: heroColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connectionStatus.isHealthy
                          ? 'SQLite realtime monitoring active'
                          : 'Monitoring stream: ${connectionStatus.label}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _heroStat('Healthy', healthyCount, Colors.greenAccent),
              _vDivider(),
              _heroStat('Degraded', degradedCount, Colors.orangeAccent),
              _vDivider(),
              _heroStat('Down', downCount, Colors.redAccent),
              _vDivider(),
              _heroStat('Unknown', unknownCount, Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22)),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
      ],
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: Colors.white10);
}

// ─────────────────────────────────────────────────────────────────────────────
// Platform Metrics Row
// ─────────────────────────────────────────────────────────────────────────────

class _PlatformMetricsRow extends StatelessWidget {
  final dynamic analytics;
  final bool isDark;

  const _PlatformMetricsRow({required this.analytics, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _metricTile('Orders Today', analytics?.totalOrdersToday?.toString() ?? '—', Icons.receipt_long, Colors.blue, isDark)),
        const SizedBox(width: 8),
        Expanded(child: _metricTile('Online Riders', analytics?.onlineRiders?.toString() ?? '—', Icons.two_wheeler, Colors.orange, isDark)),
        const SizedBox(width: 8),
        Expanded(child: _metricTile('On Delivery', analytics?.ridersOnDelivery?.toString() ?? '—', Icons.local_shipping, Colors.teal, isDark)),
        const SizedBox(width: 8),
        Expanded(child: _metricTile('Online Sellers', analytics?.onlineSellers?.toString() ?? '—', Icons.storefront, const Color(0xFF9B59B6), isDark)),
      ],
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color, bool dark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: dark ? Colors.white38 : Colors.black38), textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDark;
  final int? badge;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDark,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white60 : Colors.black45),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        if (badge != null && badge! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$badge', style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service Card
// ─────────────────────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final ServiceHealthEntry service;
  final bool isDark;
  final AnimationController pulseController;

  const _ServiceCard({
    required this.service,
    required this.isDark,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(service.status);
    final statusLabel = _statusLabel(service.status);
    final isHealthy = service.status == ServiceHealthStatus.healthy;
    final isUnknown = service.status == ServiceHealthStatus.unknown;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: color.withValues(alpha: isHealthy ? 0.2 : 0.4), width: 1.2),
        boxShadow: [
          if (!isHealthy)
            BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          // Status dot with pulse
          AnimatedBuilder(
            animation: pulseController,
            builder: (_, __) {
              final dotOpacity = isHealthy
                  ? 0.6 + 0.4 * pulseController.value
                  : isUnknown
                      ? 0.5
                      : 1.0;
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: dotOpacity),
                  boxShadow: isHealthy
                      ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Service info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statusLabel, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    if (service.errorMessage != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          service.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Latency / right column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (service.latencyMs != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${service.latencyMs}ms',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                  ),
                )
              else
                Text(
                  isUnknown ? '— ms' : 'N/A',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              if (service.lastChecked != null) ...[
                const SizedBox(height: 4),
                Text(
                  _timeAgo(service.lastChecked!),
                  style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(ServiceHealthStatus status) {
    switch (status) {
      case ServiceHealthStatus.healthy:
        return Colors.greenAccent;
      case ServiceHealthStatus.degraded:
        return Colors.orangeAccent;
      case ServiceHealthStatus.down:
        return Colors.redAccent;
      case ServiceHealthStatus.unknown:
        return Colors.grey;
    }
  }

  String _statusLabel(ServiceHealthStatus status) {
    switch (status) {
      case ServiceHealthStatus.healthy:
        return 'Healthy';
      case ServiceHealthStatus.degraded:
        return 'Degraded';
      case ServiceHealthStatus.down:
        return 'Down';
      case ServiceHealthStatus.unknown:
        return 'Unknown';
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audit Event Tile
// ─────────────────────────────────────────────────────────────────────────────

class _AuditEventTile extends StatelessWidget {
  final PlatformEvent event;
  final bool isDark;

  const _AuditEventTile({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.type);
    final icon = _eventIcon(event.type);
    final timeLabel = _timeAgo(event.timestamp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatType(event.type), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                if (event.targetId != null)
                  Text('Target: ${event.targetId}',
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                if (event.actorId != null)
                  Text('By: ${event.actorId}',
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeLabel, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(event.type.split('_').first, style: TextStyle(fontSize: 9, color: color)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    if (type.contains('ORDER')) return Icons.receipt_long;
    if (type.contains('SELLER')) return Icons.storefront;
    if (type.contains('RIDER')) return Icons.two_wheeler;
    if (type.contains('PAYMENT')) return Icons.payments;
    if (type.contains('KYC')) return Icons.verified_user;
    if (type.contains('PRODUCT') || type.contains('CATALOG')) return Icons.inventory;
    return Icons.notifications;
  }

  Color _eventColor(String type) {
    if (type.contains('ORDER')) return Colors.blue;
    if (type.contains('SELLER')) return const Color(0xFF9B59B6);
    if (type.contains('RIDER')) return Colors.orange;
    if (type.contains('PAYMENT')) return Colors.green;
    if (type.contains('KYC')) return Colors.indigo;
    return Colors.teal;
  }

  String _formatType(String type) {
    return type.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join(' ');
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty Event State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyEventState extends StatelessWidget {
  final bool isDark;
  const _EmptyEventState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 36, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            'No recent audit events',
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black45),
          ),
          const SizedBox(height: 4),
          Text(
            'Platform actions will appear here as they occur',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Telemetry Sync Info
// ─────────────────────────────────────────────────────────────────────────────

class _TelemetrySyncInfo extends StatelessWidget {
  final AdminState state;
  final bool isDark;

  const _TelemetrySyncInfo({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _row('Stream Status', state.connectionStatus.label, state.connectionStatus.isHealthy ? Colors.greenAccent : Colors.orangeAccent, isDark),
          const SizedBox(height: 8),
          _row('Last Sync', state.lastSyncLabel, Colors.white70, isDark),
          const SizedBox(height: 8),
          _row('Events Captured', '${state.liveEvents.length}', Colors.blueAccent, isDark),
          const SizedBox(height: 8),
          _row('Services Tracked', '${state.serviceHealth.length}', Colors.tealAccent, isDark),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color valueColor, bool dark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: dark ? Colors.white54 : Colors.black45)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}
