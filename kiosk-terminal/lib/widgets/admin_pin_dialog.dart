import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_keypad.dart';

/// 4-Digit Admin PIN Authentication Dialog with enterprise brute-force rate-limiting.
/// 5 consecutive failed attempts trigger an automatic 60-second temporary lockout.
class AdminPinDialog extends StatefulWidget {
  final String? expectedPin;
  final VoidCallback? onSuccess;

  const AdminPinDialog({
    super.key,
    this.expectedPin,
    this.onSuccess,
  });

  /// SharedPreferences key for stored admin PIN
  static const String prefsPinKey = 'kiosk_admin_pin';
  static const String defaultPin = '1234';
  static const int maxFailedAttempts = 5;
  static const int lockoutSeconds = 60;

  // Static tracking across dialog re-openings to prevent bypass by dismissing
  static int failedAttempts = 0;
  static DateTime? lockoutUntil;

  /// Test helper to reset rate-limiting state
  static void resetLockoutState() {
    failedAttempts = 0;
    lockoutUntil = null;
  }

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  String _enteredPin = '';
  String? _resolvedExpectedPin;
  String? _errorMessage;
  Timer? _lockoutTimer;
  int _remainingLockoutSeconds = 0;

  static const Color primaryColor = Color(0xFFEA581E);
  static const Color darkTextColor = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _checkInitialLockout();
    _loadStoredPin();
  }

  void _checkInitialLockout() {
    final lockout = AdminPinDialog.lockoutUntil;
    if (lockout != null && DateTime.now().isBefore(lockout)) {
      final remaining = lockout.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        _remainingLockoutSeconds = remaining;
        _startLockoutTimer();
      } else {
        AdminPinDialog.lockoutUntil = null;
        AdminPinDialog.failedAttempts = 0;
      }
    }
  }

  Future<void> _loadStoredPin() async {
    if (widget.expectedPin != null) {
      _resolvedExpectedPin = widget.expectedPin;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _resolvedExpectedPin = prefs.getString(AdminPinDialog.prefsPinKey) ?? AdminPinDialog.defaultPin;
    } catch (_) {
      _resolvedExpectedPin = AdminPinDialog.defaultPin;
    }
    if (mounted) setState(() {});
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingLockoutSeconds > 1) {
          _remainingLockoutSeconds--;
        } else {
          _remainingLockoutSeconds = 0;
          AdminPinDialog.lockoutUntil = null;
          AdminPinDialog.failedAttempts = 0;
          _errorMessage = null;
          timer.cancel();
        }
      });
    });
  }

  bool get _isLockedOut => _remainingLockoutSeconds > 0;

  void _onDigitPressed(String digit) {
    if (_isLockedOut || _enteredPin.length >= 4) return;

    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspacePressed() {
    if (_isLockedOut || _enteredPin.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onClearPressed() {
    if (_isLockedOut) return;
    setState(() {
      _errorMessage = null;
      _enteredPin = '';
    });
  }

  void _verifyPin() {
    final target = _resolvedExpectedPin ?? AdminPinDialog.defaultPin;
    if (_enteredPin == target) {
      // Success: reset rate limit counters
      AdminPinDialog.failedAttempts = 0;
      AdminPinDialog.lockoutUntil = null;
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } else {
      AdminPinDialog.failedAttempts++;
      if (AdminPinDialog.failedAttempts >= AdminPinDialog.maxFailedAttempts) {
        AdminPinDialog.lockoutUntil =
            DateTime.now().add(const Duration(seconds: AdminPinDialog.lockoutSeconds));
        _remainingLockoutSeconds = AdminPinDialog.lockoutSeconds;
        _startLockoutTimer();
        setState(() {
          _enteredPin = '';
          _errorMessage =
              'Demasiados intentos fallidos. Bloqueado temporalmente por ${AdminPinDialog.lockoutSeconds}s.';
        });
      } else {
        final remaining = AdminPinDialog.maxFailedAttempts - AdminPinDialog.failedAttempts;
        setState(() {
          _enteredPin = '';
          _errorMessage = 'PIN incorrecto. Intentos restantes: $remaining';
        });
      }
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('admin_pin_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon & Lock status
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _isLockedOut
                      ? const Color(0xFFEF4444).withOpacity(0.12)
                      : primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isLockedOut ? Icons.lock_clock_rounded : Icons.lock_outline_rounded,
                  size: 32,
                  color: _isLockedOut ? const Color(0xFFEF4444) : primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                _isLockedOut ? 'Acceso Bloqueado' : 'Acceso de Administrador',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: darkTextColor,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _isLockedOut
                    ? 'Espera a que expire el tiempo de seguridad para reintentar.'
                    : 'Ingresa el PIN de 4 dígitos para acceder a la configuración.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _isLockedOut ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),

              // Lockout Banner or PIN dots indicator
              if (_isLockedOut)
                Container(
                  key: const Key('admin_pin_lockout_banner'),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFFDC2626), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Reintentar en: ${_remainingLockoutSeconds}s',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  key: const Key('admin_pin_dots_row'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? primaryColor : Colors.transparent,
                        border: Border.all(
                          color: isFilled ? primaryColor : const Color(0xFFCBD5E1),
                          width: 2.5,
                        ),
                      ),
                    );
                  }),
                ),

              // Error feedback message
              if (_errorMessage != null && !_isLockedOut) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  key: const Key('admin_pin_error_text'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Keypad (Disabled if locked out)
              Opacity(
                opacity: _isLockedOut ? 0.35 : 1.0,
                child: AbsorbPointer(
                  absorbing: _isLockedOut,
                  child: CustomKeypad(
                    buttonHeight: 56.0,
                    spacing: 10.0,
                    onDigitPressed: _onDigitPressed,
                    onBackspacePressed: _onBackspacePressed,
                    onClearPressed: _onClearPressed,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  key: const Key('admin_pin_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
