import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/customer/orders/data/repositories/order_repository.dart';

import '../../data/repositories/support_repository.dart';
import '../../domain/entities/support_entities.dart';
import '../../domain/services/ai_support_agent_engine.dart';

class SupportState {
  final List<SupportMessageEntity> messages;
  final bool isAiThinking;
  final bool isHumanAssigned;
  final String? activeTicketId;
  final String? errorMessage;

  const SupportState({
    this.messages = const [],
    this.isAiThinking = false,
    this.isHumanAssigned = false,
    this.activeTicketId,
    this.errorMessage,
  });

  SupportState copyWith({
    List<SupportMessageEntity>? messages,
    bool? isAiThinking,
    bool? isHumanAssigned,
    String? activeTicketId,
    String? errorMessage,
  }) {
    return SupportState(
      messages: messages ?? this.messages,
      isAiThinking: isAiThinking ?? this.isAiThinking,
      isHumanAssigned: isHumanAssigned ?? this.isHumanAssigned,
      activeTicketId: activeTicketId ?? this.activeTicketId,
      errorMessage: errorMessage,
    );
  }
}

class SupportController extends StateNotifier<SupportState> {
  final SupportRepository _repository;
  final AiSupportAgentEngine _aiEngine;
  final String _customerId;
  final String _customerName;
  final String _customerPhone;
  final String _threadId;
  StreamSubscription<List<SupportMessageEntity>>? _sub;

  SupportController(
    this._repository,
    this._aiEngine, {
    required String customerId,
    required String customerName,
    required String customerPhone,
  })  : _customerId = customerId.isNotEmpty ? customerId : 'usr_guest',
        _customerName = customerName.isNotEmpty ? customerName : 'Valued Customer',
        _customerPhone = customerPhone.isNotEmpty ? customerPhone : '+92 300 1234567',
        _threadId = customerId.isNotEmpty ? 'thread_$customerId' : 'thread_guest',
        super(const SupportState(isAiThinking: false)) {
    _initStream();
  }

  void _initStream() {
    _sub = _repository.streamThreadMessages(_threadId).listen(
      (list) {
        state = state.copyWith(messages: list);
      },
      onError: (e) {
        state = state.copyWith(errorMessage: e.toString());
      },
    );
  }

  Future<void> sendUserMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = SupportMessageEntity(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      threadId: _threadId,
      senderType: SupportSenderType.user,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    await _repository.saveMessage(userMsg);
    state = state.copyWith(isAiThinking: true);

    try {
      // Simulate real AI latency & thinking
      await Future.delayed(const Duration(milliseconds: 700));

      final aiRes = await _aiEngine.processMessage(
        userText: text,
        customerId: _customerId,
        customerName: _customerName,
        customerPhone: _customerPhone,
        threadId: _threadId,
      );

      if (aiRes.createdTicket != null) {
        await _repository.saveTicket(aiRes.createdTicket!);
        state = state.copyWith(activeTicketId: aiRes.createdTicket!.id);
      }

      final aiMsg = SupportMessageEntity(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        threadId: _threadId,
        senderType: aiRes.toolType == 'human_escalation'
            ? SupportSenderType.humanAgent
            : SupportSenderType.aiAgent,
        text: aiRes.text,
        createdAt: DateTime.now(),
        toolType: aiRes.toolType,
        toolData: aiRes.toolData,
      );

      await _repository.saveMessage(aiMsg);
      state = state.copyWith(
        isAiThinking: false,
        isHumanAssigned: aiRes.toolType == 'human_escalation',
      );
    } catch (e) {
      state = state.copyWith(isAiThinking: false, errorMessage: e.toString());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final supportControllerProvider = StateNotifierProvider<SupportController, SupportState>((ref) {
  final repo = ref.watch(supportRepositoryProvider);
  final orderRepo = ref.watch(orderRepositoryProvider);
  final authState = ref.watch(authControllerProvider);

  final user = authState.user;
  final engine = AiSupportAgentEngine(orderRepository: orderRepo);

  return SupportController(
    repo,
    engine,
    customerId: user?.id ?? '',
    customerName: user?.name ?? 'Valued Customer',
    customerPhone: user?.phone ?? '+92 300 1234567',
  );
});
