import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/features/customer/support/domain/entities/support_entities.dart';
import 'package:groclyra/features/customer/support/presentation/controllers/support_controller.dart';


class AiCustomerSupportScreen extends ConsumerStatefulWidget {
  const AiCustomerSupportScreen({super.key});

  @override
  ConsumerState<AiCustomerSupportScreen> createState() => _AiCustomerSupportScreenState();
}

class _AiCustomerSupportScreenState extends ConsumerState<AiCustomerSupportScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickPrompts = [
    'Track My Recent Order',
    'Report Damaged or Missing Item',
    'Cancel My Order',
    'Delivery Coverage & Timelines',
    'Talk to Human Support Agent',
    'Mera order kab pohnche ga?',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? customText]) {
    final text = customText ?? _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    ref.read(supportControllerProvider.notifier).sendUserMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final supportState = ref.watch(supportControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = themeState.palette.primaryColor;

    ref.listen(supportControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || next.isAiThinking) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Customer Support',
        subtitle: 'Always here to help • Available 24/7',
        showBack: true,
        showThemePicker: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_pin_circle_rounded, color: Colors.white),
            tooltip: 'Talk to Human Agent',
            onPressed: () => _sendMessage('I would like to speak with a human support agent.'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Quick Action Pills
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: isDark ? const Color(0xFF10141D) : Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickPrompts.length,
              itemBuilder: (context, idx) {
                final prompt = _quickPrompts[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SpringTouchScale(
                    onTap: () => _sendMessage(prompt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF181E2B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        prompt,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // 2. Chat Messages Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: supportState.messages.length + (supportState.isAiThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == supportState.messages.length && supportState.isAiThinking) {
                  return _buildAiThinkingBubble(primaryColor, isDark);
                }
                final msg = supportState.messages[index];
                return _buildMessageBubble(context, msg, isDark, primaryColor, themeState);
              },
            ),
          ),

          // 3. Bottom Text Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121722) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type query in English, Urdu or Roman Urdu...',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1A2130) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF262E3D) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SpringTouchScale(
                  onTap: () => _sendMessage(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: themeState.palette.linearGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiThinkingBubble(Color primaryColor, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2130) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
            ),
            const SizedBox(width: 10),
            Text(
              'Groclyra AI is retrieving live orders & policy data...',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    SupportMessageEntity msg,
    bool isDark,
    Color primaryColor,
    ThemeState themeState,
  ) {
    final isUser = msg.senderType == SupportSenderType.user;
    final timeStr = DateFormat('hh:mm a').format(msg.createdAt);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name & time header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser) ...[
                    Icon(
                      msg.senderType == SupportSenderType.humanAgent
                          ? Icons.support_agent_rounded
                          : Icons.auto_awesome_rounded,
                      size: 13,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    msg.senderType.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUser ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),

            // Message Bubble Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? null
                    : (isDark ? const Color(0xFF141923) : Colors.white),
                gradient: isUser ? themeState.palette.linearGradient : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: !isUser
                    ? Border.all(
                        color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),

                  // Rich Tool Cards
                  if (msg.toolType != null && msg.toolData != null) ...[
                    const SizedBox(height: 12),
                    _buildToolCard(context, msg.toolType!, msg.toolData!, primaryColor, isDark),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context,
    String toolType,
    Map<String, dynamic> data,
    Color primaryColor,
    bool isDark,
  ) {
    if (toolType == 'order_status') {
      final orderNumber = data['orderNumber'] ?? 'GL-49281';
      final statusLabel = data['statusLabel'] ?? 'In Transit';
      final riderName = data['riderName'] ?? 'Muhammad Tariq';
      final riderPhone = data['riderPhone'] ?? '+92 300 9876543';
      final orderId = data['orderId'] ?? 'ord_sample_9021';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2837) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📦 Order #$orderNumber',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('🛵 Rider: $riderName • $riderPhone', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.navigation_rounded, size: 14, color: Colors.white),
              label: const Text('Open Live GPS Tracking', style: TextStyle(color: Colors.white, fontSize: 11)),
              onPressed: () => context.push('${RouteNames.customerTracking}/$orderId'),
            ),
          ],
        ),
      );
    }

    if (toolType == 'return_request') {
      final ticketId = data['ticketId'] ?? 'RET-8429';
      final resolution = data['resolution'] ?? 'Free Replacement Dispatched';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Claim #$ticketId Approved',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Resolution: $resolution', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            const Text('Zero charges applied under Groclyra 48-hr guarantee.', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      );
    }

    if (toolType == 'cancellation') {
      final ref = data['cancellationRef'] ?? 'CNC-1029';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel_rounded, color: Colors.red, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Cancellation Ref #$ref',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Refund processed back to your original payment channel within 3-5 days.', style: TextStyle(fontSize: 11)),
          ],
        ),
      );
    }

    if (toolType == 'human_escalation') {
      final tId = data['ticketId'] ?? 'TKT-9921';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.headset_mic_rounded, color: Colors.purpleAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Escalation Ticket #$tId',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purpleAccent),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Assigned to Staffed Support Queue • Expected reply in 10-15 mins.', style: TextStyle(fontSize: 11)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
