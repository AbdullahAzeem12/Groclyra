/// Extended analytics entity — all fields nullable to distinguish
/// "backend confirmed 0" from "backend unavailable".
/// The UI must NEVER treat null as zero silently.
class AdminAnalyticsEntity {
  // ── Financial metrics ──────────────────────────────────────────────────────
  /// Total Gross Merchandise Value (non-cancelled orders only)
  final double? totalGmv;

  /// Platform commission (backend-calculated; 8 % default)
  final double? totalCommission;

  /// Refund total (deducted from GMV when calculating net revenue)
  final double? totalRefunds;

  /// Net platform revenue = GMV − refunds − seller/rider payouts
  final double? netPlatformRevenue;

  /// Average order value = GMV / completed order count
  final double? averageOrderValue;

  // ── Order metrics ──────────────────────────────────────────────────────────
  final int? totalOrdersToday;
  final int? ordersCompleted;
  final int? ordersActive;
  final int? ordersCancelled;
  final int? ordersRefunded;

  // ── Stakeholder counts ─────────────────────────────────────────────────────
  final int? totalActiveCustomers;
  final int? totalActiveSellers;
  final int? totalActiveRiders;

  /// Sellers currently online/accepting orders
  final int? onlineSellers;

  /// Riders currently online
  final int? onlineRiders;

  /// Riders currently on a delivery
  final int? ridersOnDelivery;

  // ── Governance ─────────────────────────────────────────────────────────────
  final int? pendingSellerApprovals;
  final int? pendingRiderApprovals;
  final int? pendingProductApprovals;
  final int? suspendedSellers;
  final int? suspendedRiders;

  // ── System health ──────────────────────────────────────────────────────────
  final double? systemHealthScore;

  // ── Data freshness ─────────────────────────────────────────────────────────
  /// UTC timestamp when this snapshot was computed from Firestore
  final DateTime? lastUpdated;

  /// True if this entity was produced by a live Firestore snapshot
  final bool isLiveOnline;

  /// True if data is stale (> configured threshold since lastUpdated)
  final bool isStale;

  const AdminAnalyticsEntity({
    this.totalGmv,
    this.totalCommission,
    this.totalRefunds,
    this.netPlatformRevenue,
    this.averageOrderValue,
    this.totalOrdersToday,
    this.ordersCompleted,
    this.ordersActive,
    this.ordersCancelled,
    this.ordersRefunded,
    this.totalActiveCustomers,
    this.totalActiveSellers,
    this.totalActiveRiders,
    this.onlineSellers,
    this.onlineRiders,
    this.ridersOnDelivery,
    this.pendingSellerApprovals,
    this.pendingRiderApprovals,
    this.pendingProductApprovals,
    this.suspendedSellers,
    this.suspendedRiders,
    this.systemHealthScore,
    this.lastUpdated,
    this.isLiveOnline = true,
    this.isStale = false,
  });

  /// Used when backend is entirely unavailable — all metrics are null (unknown)
  factory AdminAnalyticsEntity.unavailable() {
    return const AdminAnalyticsEntity(
      isLiveOnline: false,
      lastUpdated: null,
    );
  }

  /// True "backend confirmed" zero state — every metric explicitly 0 (not
  /// null) and the connection considered live. Used by tests and empty
  /// dashboards.
  factory AdminAnalyticsEntity.empty() {
    return const AdminAnalyticsEntity(
      totalGmv: 0.0,
      totalCommission: 0.0,
      totalRefunds: 0.0,
      netPlatformRevenue: 0.0,
      averageOrderValue: 0.0,
      totalOrdersToday: 0,
      ordersCompleted: 0,
      ordersActive: 0,
      ordersCancelled: 0,
      ordersRefunded: 0,
      totalActiveCustomers: 0,
      totalActiveSellers: 0,
      totalActiveRiders: 0,
      onlineSellers: 0,
      onlineRiders: 0,
      ridersOnDelivery: 0,
      pendingSellerApprovals: 0,
      pendingRiderApprovals: 0,
      pendingProductApprovals: 0,
      suspendedSellers: 0,
      suspendedRiders: 0,
      systemHealthScore: 100.0,
      isLiveOnline: true,
    );
  }

  /// Convenience — create updated copy with changed fields
  AdminAnalyticsEntity copyWith({
    double? totalGmv,
    double? totalCommission,
    double? totalRefunds,
    double? netPlatformRevenue,
    double? averageOrderValue,
    int? totalOrdersToday,
    int? ordersCompleted,
    int? ordersActive,
    int? ordersCancelled,
    int? ordersRefunded,
    int? totalActiveCustomers,
    int? totalActiveSellers,
    int? totalActiveRiders,
    int? onlineSellers,
    int? onlineRiders,
    int? ridersOnDelivery,
    int? pendingSellerApprovals,
    int? pendingRiderApprovals,
    int? pendingProductApprovals,
    int? suspendedSellers,
    int? suspendedRiders,
    double? systemHealthScore,
    DateTime? lastUpdated,
    bool? isLiveOnline,
    bool? isStale,
  }) {
    return AdminAnalyticsEntity(
      totalGmv: totalGmv ?? this.totalGmv,
      totalCommission: totalCommission ?? this.totalCommission,
      totalRefunds: totalRefunds ?? this.totalRefunds,
      netPlatformRevenue: netPlatformRevenue ?? this.netPlatformRevenue,
      averageOrderValue: averageOrderValue ?? this.averageOrderValue,
      totalOrdersToday: totalOrdersToday ?? this.totalOrdersToday,
      ordersCompleted: ordersCompleted ?? this.ordersCompleted,
      ordersActive: ordersActive ?? this.ordersActive,
      ordersCancelled: ordersCancelled ?? this.ordersCancelled,
      ordersRefunded: ordersRefunded ?? this.ordersRefunded,
      totalActiveCustomers: totalActiveCustomers ?? this.totalActiveCustomers,
      totalActiveSellers: totalActiveSellers ?? this.totalActiveSellers,
      totalActiveRiders: totalActiveRiders ?? this.totalActiveRiders,
      onlineSellers: onlineSellers ?? this.onlineSellers,
      onlineRiders: onlineRiders ?? this.onlineRiders,
      ridersOnDelivery: ridersOnDelivery ?? this.ridersOnDelivery,
      pendingSellerApprovals: pendingSellerApprovals ?? this.pendingSellerApprovals,
      pendingRiderApprovals: pendingRiderApprovals ?? this.pendingRiderApprovals,
      pendingProductApprovals: pendingProductApprovals ?? this.pendingProductApprovals,
      suspendedSellers: suspendedSellers ?? this.suspendedSellers,
      suspendedRiders: suspendedRiders ?? this.suspendedRiders,
      systemHealthScore: systemHealthScore ?? this.systemHealthScore,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isLiveOnline: isLiveOnline ?? this.isLiveOnline,
      isStale: isStale ?? this.isStale,
    );
  }

  /// Seconds since last update; null if never updated
  int? get secondsSinceUpdate {
    if (lastUpdated == null) return null;
    return DateTime.now().toUtc().difference(lastUpdated!).inSeconds.abs();
  }
}
