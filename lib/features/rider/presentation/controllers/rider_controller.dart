import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/delivery_task_entity.dart';
import '../../data/repositories/rider_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class RiderState {
  final bool isOnline;
  final List<DeliveryTaskEntity> tasks;
  final double todayEarnings;
  final double totalEarnings;
  final double codCashInHand;
  final bool isLoading;
  final String? errorMessage;

  const RiderState({
    this.isOnline = true,
    this.tasks = const [],
    this.todayEarnings = 0.0,
    this.totalEarnings = 0.0,
    this.codCashInHand = 0.0,
    this.isLoading = false,
    this.errorMessage,
  });

  RiderState copyWith({
    bool? isOnline,
    List<DeliveryTaskEntity>? tasks,
    double? todayEarnings,
    double? totalEarnings,
    double? codCashInHand,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RiderState(
      isOnline: isOnline ?? this.isOnline,
      tasks: tasks ?? this.tasks,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      codCashInHand: codCashInHand ?? this.codCashInHand,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class RiderController extends StateNotifier<RiderState> {
  final RiderRepository _repository;
  final String _riderId;

  StreamSubscription? _tasksSub;
  StreamSubscription<Map<String, double>>? _earningsSub;

  RiderController(this._repository, this._riderId)
      : super(const RiderState()) {
    _initStreams();
    _loadEarnings();
  }

  void _initStreams() {
    if (_riderId.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(isLoading: true);
    _tasksSub?.cancel();
    _tasksSub = _repository.streamRiderDashboard(_riderId).listen((list) {
      state = state.copyWith(tasks: list, isLoading: false);
    }, onError: (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    });
  }

  Future<void> loadTasks() async {
    // Re-init streams to refresh
    _initStreams();
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    _earningsSub?.cancel();
    super.dispose();
  }

  /// FIX: previously a no-op, so `todayEarnings` and `codCashInHand` on both
  /// the rider dashboard and the COD reconciliation screen stayed at 0.0
  /// forever. The existing `streamRiderEarnings` Firestore stream is now
  /// wired directly into state (real earnings data from `deliveryTasks`).
  Future<void> _loadEarnings() async {
    if (_riderId.isEmpty) return;
    _earningsSub?.cancel();
    _earningsSub =
        _repository.streamRiderEarnings(_riderId).listen((stats) {
      state = state.copyWith(
        todayEarnings: stats['todayEarnings'] ?? 0.0,
        totalEarnings: stats['totalEarnings'] ?? 0.0,
        codCashInHand: stats['codCashInHand'] ?? 0.0,
      );
    });
  }

  void toggleOnline(bool online) {
    state = state.copyWith(isOnline: online);
  }

  Future<void> acceptTask(String taskId) async {
    if (_riderId.isEmpty) return;
    await _repository.acceptTask(taskId, _riderId);
    await loadTasks();
  }

  Future<void> updateStatus(
      String taskId, DeliveryTaskStatus newStatus) async {
    await _repository.updateTaskStatus(taskId, newStatus);
    await loadTasks();
  }

  /// Verifies OTP with Firestore and marks delivery as complete.
  /// Returns `true` on success, `false` on wrong OTP.
  Future<bool> completeDeliveryWithOtp(
      String taskId, String enteredOtp) async {
    final success =
        await _repository.completeDeliveryWithOtp(taskId, enteredOtp);
    if (success) await loadTasks();
    return success;
  }

  Future<bool> remitCodCash({
    required double amount,
    required String channel,
    required String referenceNumber,
  }) async {
    final success = await _repository.remitCodCash(
      riderId: _riderId,
      amount: amount,
      channel: channel,
      referenceNumber: referenceNumber,
    );
    if (success) {
      final newCash = (state.codCashInHand - amount).clamp(0.0, double.infinity);
      state = state.copyWith(codCashInHand: newCash);
    }
    return success;
  }
}

final riderControllerProvider =
    StateNotifierProvider<RiderController, RiderState>((ref) {
  final repository = ref.watch(riderRepositoryProvider);
  // Use the authenticated user's UID as riderId
  final authState = ref.watch(authControllerProvider);
  final riderId = authState.user?.id ?? '';
  return RiderController(repository, riderId);
});
