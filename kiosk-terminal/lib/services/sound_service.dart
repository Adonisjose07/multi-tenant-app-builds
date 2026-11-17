import 'package:flutter/services.dart';

/// Sound categories emitted during the self-service kiosk workflow
enum KioskSoundType {
  cardDetected,
  paymentSuccess,
  error,
  click,
}

/// Service providing audible tactile chime feedback to the customer.
/// Plays native system clicks or tones when cards are tapped and payments succeed.
class SoundService {
  final Future<void> Function(KioskSoundType type)? _customPlayer;
  bool _enabled;

  SoundService({
    Future<void> Function(KioskSoundType type)? customPlayer,
    bool enabled = true,
  })  : _customPlayer = customPlayer,
        _enabled = enabled;

  bool get isEnabled => _enabled;

  set isEnabled(bool value) {
    _enabled = value;
  }

  /// Emits a chime when the NFC chip is first detected by the antenna
  Future<void> playCardDetected() async {
    if (!_enabled) return;
    if (_customPlayer != null) {
      await _customPlayer!(KioskSoundType.cardDetected);
      return;
    }
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Emits a celebratory chime when the payment is approved by the bank
  Future<void> playPaymentSuccess() async {
    if (!_enabled) return;
    if (_customPlayer != null) {
      await _customPlayer!(KioskSoundType.paymentSuccess);
      return;
    }
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Emits an alert chime when a card read error or decline occurs
  Future<void> playError() async {
    if (!_enabled) return;
    if (_customPlayer != null) {
      await _customPlayer!(KioskSoundType.error);
      return;
    }
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  /// Standard soft click on button press
  Future<void> playClick() async {
    if (!_enabled) return;
    if (_customPlayer != null) {
      await _customPlayer!(KioskSoundType.click);
      return;
    }
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
