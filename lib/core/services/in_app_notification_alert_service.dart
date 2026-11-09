import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/routing/route_names.dart';

/// Service managing custom audio chimes, haptics, voice TTS prompts,
/// and animated floating in-app notification alerts for Groclyra.
class InAppNotificationAlertService {
  InAppNotificationAlertService._();
  static final InAppNotificationAlertService instance = InAppNotificationAlertService._();

  FlutterTts? _flutterTts;
  final Set<String> _seenNotificationIds = {};
  StreamSubscription? _notifSub;
  OverlayEntry? _currentBannerOverlay;
  Timer? _dismissTimer;
  bool _isInitialized = false;

  /// Initializes the audio and TTS subsystem.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _flutterTts = FlutterTts();
      await _flutterTts?.setLanguage('en-US');
      await _flutterTts?.setSpeechRate(0.5);
      await _flutterTts?.setVolume(1.0);
      await _flutterTts?.setPitch(1.0);
    } catch (e) {
      debugPrint('[InAppAlert] TTS Init note: $e');
    }
    _isInitialized = true;
  }

  /// Starts listening to real-time notifications for the given user ID.
  void startListening(BuildContext context, String userId) {
    if (userId.isEmpty) return;
    _notifSub?.cancel();

    // Prime seen set with existing notifications so initial fetch doesn't trigger alarms
    AppDatabase.instance.query(
      'notifications',
      where: 'recipientId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
      limit: 30,
    ).then((existing) {
      for (final row in existing) {
        final id = row['id']?.toString();
        if (id != null) _seenNotificationIds.add(id);
      }
    });

    _notifSub = AppDatabase.instance.watchTable('notifications').listen((_) async {
      try {
        final rows = await AppDatabase.instance.query(
          'notifications',
          where: 'recipientId = ? AND isRead = 0',
          whereArgs: [userId],
          orderBy: 'createdAt DESC',
          limit: 5,
        );

        if (!context.mounted) return;

        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty && !_seenNotificationIds.contains(id)) {
            _seenNotificationIds.add(id);
            if (!context.mounted) return;
            _triggerAlert(
              context: context,
              id: id,
              kind: row['type']?.toString() ?? 'system',
              title: row['title']?.toString() ?? 'New Notification',
              body: row['body']?.toString() ?? '',
            );
          }
        }
      } catch (e) {
        debugPrint('[InAppAlert] Watcher error: $e');
      }
    });
  }

  /// Triggers sound, haptics, voice announcement, and the animated in-app banner.
  Future<void> _triggerAlert({
    required BuildContext context,
    required String id,
    required String kind,
    required String title,
    required String body,
  }) async {
    // 1. Audio chime & vibration
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (_) {}

    // 2. TTS Voice Prompt for delivery milestones
    if (kind == 'outForDelivery' || title.toLowerCase().contains('out for delivery')) {
      _speakVoice('Groclyra Express: Your package is out for delivery with our rider!');
    } else if (kind == 'delivered' || title.toLowerCase().contains('delivered')) {
      _speakVoice('Your Groclyra delivery is complete. Thank you for ordering!');
    } else if (kind == 'pickedUp' || title.toLowerCase().contains('picked up')) {
      _speakVoice('Your order has been picked up from the merchant.');
    }

    // 3. Floating top in-app banner overlay
    if (context.mounted) {
      _showFloatingBanner(
        context: context,
        kind: kind,
        title: title,
        body: body,
      );
    }
  }

  void _speakVoice(String text) async {
    try {
      await _flutterTts?.stop();
      await _flutterTts?.speak(text);
    } catch (e) {
      debugPrint('[InAppAlert] TTS Speak error: $e');
    }
  }

  void _showFloatingBanner({
    required BuildContext context,
    required String kind,
    required String title,
    required String body,
  }) {
    _dismissTimer?.cancel();
    _currentBannerOverlay?.remove();
    _currentBannerOverlay = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDelivered = kind == 'delivered' || title.toLowerCase().contains('delivered');
    final isOutForDelivery = kind == 'outForDelivery' || title.toLowerCase().contains('out for delivery');

    final Color bannerColor = isDelivered
        ? const Color(0xFF10B981)
        : (isOutForDelivery ? const Color(0xFFF59E0B) : const Color(0xFF6366F1));

    final IconData bannerIcon = isDelivered
        ? Icons.check_circle_rounded
        : (isOutForDelivery ? Icons.two_wheeler_rounded : Icons.notifications_active_rounded);

    _currentBannerOverlay = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: MediaQuery.of(ctx).padding.top + 10,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: -50.0, end: 0.0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (context, translateY, child) {
                return Transform.translate(
                  offset: Offset(0, translateY),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161C26) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: bannerColor.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: bannerColor.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bannerColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(bannerIcon, color: bannerColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _currentBannerOverlay?.remove();
                        _currentBannerOverlay = null;
                        if (isOutForDelivery || isDelivered) {
                          context.push(RouteNames.customerTracking);
                        } else {
                          context.push(RouteNames.customerNotifications);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: bannerColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isOutForDelivery ? 'Track' : 'View',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_currentBannerOverlay!);

    _dismissTimer = Timer(const Duration(seconds: 6), () {
      _currentBannerOverlay?.remove();
      _currentBannerOverlay = null;
    });
  }

  void stop() {
    _dismissTimer?.cancel();
    _currentBannerOverlay?.remove();
    _currentBannerOverlay = null;
    _notifSub?.cancel();
    _notifSub = null;
  }
}

final inAppNotificationAlertServiceProvider = Provider<InAppNotificationAlertService>((ref) {
  return InAppNotificationAlertService.instance;
});
