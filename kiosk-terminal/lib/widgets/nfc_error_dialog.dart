import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Modal dialog presented when contactless card read fails, times out, or is declined.
/// Includes a subtle shake entrance animation and 1-click fallback options to
/// Mobile QR code payment or Cashier / Counter payment.
class NfcErrorDialog extends StatefulWidget {
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onPayWithQr;
  final VoidCallback onPayAtCounter;

  const NfcErrorDialog({
    super.key,
    this.errorMessage,
    required this.onRetry,
    required this.onPayWithQr,
    required this.onPayAtCounter,
  });

  /// Static helper to display the dialog easily
  static Future<void> show({
    required BuildContext context,
    String? errorMessage,
    required VoidCallback onRetry,
    required VoidCallback onPayWithQr,
    required VoidCallback onPayAtCounter,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NfcErrorDialog(
        errorMessage: errorMessage,
        onRetry: () {
          Navigator.of(ctx).pop();
          onRetry();
        },
        onPayWithQr: () {
          Navigator.of(ctx).pop();
          onPayWithQr();
        },
        onPayAtCounter: () {
          Navigator.of(ctx).pop();
          onPayAtCounter();
        },
      ),
    );
  }

  @override
  State<NfcErrorDialog> createState() => _NfcErrorDialogState();
}

class _NfcErrorDialogState extends State<NfcErrorDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  static const Color brandPrimary = Color(0xFFEA581E);
  static const Color darkText = Color(0xFF1E293B);
  static const Color errorRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        // Sine wave damping shake offset: +/- 8px
        final decay = 1.0 - _shakeController.value;
        final offset =
            math.sin(_shakeController.value * math.pi * 6) * 8.0 * decay;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2), // Light red
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFCA5A5),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.contactless_rounded,
                    size: 38,
                    color: errorRed,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              const Text(
                'No pudimos leer tu tarjeta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),

              const SizedBox(height: 10),

              // Description
              Text(
                widget.errorMessage ??
                    'Asegúrate de acercar la tarjeta firmemente al sensor y mantenerla quieta por 2 segundos. O selecciona otra opción de pago:',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              // 1-Click Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Action 1: Reintentar
                  ElevatedButton.icon(
                    key: const Key('nfc_dialog_retry_button'),
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Reintentar Lectura NFC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action 2: Pagar con Celular (QR)
                  OutlinedButton.icon(
                    key: const Key('nfc_dialog_qr_button'),
                    onPressed: widget.onPayWithQr,
                    icon: const Icon(Icons.qr_code_rounded, size: 20),
                    label: const Text('Pagar con Celular (Código QR)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: const BorderSide(
                        color: Color(0xFFBFDBFE),
                        width: 1.5,
                      ),
                      backgroundColor: const Color(0xFFEFF6FF),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Action 3: Pagar en Caja / Mostrador
                  TextButton.icon(
                    key: const Key('nfc_dialog_counter_button'),
                    onPressed: widget.onPayAtCounter,
                    icon: const Icon(Icons.storefront_rounded, size: 20),
                    label: const Text('Pagar en Caja / Mostrador'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
