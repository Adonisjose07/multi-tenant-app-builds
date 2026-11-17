import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../controllers/cart_controller.dart';
import '../controllers/kiosk_session_controller.dart';
import '../main.dart';
import '../models/kiosk_session.dart';
import '../services/sound_service.dart';

/// Screen displayed upon order placement.
/// Features:
/// - Extra-large order number (#42 or custom ID).
/// - Dining mode chip: [ 🍽️ COMER AQUÍ ] with table/pager or [ 🛍️ PARA LLEVAR ].
/// - Payment status banner: PAID (green check) or PENDING (counter payment warning).
/// - Dynamic QR code via [QrImageView] for mobile live tracking (`https://.../order/<orderId>`).
/// - 60-second inactivity countdown with progress indicator and 10s warning dialog.
/// - Prominent 56dp+ "Finalizar / Listo" button to immediately free the kiosk.
class OrderSuccessScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final KioskSessionController? sessionController;
  final CartController? cartController;
  final SoundService? soundService;
  final VoidCallback? onFinished;
  final String trackingBaseUrl;
  final int initialCountdownSeconds;
  final int warningThresholdSeconds;

  const OrderSuccessScreen({
    super.key,
    required this.order,
    this.sessionController,
    this.cartController,
    this.soundService,
    this.onFinished,
    this.trackingBaseUrl = 'https://apimono.elorigen.restaurant/order',
    this.initialCountdownSeconds = 60,
    this.warningThresholdSeconds = 10,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  static const Color brandPrimary = Color(0xFFEA581E);
  static const Color darkText = Color(0xFF1E293B);
  static const Color mutedText = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color surfaceColor = Color(0xFFF8FAFC);

  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _isWarningDialogOpen = false;
  late final SoundService _soundService;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialCountdownSeconds;
    _soundService = widget.soundService ?? SoundService();

    // Play celebratory sound on screen entry
    _soundService.playPaymentSuccess();

    // Start 60-second countdown
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });

        // Trigger warning dialog at threshold (default 10s remaining)
        if (_remainingSeconds <= widget.warningThresholdSeconds &&
            !_isWarningDialogOpen) {
          _showWarningDialog();
        }
      } else {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        _handleFinish();
      }
    });
  }

  void _showWarningDialog() {
    if (!mounted || _isWarningDialogOpen) return;
    _isWarningDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('order_success_warning_dialog'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.timer_outlined, color: brandPrimary, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¿Necesitas más tiempo?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: darkText,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '¿Necesitas más tiempo? El kiosko se cerrará en $_remainingSeconds s para liberar la pantalla al siguiente cliente en fila.',
            style: const TextStyle(fontSize: 16, color: darkText, height: 1.4),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              key: const Key('order_success_exit_now_button'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _isWarningDialogOpen = false;
                _soundService.playClick();
                _handleFinish();
              },
              child: const Text(
                'Salir Ahora',
                style: TextStyle(
                  color: mutedText,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('order_success_extend_time_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _isWarningDialogOpen = false;
                _soundService.playClick();
                setState(() {
                  _remainingSeconds += 30;
                });
              },
              child: const Text(
                '+30 Segundos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isWarningDialogOpen = false;
    });
  }

  void _handleFinish() {
    _countdownTimer?.cancel();
    _countdownTimer = null;

    if (_isWarningDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _isWarningDialogOpen = false;
    }

    // Reset controllers to safeguard customer PII & clear shopping state
    _getSessionController()?.resetSession();
    _getCartController()?.clear();

    if (widget.onFinished != null) {
      widget.onFinished!();
    } else if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  KioskSessionController? _getSessionController() {
    if (widget.sessionController != null) return widget.sessionController;
    try {
      return KioskScope.of(context);
    } catch (_) {
      return null;
    }
  }

  CartController? _getCartController() {
    if (widget.cartController != null) return widget.cartController;
    try {
      return CartScope.of(context);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data extraction helpers
  // ---------------------------------------------------------------------------

  String get _orderCode {
    final raw = widget.order['orderCode'] ??
        widget.order['orderNumber'] ??
        widget.order['id'] ??
        '42';
    final str = raw.toString().replaceAll('#', '');
    if (str.length == 24 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(str)) {
      return '#${str.substring(str.length - 6).toUpperCase()}';
    }
    return '#$str';
  }

  String get _orderId {
    return widget.order['id']?.toString() ??
        widget.order['orderNumber']?.toString() ??
        widget.order['orderCode']?.toString().replaceAll('#', '') ??
        '42';
  }

  String get _trackingUrl {
    final base = widget.trackingBaseUrl.endsWith('/')
        ? widget.trackingBaseUrl
            .substring(0, widget.trackingBaseUrl.length - 1)
        : widget.trackingBaseUrl;
    return '$base/$_orderId';
  }

  bool get _isPaid {
    final paymentStatus =
        widget.order['paymentStatus']?.toString().toUpperCase();
    if (paymentStatus == 'PENDING') return false;
    if (paymentStatus == 'PAID' ||
        paymentStatus == 'COMPLETED' ||
        paymentStatus == 'SUCCESS') {
      return true;
    }
    final paymentMethod =
        widget.order['paymentMethod']?.toString().toUpperCase();
    if (paymentMethod == 'COUNTER' || paymentMethod == 'CASH') return false;
    return true; // default paid for card / NFC transactions
  }

  bool get _isDineIn {
    final dt = widget.order['deliveryType']?.toString().toLowerCase() ??
        widget.order['deliveryMethod']?.toString().toLowerCase() ??
        _getSessionController()?.diningMode?.code ??
        'dine_in';
    return dt.contains('in') || dt.contains('comer');
  }

  String? get _tableOrPager {
    final val = widget.order['tableNumber']?.toString() ??
        widget.order['pagerNumber']?.toString() ??
        _getSessionController()?.tableOrPagerNumber;
    if (val != null && val.trim().isNotEmpty) {
      return val.trim();
    }
    return null;
  }

  String? get _customerPhone {
    final contact = widget.order['contactInfo'];
    if (contact is Map && contact['phoneNr'] != null) {
      return contact['phoneNr'].toString();
    }
    final sessionPhone = _getSessionController()?.phone;
    if (sessionPhone != null && sessionPhone.isNotEmpty) {
      return sessionPhone;
    }
    return null;
  }

  double? get _totalPrice {
    final raw = widget.order['paymentAmount'] ?? widget.order['totalPrice'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  // ---------------------------------------------------------------------------
  // Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final progressFraction = widget.initialCountdownSeconds > 0
        ? (_remainingSeconds / widget.initialCountdownSeconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Branding + Inactivity Countdown Badge
            _buildTopBar(),

            // Linear Progress Bar for 60s countdown
            LinearProgressIndicator(
              key: const Key('order_success_progress_bar'),
              value: progressFraction,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(brandPrimary),
              minHeight: 4,
            ),

            // Scrollable / Responsive Content Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 950;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column: Order Number & Details
                                  Expanded(
                                    flex: 6,
                                    child: _buildOrderDetailsCard(),
                                  ),
                                  const SizedBox(width: 24),
                                  // Right Column: Mobile Tracking QR
                                  Expanded(
                                    flex: 5,
                                    child: _buildMobileQrTrackingCard(),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildOrderDetailsCard(),
                                  const SizedBox(height: 20),
                                  _buildMobileQrTrackingCard(),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Action Area: Prominent "Finalizar / Listo" Button (56dp+ height)
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Logo / Title
          Expanded(
            child: Row(
              children: const [
                Icon(Icons.restaurant_rounded, color: brandPrimary, size: 28),
                SizedBox(width: 10),
                Text(
                  'El Origen',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '• Kiosko Auto-Servicio',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Inactivity Countdown Badge
          Container(
            key: const Key('order_success_timer_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _remainingSeconds <= widget.warningThresholdSeconds
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _remainingSeconds <= widget.warningThresholdSeconds
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: _remainingSeconds <= widget.warningThresholdSeconds
                      ? const Color(0xFFDC2626)
                      : darkText,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cerrando en ${_remainingSeconds}s',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds <= widget.warningThresholdSeconds
                        ? const Color(0xFFDC2626)
                        : darkText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    final dineIn = _isDineIn;
    final tablePager = _tableOrPager;
    final paid = _isPaid;
    final total = _totalPrice;
    final phone = _customerPhone;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Number Header Label
          const Text(
            'TU NÚMERO DE ORDEN',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: mutedText,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),

          // Extra-Large Order Number Display
          Text(
            _orderCode,
            key: const Key('order_success_order_number'),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: brandPrimary,
              letterSpacing: -1.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),

          // Dining Mode & Table / Pager Chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Dining Mode Chip
              Container(
                key: const Key('order_success_dining_mode_chip'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: dineIn
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dineIn
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFE9D5FF),
                  ),
                ),
                child: Text(
                  dineIn ? '🍽️ COMER AQUÍ' : '🛍️ PARA LLEVAR',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: dineIn
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF7E22CE),
                  ),
                ),
              ),

              // Table / Pager Number Chip if Dine In
              if (dineIn && tablePager != null)
                Container(
                  key: const Key('order_success_table_pager_chip'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.table_restaurant_rounded,
                          size: 16, color: darkText),
                      const SizedBox(width: 6),
                      Text(
                        'Mesa / Localizador: #$tablePager',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Payment Status Banner
          if (paid)
            _buildPaidStatusBanner()
          else
            _buildPendingStatusBanner(),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), thickness: 1),
          const SizedBox(height: 16),

          // Total Price & Summary Information
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total de la comanda:',
                  style: TextStyle(
                    fontSize: 16,
                    color: mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                total != null ? '\$${total.toStringAsFixed(2)}' : '\$0.00',
                key: const Key('order_success_total_amount'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
            ],
          ),

          // SMS Phone notification reminder if phone was provided
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sms_outlined, size: 16, color: mutedText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Te notificaremos por SMS a $phone cuando tu orden esté lista.',
                      style: const TextStyle(fontSize: 13, color: mutedText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaidStatusBanner() {
    return Container(
      key: const Key('order_success_paid_badge'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 32,
            color: successGreen,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Pago completado con éxito',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tu comanda ha sido enviada directamente a la cocina y está en preparación.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF047857),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingStatusBanner() {
    return Container(
      key: const Key('order_success_pending_badge'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 32,
            color: warningAmber,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '⚠️ PAGO PENDIENTE EN CAJA - Pasa a mostrador con tu ticket para abonar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Muestra tu número de orden en caja. La preparación comenzará una vez registrado el cobro.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB45309),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileQrTrackingCard() {
    final qrData = _trackingUrl;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.qr_code_scanner_rounded, color: brandPrimary, size: 24),
              SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Seguimiento en Vivo en tu Celular',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Instructional prompt specified in Task 9 brief
          const Text(
            'Escanea con tu celular para ver el estado de tu pedido en vivo desde tu mesa',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: mutedText,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),

          // Dynamic QR Code Rendering via qr_flutter QrImageView
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  offset: Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                key: const Key('order_tracking_qr_code'),
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: darkText,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: darkText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tracking URL Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              qrData,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Compatible con la cámara de cualquier smartphone. No requiere app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SizedBox(
            width: double.infinity,
            height: 60, // 56dp+ height requirement
            child: ElevatedButton(
              key: const Key('order_success_finish_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandPrimary,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                _soundService.playClick();
                _handleFinish();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle_outline_rounded, size: 24),
                  SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Finalizar / Listo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
