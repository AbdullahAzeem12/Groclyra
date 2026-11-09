import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

final audioNavigationProvider = ChangeNotifierProvider<AudioNavigationService>((ref) {
  return AudioNavigationService();
});

class AudioNavigationService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _isMuted = false;
  bool _isSpeaking = false;
  String? _lastAnnouncedText;
  DateTime? _lastAnnouncedAt;

  bool get isMuted => _isMuted;
  bool get isSpeaking => _isSpeaking;

  AudioNavigationService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[AudioNavigation] TTS Error: $msg');
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[AudioNavigation] Init error: $e');
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _tts.stop();
    } else {
      speak('Audio navigation unmuted');
    }
    notifyListeners();
  }

  Future<void> speak(String text) async {
    if (_isMuted) return;

    // Prevent immediate repeated identical speech
    final now = DateTime.now();
    if (_lastAnnouncedText == text &&
        _lastAnnouncedAt != null &&
        now.difference(_lastAnnouncedAt!).inSeconds < 8) {
      return;
    }

    _lastAnnouncedText = text;
    _lastAnnouncedAt = now;

    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[AudioNavigation] Speak error: $e');
    }
  }

  /// Announces a distance-based turn instruction
  Future<void> announceManeuver(String instruction, double distanceMeters) async {
    if (_isMuted) return;

    String announcement;
    if (distanceMeters > 500) {
      final km = (distanceMeters / 1000).toStringAsFixed(1);
      announcement = 'In $km kilometers, $instruction';
    } else if (distanceMeters > 60) {
      announcement = 'In ${(distanceMeters ~/ 10) * 10} meters, $instruction';
    } else {
      announcement = instruction;
    }

    await speak(announcement);
  }

  /// Announces arrival at pickup store or customer destination
  Future<void> announceArrival(String destinationName, bool isPickup) async {
    if (isPickup) {
      await speak('You have arrived at pickup merchant $destinationName. Collect the packages.');
    } else {
      await speak('You have arrived at customer delivery destination. Ask for the 4-digit verification code.');
    }
  }

  /// Announces OTP verification success
  Future<void> announceDeliverySuccess(String orderNumber) async {
    await speak('Order $orderNumber delivery completed successfully. Earnings credited to your wallet.');
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}

