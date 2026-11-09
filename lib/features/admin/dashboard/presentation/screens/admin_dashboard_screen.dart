import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/gradient_card.dart';
import 'package:groclyra/features/admin/presentation/controllers/admin_controller.dart';
import 'package:groclyra/features/admin/domain/entities/admin_analytics_entity.dart';
import 'package:groclyra/features/admin/domain/entities/connection_status.dart';
import 'package:groclyra/features/admin/data/repositories/admin_repository.dart';
import 'package:groclyra/features/catalog/presentation/controllers/catalog_controller.dart';
import 'package:groclyra/core/sync/sqlite_network_sync_service.dart';
import '../widgets/sql_database_diagnostics_sheet.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _staleTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Periodically check data freshness every 30s
    _staleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _staleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminControllerProvider);
    final catalogState = ref.watch(catalogControllerProvider);
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = adminState.analytics;

    final pendingSellers = adminState.kycQueue
        .where((k) => !k.isApproved)
        .length;
    final pendingRiders = adminState.riderKycQueue
        .where((r) => r.isPending)
        .length;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B101D)
          : const Color(0xFFF1F5F9),
      appBar: GradientAppBar(
        title: 'Groclyra Admin Console',
        subtitle: 'Platform Governance & Operational Health',
        // Phase 1B: real-time notification centre
        showNotificationBell: true,
        actions: [
          // Connection status badge
          GestureDetector(
            onTap: () => _showConnectionDialog(context, adminState),
            child: _ConnectionBadge(
              status: adminState.connectionStatus,
              pulseController: _pulseController,
              lastSyncLabel: adminState.lastSyncLabel,
            ),
          ),
          IconButton(
            tooltip: 'Switch Portal',
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            onPressed: () => context.go(RouteNames.login),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: themeState.palette.primaryColor,
        onRefresh: () {
          HapticFeedback.mediumImpact();
          return ref.read(adminControllerProvider.notifier).loadDashboard();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Error banner
            if (adminState.errorMessage != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(message: adminState.errorMessage!),
              ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── GMV CARD ───────────────────────────────────────────────
                  _GmvCard(
                        analytics: analytics,
                        connectionStatus: adminState.connectionStatus,
                        isInitializing: adminState.isInitializing,
                        pulseController: _pulseController,
                        lastSyncLabel: adminState.lastSyncLabel,
                        isDark: isDark,
                        themeColor: themeState.palette.primaryColor,
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.08, end: 0),

                  const SizedBox(height: 14),

                  // ── ORDER BREAKDOWN ────────────────────────────────────────
                  _OrderBreakdownRow(
                    analytics: analytics,
                    isDark: isDark,
                  ).animate().fadeIn(duration: 400.ms, delay: 80.ms),

                  const SizedBox(height: 14),

                  // ── STAKEHOLDER TILES ──────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StakeholderTile(
                          label: 'Customers',
                          total: analytics?.totalActiveCustomers,
                          subtitle: null,
                          icon: Icons.people_outline,
                          color: Colors.blue,
                          isDark: isDark,
                          onTap: null, // future: customer management
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StakeholderTile(
                          label: 'Sellers',
                          total: analytics?.totalActiveSellers,
                          subtitle: analytics?.onlineSellers != null
                              ? '${analytics!.onlineSellers} online'
                              : null,
                          icon: Icons.storefront_outlined,
                          color: const Color(0xFF9B59B6),
                          isDark: isDark,
                          onTap: () => context.go(RouteNames.adminKyc),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StakeholderTile(
                          label: 'Riders',
                          total: analytics?.totalActiveRiders,
                          subtitle: analytics?.onlineRiders != null
                              ? '${analytics!.onlineRiders} online'
                              : null,
                          icon: Icons.two_wheeler_outlined,
                          color: Colors.orange,
                          isDark: isDark,
                          onTap: () => context.go(RouteNames.adminRiderKyc),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

                  const SizedBox(height: 22),

                  // ── GOVERNANCE SECTION HEADER ──────────────────────────────
                  // Overflow fix: title now wraps instead of overflowing on
                  // narrow (360 dp) screens.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pending Approvals & Governance',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                        ),
                      ),
                      if (pendingSellers + pendingRiders > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pendingSellers + pendingRiders} pending',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                  const SizedBox(height: 12),

                  // ── SELLER KYC CARD ────────────────────────────────────────
                  _GovernanceCard(
                    icon: Icons.verified_user_rounded,
                    iconColor: const Color(0xFF9B59B6),
                    title: 'Seller KYC Applications',
                    subtitle: adminState.isInitializing
                        ? 'Loading...'
                        : '$pendingSellers merchant document${pendingSellers == 1 ? '' : 's'} pending verification',
                    badgeCount: pendingSellers,
                    onTap: () => context.go(RouteNames.adminKyc),
                    isDark: isDark,
                  ).animate().fadeIn(duration: 400.ms, delay: 260.ms),

                  const SizedBox(height: 10),

                  // ── RIDER KYC CARD ─────────────────────────────────────────
                  _GovernanceCard(
                    icon: Icons.two_wheeler_rounded,
                    iconColor: Colors.orange,
                    title: 'Rider KYC Applications',
                    subtitle: adminState.isInitializing
                        ? 'Loading...'
                        : '$pendingRiders rider application${pendingRiders == 1 ? '' : 's'} pending verification',
                    badgeCount: pendingRiders,
                    onTap: () => context.go(RouteNames.adminRiderKyc),
                    isDark: isDark,
                  ).animate().fadeIn(duration: 400.ms, delay: 310.ms),

                  const SizedBox(height: 10),

                  // ── CATALOG MODERATION CARD ────────────────────────────────
                  _GovernanceCard(
                    icon: Icons.checklist_rtl_rounded,
                    iconColor: Colors.indigo,
                    title: 'Catalog Product Moderation',
                    subtitle:
                        '${catalogState.allProducts.length} listings in the catalog',
                    badgeCount: 0,
                    onTap: () => context.go(RouteNames.adminCatalog),
                    isDark: isDark,
                  ).animate().fadeIn(duration: 400.ms, delay: 360.ms),

                  const SizedBox(height: 10),

                  // ── SYSTEM HEALTH CARD ─────────────────────────────────────
                  _GovernanceCard(
                    icon: Icons.monitor_heart_rounded,
                    iconColor: Colors.teal,
                    title: 'System Health & Telemetry',
                    subtitle: _healthSubtitle(adminState),
                    badgeCount: 0,
                    onTap: () => context.go(RouteNames.adminTelemetry),
                    isDark: isDark,
                    trailingWidget: _healthIndicatorDot(
                      adminState.connectionStatus,
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 410.ms),

                  const SizedBox(height: 20),

                  // ── LIVE EVENTS PREVIEW ───────────────────────────────────
                  if (adminState.liveEvents.isNotEmpty)
                    _LiveEventsPreview(
                      events: adminState.liveEvents,
                      isDark: isDark,
                    ).animate().fadeIn(duration: 400.ms, delay: 460.ms),

                  const SizedBox(height: 20),

                  // ── LAST SYNC FOOTER ──────────────────────────────────────
                  _SyncFooter(
                    status: adminState.connectionStatus,
                    lastSyncLabel: adminState.lastSyncLabel,
                  ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _healthSubtitle(AdminState state) {
    final healthy = state.serviceHealth
        .where((s) => s.status == ServiceHealthStatus.healthy)
        .length;
    final total = state.serviceHealth.length;
    if (total == 0) return 'Backend services monitoring';
    if (healthy == total) return '$total services — all operational';
    final degraded = total - healthy;
    return '$degraded service${degraded == 1 ? '' : 's'} need attention';
  }

  Widget _healthIndicatorDot(ConnectionStatus status) {
    final color = status == ConnectionStatus.live
        ? Colors.greenAccent
        : Colors.orangeAccent;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final opacity = 0.5 + 0.5 * _pulseController.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConnectionDialog(BuildContext context, AdminState state) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => _ConnectionHealthDialog(state: state),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection Badge
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionBadge extends StatelessWidget {
  final ConnectionStatus status;
  final AnimationController pulseController;
  final String lastSyncLabel;

  const _ConnectionBadge({
    required this.status,
    required this.pulseController,
    required this.lastSyncLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Color bgColor;

    switch (status) {
      case ConnectionStatus.live:
        dotColor = Colors.greenAccent;
        bgColor = Colors.green;
        break;
      case ConnectionStatus.syncing:
        dotColor = Colors.blueAccent;
        bgColor = Colors.blue;
        break;
      case ConnectionStatus.stale:
        dotColor = Colors.amberAccent;
        bgColor = Colors.amber;
        break;
      case ConnectionStatus.degraded:
        dotColor = Colors.orangeAccent;
        bgColor = Colors.orange;
        break;
      case ConnectionStatus.offline:
      case ConnectionStatus.error:
        dotColor = Colors.redAccent;
        bgColor = Colors.red;
        break;
      default:
        dotColor = Colors.grey;
        bgColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgColor.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseController,
            builder: (_, __) => Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor.withValues(
                  alpha: 0.6 + 0.4 * pulseController.value,
                ),
                boxShadow: status == ConnectionStatus.live
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: dotColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GMV Card
// ─────────────────────────────────────────────────────────────────────────────

class _GmvCard extends StatelessWidget {
  final AdminAnalyticsEntity? analytics;
  final ConnectionStatus connectionStatus;
  final bool isInitializing;
  final AnimationController pulseController;
  final String lastSyncLabel;
  final bool isDark;
  final Color themeColor;

  const _GmvCard({
    required this.analytics,
    required this.connectionStatus,
    required this.isInitializing,
    required this.pulseController,
    required this.lastSyncLabel,
    required this.isDark,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final gmv = analytics?.totalGmv;
    final commission = analytics?.totalCommission;
    final refunds = analytics?.totalRefunds;
    final netRevenue = analytics?.netPlatformRevenue;
    final avgOrderValue = analytics?.averageOrderValue;
    final ordersToday = analytics?.totalOrdersToday;

    return GestureDetector(
      onTap: () => _showRevenueBreakdown(
        context,
        gmv,
        commission,
        refunds,
        netRevenue,
        ordersToday,
      ),
      child: Container(
        width: double.infinity,
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
          border: Border.all(
            color: themeColor.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            // Overflow fix: labels are flexible + ellipsised on narrow screens.
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total Platform GMV',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Updated: $lastSyncLabel',
                  style: TextStyle(
                    color: analytics?.isStale == true
                        ? Colors.amberAccent
                        : Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // GMV Value
            if (isInitializing)
              _shimmerText(width: 180, height: 36)
            else
              _AnimatedCurrencyValue(
                value: gmv,
                unavailableText: '— Awaiting data',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),

            const SizedBox(height: 16),

            // Metrics grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _gmvMetricChip('Commission', commission, Colors.amberAccent),
                _gmvMetricChip(
                  'Refunds',
                  refunds,
                  Colors.redAccent,
                  prefix: '-',
                ),
                _gmvMetricChip('Net Revenue', netRevenue, Colors.greenAccent),
                if (avgOrderValue != null)
                  _gmvMetricChip('Avg Order', avgOrderValue, Colors.blueAccent),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 10),

            // Orders today row
            // Overflow fix: label flexible, status chip stays right-aligned.
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isInitializing
                      ? _shimmerText(width: 120, height: 14)
                      : Text(
                          ordersToday == null
                              ? 'Orders today: — awaiting data'
                              : '$ordersToday order${ordersToday == 1 ? '' : 's'} today',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ordersToday == null
                                ? Colors.white54
                                : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                ),
                const Spacer(),
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: connectionStatus.isHealthy
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    connectionStatus.isHealthy
                        ? 'Live'
                        : connectionStatus.label,
                    style: TextStyle(
                      color: connectionStatus.isHealthy
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRevenueBreakdown(
    BuildContext context,
    double? gmv,
    double? commission,
    double? refunds,
    double? netRevenue,
    int? ordersToday,
  ) {
    if (gmv == null || commission == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 48,
                          color: themeColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Revenue Mathematical Breakdown',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Based on real-time connected data sync.',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildBreakdownRow(
                          'Total GMV',
                          gmv,
                          isDark,
                          isPositive: true,
                        ),
                        _buildBreakdownRow(
                          'Refunds',
                          refunds ?? 0,
                          isDark,
                          isPositive: false,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(),
                        ),
                        _buildBreakdownRow(
                          'Net GMV',
                          gmv - (refunds ?? 0),
                          isDark,
                          isPositive: true,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Platform Commission',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '10.0%',
                              style: TextStyle(
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(),
                        ),
                        _buildBreakdownRow(
                          'Net Platform Revenue',
                          netRevenue ?? 0,
                          isDark,
                          isPositive: true,
                          isTotal: true,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'Close Details',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBreakdownRow(
    String label,
    double value,
    bool isDark, {
    bool isPositive = true,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            '${isPositive ? '' : '- '}PKR ${value.toStringAsFixed(0)}',
            style: TextStyle(
              color: isTotal
                  ? Colors.greenAccent
                  : (isPositive
                        ? (isDark ? Colors.white : Colors.black87)
                        : Colors.redAccent),
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gmvMetricChip(
    String label,
    double? value,
    Color color, {
    String prefix = '',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          if (value == null)
            Text(
              '—',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              '$prefix${CurrencyFormatter.format(value)}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _shimmerText({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order Breakdown Row
// ─────────────────────────────────────────────────────────────────────────────

class _OrderBreakdownRow extends StatelessWidget {
  final AdminAnalyticsEntity? analytics;
  final bool isDark;

  const _OrderBreakdownRow({required this.analytics, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showOrdersBreakdown(context, analytics),
      child: Row(
        children: [
          Expanded(
            child: _orderChip(
              'Completed',
              analytics?.ordersCompleted,
              Colors.green,
              isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _orderChip(
              'Active',
              analytics?.ordersActive,
              Colors.blue,
              isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _orderChip(
              'Cancelled',
              analytics?.ordersCancelled,
              Colors.red,
              isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _orderChip(
              'Refunded',
              analytics?.ordersRefunded,
              Colors.amber,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrdersBreakdown(
    BuildContext context,
    AdminAnalyticsEntity? analytics,
  ) {
    if (analytics == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 48,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Order Lifecycle & Sync',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Based on real-time connected data sync.',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildBreakdownRow(
                          'Total Orders Today',
                          analytics.totalOrdersToday ?? 0,
                          isDark,
                          isTotal: true,
                          color: Colors.blueAccent,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(),
                        ),
                        _buildBreakdownRow(
                          'Completed',
                          analytics.ordersCompleted ?? 0,
                          isDark,
                          color: Colors.green,
                        ),
                        _buildBreakdownRow(
                          'Active (In-progress)',
                          analytics.ordersActive ?? 0,
                          isDark,
                          color: Colors.blue,
                        ),
                        _buildBreakdownRow(
                          'Cancelled',
                          analytics.ordersCancelled ?? 0,
                          isDark,
                          color: Colors.red,
                        ),
                        _buildBreakdownRow(
                          'Refunded',
                          analytics.ordersRefunded ?? 0,
                          isDark,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'Close Details',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBreakdownRow(
    String label,
    int value,
    bool isDark, {
    bool isTotal = false,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderChip(String label, int? value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            value != null ? '$value' : '—',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stakeholder Tile
// ─────────────────────────────────────────────────────────────────────────────

class _StakeholderTile extends StatelessWidget {
  final String label;
  final int? total;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const _StakeholderTile({
    required this.label,
    required this.total,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          total == null
              ? Text(
                  '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: color,
                  ),
                )
              : Text(
                  '$total',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: color,
                  ),
                ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9,
                color: color.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return SpringTouchScale(
        onTap: onTap,
        scaleFactor: 0.95,
        pressDepth: 3.0,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: card,
      );
    }
    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Governance Card
// ─────────────────────────────────────────────────────────────────────────────

class _GovernanceCard extends ConsumerWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int badgeCount;
  final VoidCallback onTap;
  final bool isDark;
  final Widget? trailingWidget;

  const _GovernanceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeCount,
    required this.onTap,
    required this.isDark,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GradientCard(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailingWidget ??
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey,
              ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Events Preview
// ─────────────────────────────────────────────────────────────────────────────

class _LiveEventsPreview extends StatelessWidget {
  final List<PlatformEvent> events;
  final bool isDark;

  const _LiveEventsPreview({required this.events, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final shown = events.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'Live Event Feed',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${events.length} events',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...shown.asMap().entries.map((e) {
          final event = e.value;
          final icon = _eventIcon(event.type);
          final color = _eventColor(event.type);
          final diff = DateTime.now().difference(event.timestamp);
          final timeLabel = diff.inSeconds < 60
              ? '${diff.inSeconds}s ago'
              : '${diff.inMinutes}m ago';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child:
                Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121722) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 14, color: color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatEventType(event.type),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (event.targetId != null)
                                  Text(
                                    'ID: ${event.targetId}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: (e.key * 60).ms)
                    .slideX(begin: 0.05, end: 0),
          );
        }),
      ],
    );
  }

  IconData _eventIcon(String type) {
    if (type.contains('ORDER')) return Icons.receipt_long;
    if (type.contains('SELLER')) return Icons.storefront;
    if (type.contains('RIDER')) return Icons.two_wheeler;
    if (type.contains('PAYMENT')) return Icons.payments;
    if (type.contains('PRODUCT') || type.contains('CATALOG')) {
      return Icons.inventory;
    }
    if (type.contains('KYC')) return Icons.verified_user;
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

  String _formatEventType(String type) {
    return type
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync Footer
// ─────────────────────────────────────────────────────────────────────────────

class _SyncFooter extends StatelessWidget {
  final ConnectionStatus status;
  final String lastSyncLabel;

  const _SyncFooter({required this.status, required this.lastSyncLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          status.isHealthy
              ? Icons.cloud_done_outlined
              : Icons.cloud_off_outlined,
          size: 13,
          color: Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          status.isHealthy
              ? 'Last synced: $lastSyncLabel'
              : 'Data unavailable — ${status.label}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Currency Value Widget
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedCurrencyValue extends StatelessWidget {
  final double? value;
  final String unavailableText;
  final TextStyle style;

  const _AnimatedCurrencyValue({
    required this.value,
    required this.unavailableText,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Text(
        unavailableText,
        style: style.copyWith(color: Colors.white38, fontSize: 18),
      );
    }
    return Text(CurrencyFormatter.format(value!), style: style)
        .animate(key: ValueKey(value!.toInt()))
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.15, end: 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection Health Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionHealthDialog extends ConsumerWidget {
  final AdminState state;

  const _ConnectionHealthDialog({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    switch (state.connectionStatus) {
      case ConnectionStatus.live:
        statusColor = Colors.greenAccent;
        break;
      case ConnectionStatus.syncing:
        statusColor = Colors.blueAccent;
        break;
      case ConnectionStatus.offline:
      case ConnectionStatus.error:
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = Colors.orangeAccent;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.cloud_sync_outlined,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Health',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Groclyra Platform',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 14),
            _infoRow('Database Engine', 'SQLite (groclyra.db)', Colors.greenAccent),
            _infoRow('Storage Architecture', 'Pure Local Relational SQL', Colors.white70),
            _infoRow('Status', state.connectionStatus.label, statusColor),
            _infoRow('Realtime Bus', 'Active (Mutation Stream)', Colors.greenAccent),
            _infoRow('Last Sync', state.lastSyncLabel, Colors.white70),
            _infoRow(
              'Live Events',
              '${state.liveEvents.length} received',
              Colors.white70,
            ),
            _infoRow(
              'KYC Queue',
              'Seller: ${state.kycQueue.length}  Rider: ${state.riderKycQueue.length}',
              Colors.white70,
            ),
            const SizedBox(height: 6),
            const Divider(color: Colors.white12),
            const SizedBox(height: 6),
            Builder(
              builder: (ctx) {
                final syncState = ref.watch(sqliteNetworkSyncProvider);
                return Column(
                  children: [
                    _infoRow('Multi-Device Sync', syncState.mode.name, Colors.cyanAccent),
                    _infoRow('Connected Peers', '${syncState.connectedPeersCount} active', Colors.white70),
                    _infoRow('Sync Status', syncState.statusMessage ?? 'Active', Colors.white70),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (syncState.mode == SyncMode.standalone) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => ref.read(sqliteNetworkSyncProvider.notifier).startHubServer(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.cyanAccent),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Start Sync Hub', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showConnectHostDialog(context, ref),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.tealAccent),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Connect to IP', style: TextStyle(color: Colors.tealAccent, fontSize: 11)),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => ref.read(sqliteNetworkSyncProvider.notifier).stopSync(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orangeAccent),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Stop Sync Hub (Standalone)', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.storage_rounded, size: 16, color: Color(0xFF3B82F6)),
                label: const Text(
                  'SQL Engine Diagnostics & Backup',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3B82F6), width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  SqlDatabaseDiagnosticsSheet.show(context);
                },
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      ref
                          .read(adminControllerProvider.notifier)
                          .loadDashboard();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync, size: 16),
                        SizedBox(width: 6),
                        Text('Sync Now'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.92, 0.92)),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white54),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectHostDialog(BuildContext context, WidgetRef ref) {
    final ipController = TextEditingController(text: '192.168.1.100');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect to Sync Hub'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the local Wi-Fi or LAN IP address of the device hosting the Groclyra Sync Hub:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'Hub IP Address',
                hintText: '192.168.1.100',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                ref.read(sqliteNetworkSyncProvider.notifier).connectAsClient(ip);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
