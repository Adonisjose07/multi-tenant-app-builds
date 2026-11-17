import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/kiosk_session.dart';
export '../models/kiosk_session.dart';

class KioskSessionController extends ChangeNotifier {
  static const Duration defaultInactivityTimeout = Duration(seconds: 60);

  KioskSession _session = KioskSession();
  Timer? _inactivityTimer;
  VoidCallback? onSessionTimeout;
  final Duration timeoutDuration;

  KioskSessionController({
    this.timeoutDuration = defaultInactivityTimeout,
    this.onSessionTimeout,
  });

  KioskSession get session => _session;
  String get phone => _session.phone;
  String? get email => _session.email;
  DiningMode? get diningMode => _session.diningMode;
  String? get tableOrPagerNumber => _session.tableOrPagerNumber;
  bool get isPhoneValid => _session.isPhoneValid;
  bool get isEmailValid => _session.isEmailValid;

  // ---------------------------------------------------------------------------
  // Inactivity & Privacy Sanitization
  // ---------------------------------------------------------------------------

  /// Called on user touch / gesture to reset the idle countdown
  void userInteracted() {
    resetInactivityTimer();
  }

  /// Starts or restarts the inactivity timer
  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(timeoutDuration, _onTimerTriggered);
  }

  /// Alias to start inactivity timer
  void startInactivityTimer() {
    resetInactivityTimer();
  }

  /// Stops the timer (e.g. while on AttractScreen)
  void stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _onTimerTriggered() {
    // Wipe all customer PII and notify timeout
    resetSession();
    onSessionTimeout?.call();
  }

  /// Wipes all entered customer data from memory to preserve kiosk privacy
  void resetSession() {
    _session = KioskSession();
    stopInactivityTimer();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Phone Mutators
  // ---------------------------------------------------------------------------

  void setPhone(String phone) {
    userInteracted();
    _session = _session.copyWith(phone: phone);
    notifyListeners();
  }

  void appendPhoneDigit(String digit) {
    if (_session.rawPhone.length >= 15) return; // Prevent unreasonable length
    userInteracted();
    final newPhone = '${_session.phone}$digit';
    _session = _session.copyWith(phone: newPhone);
    notifyListeners();
  }

  void backspacePhone() {
    userInteracted();
    if (_session.phone.isNotEmpty) {
      final newPhone = _session.phone.substring(0, _session.phone.length - 1);
      _session = _session.copyWith(phone: newPhone);
      notifyListeners();
    }
  }

  void clearPhone() {
    userInteracted();
    _session = _session.copyWith(phone: '');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Email Mutators
  // ---------------------------------------------------------------------------

  void setEmail(String? email) {
    userInteracted();
    _session = _session.copyWith(email: email, clearEmail: email == null);
    notifyListeners();
  }

  void appendEmailChar(String char) {
    userInteracted();
    final current = _session.email ?? '';
    _session = _session.copyWith(email: '$current$char');
    notifyListeners();
  }

  void backspaceEmail() {
    userInteracted();
    final current = _session.email ?? '';
    if (current.isNotEmpty) {
      final updated = current.substring(0, current.length - 1);
      _session = _session.copyWith(email: updated);
      notifyListeners();
    }
  }

  void clearEmail() {
    userInteracted();
    _session = _session.copyWith(email: '', clearEmail: true);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Dining Mode & Table / Pager Mutators
  // ---------------------------------------------------------------------------

  void setDiningMode(DiningMode mode) {
    userInteracted();
    _session = _session.copyWith(diningMode: mode);
    notifyListeners();
  }

  void setTableOrPagerNumber(String? number) {
    userInteracted();
    _session = _session.copyWith(
      tableOrPagerNumber: number,
      clearTableOrPager: number == null,
    );
    notifyListeners();
  }

  void appendTableDigit(String digit) {
    userInteracted();
    final current = _session.tableOrPagerNumber ?? '';
    if (current.length >= 5) return;
    _session = _session.copyWith(tableOrPagerNumber: '$current$digit');
    notifyListeners();
  }

  void backspaceTableDigit() {
    userInteracted();
    final current = _session.tableOrPagerNumber ?? '';
    if (current.isNotEmpty) {
      final updated = current.substring(0, current.length - 1);
      _session = _session.copyWith(tableOrPagerNumber: updated);
      notifyListeners();
    }
  }

  void clearTableDigit() {
    userInteracted();
    _session = _session.copyWith(tableOrPagerNumber: '', clearTableOrPager: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
