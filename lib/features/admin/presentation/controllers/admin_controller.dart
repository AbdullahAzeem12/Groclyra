import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/auth/domain/entities/account_status.dart';
import '../../domain/entities/admin_analytics_entity.dart';
import '../../domain/entities/connection_status.dart';
import '../../data/repositories/admin_repository.dart';
import '../../riders/domain/entities/rider_kyc_application.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AdminState {
  final AdminAnalyticsEntity? analytics;
  final List<SellerKycApplication> kycQueue;
  final List<RiderKycApplication> riderKycQueue;
  final List<ServiceHealthEntry> serviceHealth;
  final List<PlatformEvent> liveEvents;
  final bool isLoading;
  final ConnectionStatus connectionStatus;
  final String? errorMessage;
  final String? successMessage;
  final DateTime? lastSyncTime;

  /// True if streams are initializing (no first event yet)
  final bool isInitializing;

  const AdminState({
    this.analytics,
    this.kycQueue = const [],
    this.riderKycQueue = const [],
    this.serviceHealth = const [],
    this.liveEvents = const [],
    this.isLoading = false,
    this.connectionStatus = ConnectionStatus.connecting,
    this.errorMessage,
    this.successMessage,
    this.lastSyncTime,
    this.isInitializing = true,
  });

  /// Backward-compatibility: old code used isLiveOnline
  bool get isLiveOnline => connectionStatus.isHealthy;

  AdminState copyWith({
    AdminAnalyticsEntity? analytics,
    List<SellerKycApplication>? kycQueue,
    List<RiderKycApplication>? riderKycQueue,
    List<ServiceHealthEntry>? serviceHealth,
    List<PlatformEvent>? liveEvents,
    bool? isLoading,
    ConnectionStatus? connectionStatus,
    String? errorMessage,
    String? successMessage,
    DateTime? lastSyncTime,
    bool? isInitializing,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AdminState(
      analytics: analytics ?? this.analytics,
      kycQueue: kycQueue ?? this.kycQueue,
      riderKycQueue: riderKycQueue ?? this.riderKycQueue,
      serviceHealth: serviceHealth ?? this.serviceHealth,
      liveEvents: liveEvents ?? this.liveEvents,
      isLoading: isLoading ?? this.isLoading,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }

  /// Human-readable last sync description
  String get lastSyncLabel {
    if (lastSyncTime == null) return 'Never synced';
    final diff = DateTime.now().difference(lastSyncTime!);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Controller ────────────────────────────────────────────────────────────────

class AdminController extends StateNotifier<AdminState> {
  final AdminRepository _repository;
  StreamSubscription<AdminAnalyticsEntity>? _analyticsSub;
  StreamSubscription<List<RiderKycApplication>>? _riderKycSub;
  StreamSubscription<List<SellerKycApplication>>? _sellerKycSub;
  StreamSubscription<List<ServiceHealthEntry>>? _serviceHealthSub;
  StreamSubscription<List<PlatformEvent>>? _eventsSub;

  // Idempotency: track in-flight action IDs
  final Set<String> _pendingActions = {};

  AdminController(this._repository) : super(const AdminState(isInitializing: true)) {
    _initRealtimeSubscriptions();
  }

  void _initRealtimeSubscriptions() {
    state = state.copyWith(connectionStatus: ConnectionStatus.connecting, isInitializing: true);

    // 1. Live Analytics
    _analyticsSub = _repository.watchAnalytics().listen(
      (analytics) {
        final isStale = analytics.lastUpdated != null &&
            DateTime.now().toUtc().difference(analytics.lastUpdated!).inSeconds > 120;
        state = state.copyWith(
          analytics: analytics.copyWith(isStale: isStale),
          connectionStatus: ConnectionStatus.live,
          isLoading: false,
          isInitializing: false,
          lastSyncTime: DateTime.now(),
          clearError: true,
        );
      },
      onError: (err) {
        state = state.copyWith(
          connectionStatus: ConnectionStatus.offline,
          isLoading: false,
          isInitializing: false,
          errorMessage: 'Unable to stream live metrics',
        );
      },
    );

    // 2. Rider KYC
    _riderKycSub = _repository.watchRiderKycApplications().listen(
      (riders) => state = state.copyWith(riderKycQueue: riders),
      onError: (err) => state = state.copyWith(errorMessage: 'Rider queue sync issue'),
    );

    // 3. Seller KYC
    _sellerKycSub = _repository.watchSellerKycApplications().listen(
      (sellers) => state = state.copyWith(kycQueue: sellers),
      onError: (err) => state = state.copyWith(errorMessage: 'Seller queue sync issue'),
    );

    // 4. Service Health
    _serviceHealthSub = _repository.watchServiceHealth().listen(
      (health) => state = state.copyWith(serviceHealth: health),
      onError: (_) {},
    );

    // 5. Live Events
    _eventsSub = _repository.watchLiveEvents().listen(
      (events) => state = state.copyWith(liveEvents: events),
      onError: (_) {},
    );
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, connectionStatus: ConnectionStatus.syncing, clearError: true);
    try {
      final analytics = await _repository.getAnalytics();
      final kyc = await _repository.getKycApplications();
      final riderKyc = await _repository.getRiderKycApplications();
      state = state.copyWith(
        analytics: analytics,
        kycQueue: kyc,
        riderKycQueue: riderKyc,
        isLoading: false,
        connectionStatus: ConnectionStatus.live,
        lastSyncTime: DateTime.now(),
        isInitializing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        connectionStatus: ConnectionStatus.error,
        errorMessage: 'Dashboard sync failed',
      );
    }
  }

  Future<void> reviewRiderKyc({
    required String riderId,
    required AccountStatus newStatus,
    required String adminId,
    String? notes,
  }) async {
    // Idempotency guard
    final actionKey = 'rider_kyc_$riderId';
    if (_pendingActions.contains(actionKey)) return;
    _pendingActions.add(actionKey);

    try {
      await _repository.reviewRiderKyc(riderId: riderId, newStatus: newStatus, adminId: adminId, notes: notes);
      // Optimistic local update — Firestore stream will confirm
      final updatedQueue = state.riderKycQueue.map((app) {
        if (app.id == riderId || app.riderId == riderId) {
          return app.copyWith(status: newStatus, adminNotes: notes, reviewedBy: adminId, updatedAt: DateTime.now());
        }
        return app;
      }).toList();
      state = state.copyWith(
        riderKycQueue: updatedQueue,
        clearError: true,
        successMessage: 'Rider status updated to ${newStatus.label}',
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update rider: $e');
      rethrow;
    } finally {
      _pendingActions.remove(actionKey);
    }
  }

  Future<void> reviewSellerKyc({
    required String sellerId,
    required AccountStatus newStatus,
    required String adminId,
    String? notes,
  }) async {
    final actionKey = 'seller_kyc_$sellerId';
    if (_pendingActions.contains(actionKey)) return;
    _pendingActions.add(actionKey);

    try {
      await _repository.reviewSellerKyc(sellerId: sellerId, newStatus: newStatus, adminId: adminId, notes: notes);
      state = state.copyWith(
        clearError: true,
        successMessage: 'Seller status updated to ${newStatus.label}',
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update seller: $e');
      rethrow;
    } finally {
      _pendingActions.remove(actionKey);
    }
  }

  /// Backward-compat
  Future<void> moderateKyc(String id, bool approve) => reviewSellerKyc(
    sellerId: id,
    newStatus: approve ? AccountStatus.active : AccountStatus.disabled,
    adminId: 'admin_sys',
  );

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  @override
  void dispose() {
    _analyticsSub?.cancel();
    _riderKycSub?.cancel();
    _sellerKycSub?.cancel();
    _serviceHealthSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }
}

final adminControllerProvider = StateNotifierProvider<AdminController, AdminState>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  return AdminController(repository);
});
