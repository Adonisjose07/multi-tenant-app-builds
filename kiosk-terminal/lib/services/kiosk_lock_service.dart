import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing the enterprise kiosk hardening layer and native Android LockTask mode.
/// When LockTask is enabled, Android pins the application to the screen, hiding the OS navigation
/// bar, status bar, and preventing customers from exiting into the operating system.
class KioskLockService {
  static const String channelName = 'com.elorigen.kiosk/lock_task';
  static const String prefsLockEnabledKey = 'is_kiosk_lock_enabled';

  final MethodChannel _channel;
  final ValueNotifier<bool> _isLockedNotifier = ValueNotifier<bool>(false);

  KioskLockService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  /// Reactive notifier for UI observation of the kiosk lock state
  ValueListenable<bool> get isLockedNotifier => _isLockedNotifier;

  /// Current snapshot value of whether kiosk lockdown is enabled
  bool get isKioskModeEnabled => _isLockedNotifier.value;

  /// Initializes the service from persistent storage.
  /// If Kiosk Lock was previously active, re-engages native LockTask on startup.
  Future<void> init() async {
    final enabled = await isLockEnabled();
    _isLockedNotifier.value = enabled;

    if (enabled) {
      await _invokeNativeStartLockTask();
    }
  }

  /// Checks whether kiosk lockdown is configured to be active in persistent storage
  Future<bool> isLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsLockEnabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Queries native Android OS to determine if the activity is actively pinned in LockTask mode
  Future<bool> isInLockTaskMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('isInLockTaskMode');
      return res?['inLockTaskMode'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Enables kiosk lockdown: persists flag and invokes Android startLockTask
  Future<bool> enableKioskLock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsLockEnabledKey, true);
    } catch (_) {}

    _isLockedNotifier.value = true;
    return _invokeNativeStartLockTask();
  }

  /// Disables kiosk lockdown: persists flag and invokes Android stopLockTask
  Future<bool> disableKioskLock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsLockEnabledKey, false);
    } catch (_) {}

    _isLockedNotifier.value = false;
    return _invokeNativeStopLockTask();
  }

  Future<bool> _invokeNativeStartLockTask() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true; // Graceful simulation on non-Android platforms / tests
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('startLockTask');
      return res?['success'] as bool? ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _invokeNativeStopLockTask() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true; // Graceful simulation on non-Android platforms / tests
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('stopLockTask');
      return res?['success'] as bool? ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Releases resources
  void dispose() {
    _isLockedNotifier.dispose();
  }
}
