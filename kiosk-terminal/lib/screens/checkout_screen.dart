import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../controllers/cart_controller.dart';
import '../controllers/kiosk_session_controller.dart';
import '../main.dart';
import '../models/kiosk_session.dart';
import '../models/nfc_quadrant.dart';
import '../services/kiosk_api_service.dart';
import '../services/sound_service.dart';
import '../services/stripe_terminal_service.dart';
import '../widgets/nfc_error_dialog.dart';
import '../widgets/nfc_radar_widget.dart';
import '../widgets/qr_payment_widget.dart';
import '../widgets/tip_selector_widget.dart';

enum PaymentMethodTab {
  nfc,
  qr,
  counter,
}

/// Checkout Screen for El Origen Self-Service Kiosk.
/// Incorporates:
/// 1. Dynamic NFC antenna calibration & pulsing radar animation.
/// 2. Live tip calculation & order review.
/// 3. Multi-payment alternatives: Tap to Pay (NFC), QR Code, Cashier/Counter.
/// 4. Audible chime feedback via SoundService.
/// 5. Double-tap protection & graceful error recovery with 1-click fallback.
class CheckoutScreen extends StatefulWidget {
  final KioskSessionController? sessionController;
  final CartController? cartController;
  final StripeTerminalService? terminalService;
  final KioskApiService? apiService;
  final SoundService? soundService;
  final NfcQuadrant? initialQuadrant;
  final String branchId;

  const CheckoutScreen({
    super.key,
    this.sessionController,
    this.cartController,
    this.terminalService,
    this.apiService,
    this.soundService,
    this.initialQuadrant,
    this.branchId = 'branch_default',
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color brandPrimary = Color(0xFFEA581E);
  static const Color brandSurface = Color(0xFFF8FAFC);
  static const Color darkText = Color(0xFF1E293B);

  late final StripeTerminalService _terminalService;
  late final KioskApiService _apiService;
  late final SoundService _soundService;

  NfcQuadrant _quadrant = NfcQuadrant.topRight;
  PaymentMethodTab _selectedTab = PaymentMethodTab.nfc;

  StreamSubscription<void>? _cardDetectedSub;
  VoidCallback? _terminalStateListener;

  bool _isProcessing = false;
  bool _isErrorDialogShowing = false;
  bool _orderCreated = false;

  @override
  void initState() {
    super.initState();
    _terminalService = widget.terminalService ?? StripeTerminalService();
    _apiService = widget.apiService ?? KioskApiService();
    _soundService = widget.soundService ?? SoundService();

    _loadQuadrant();
    _setupTerminalListeners();

    // Start NFC payment automatically on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNfcPayment();
    });
  }

  Future<void> _loadQuadrant() async {
    if (widget.initialQuadrant != null) {
      setState(() => _quadrant = widget.initialQuadrant!);
    } else {
      final loaded = await NfcQuadrantExtension.loadConfigured();
      if (mounted) {
        setState(() => _quadrant = loaded);
      }
    }
  }

  void _setupTerminalListeners() {
    // 1. Audio chime on card detected
    _cardDetectedSub = _terminalService.onCardDetected.listen((_) {
      _soundService.playCardDetected();
    });

    // 2. Terminal state transitions
    _terminalStateListener = () {
      final state = _terminalService.currentState;

      if (!mounted) return;

      if (state.isSuccess && !_orderCreated && !_isProcessing) {
        _soundService.playPaymentSuccess();
        _handlePaymentSuccess(
          paymentMethod: 'CARD',
          paymentIntentId: state.lastPaymentIntentId,
        );
      } else if (state.isFailed && !_isErrorDialogShowing && !_orderCreated) {
        _soundService.playError();
        _showNfcErrorModal(state.errorMessage);
      }
    };

    _terminalService.stateNotifier.addListener(_terminalStateListener!);
  }

  KioskSessionController _getSessionController() {
    if (widget.sessionController != null) {
      return widget.sessionController!;
    }
    return KioskScope.of(context);
  }

  CartController _getCartController() {
    if (widget.cartController != null) {
      return widget.cartController!;
    }
    return CartScope.of(context);
  }

  Future<void> _startNfcPayment() async {
    if (_isProcessing || _orderCreated) return;
    if (_selectedTab != PaymentMethodTab.nfc) return;

    final cart = _getCartController();
    if (cart.isEmpty) return;

    _terminalService.resetPaymentState();

    try {
      // 1. Ensure terminal initialized
      if (_terminalService.currentState.connectionStatus !=
          TerminalConnectionStatus.connected) {
        await _terminalService.initialize(widget.branchId);
      }

      // 2. Create PaymentIntent on backend
      final piData = await _apiService.createPaymentIntent(
        branchId: widget.branchId,
        amount: cart.total,
      );

      final clientSecret = piData['clientSecret'] as String? ?? '';
      if (clientSecret.isEmpty) {
        throw Exception('No se pudo generar el secreto de pago.');
      }

      // 3. Collect & Process contactless tap
      await _terminalService.collectAndProcessPayment(
        clientSecret: clientSecret,
        amount: cart.total,
      );
    } catch (e) {
      if (mounted && !_isErrorDialogShowing && !_orderCreated) {
        _soundService.playError();
        _showNfcErrorModal(e.toString());
      }
    }
  }

  void _showNfcErrorModal(String? errorMessage) {
    if (_isErrorDialogShowing || _orderCreated || !mounted) return;
    setState(() => _isErrorDialogShowing = true);

    NfcErrorDialog.show(
      context: context,
      errorMessage: errorMessage,
      onRetry: () {
        setState(() => _isErrorDialogShowing = false);
        _startNfcPayment();
      },
      onPayWithQr: () {
        setState(() {
          _isErrorDialogShowing = false;
          _selectedTab = PaymentMethodTab.qr;
        });
        _terminalService.cancelPayment();
      },
      onPayAtCounter: () {
        setState(() {
          _isErrorDialogShowing = false;
          _selectedTab = PaymentMethodTab.counter;
        });
        _terminalService.cancelPayment();
      },
    );
  }

  void _onTipChanged(double tip) {
    final session = _getSessionController();
    session.userInteracted();

    final cart = _getCartController();
    cart.setTipAmount(tip);

    // If currently waiting for NFC card, restart payment with updated total
    if (_selectedTab == PaymentMethodTab.nfc &&
        _terminalService.currentState.isWaitingForCard) {
      _terminalService.cancelPayment();
      _startNfcPayment();
    }
  }

  Future<void> _handlePaymentSuccess({
    required String paymentMethod,
    String? paymentIntentId,
  }) async {
    if (_isProcessing || _orderCreated) return;
    setState(() => _isProcessing = true);

    final session = _getSessionController();
    final cart = _getCartController();

    try {
      final itemsPayload = jsonEncode(
        cart.items.map((item) => item.toJson()).toList(),
      );

      final input = {
        'branchId': widget.branchId,
        'deliveryMethod': session.diningMode?.code ?? 'dine_in',
        'tableNumber': session.tableOrPagerNumber,
        'pagerNumber': session.tableOrPagerNumber,
        'kioskDeviceId': 'kiosk_${_quadrant.name}',
        'contactInfo': {
          'firstName': 'Cliente',
          'lastName': 'Kiosk',
          'phoneNr': session.phone,
          'email': session.email,
        },
        'itemsJson': itemsPayload,
        'tipAmount': cart.tipAmount,
        'paymentMethod': paymentMethod,
        'paymentIntentId': paymentIntentId,
      };

      final response = await _apiService.createKioskOrder(input);

      if (response['success'] == true && response['order'] != null) {
        _orderCreated = true;
        final createdOrder = response['order'] as Map<String, dynamic>;

        cart.clear();

        if (mounted) {
          _navigateToSuccessScreen(createdOrder);
        }
      } else {
        throw Exception(
            response['message'] ?? 'Error al registrar orden en el sistema.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar orden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleCounterCheckout() async {
    final session = _getSessionController();
    session.userInteracted();
    _soundService.playPaymentSuccess();

    await _handlePaymentSuccess(
      paymentMethod: 'COUNTER',
      paymentIntentId: null,
    );
  }

  Future<void> _handleQrPaymentCompleted() async {
    final session = _getSessionController();
    session.userInteracted();
    _soundService.playPaymentSuccess();

    await _handlePaymentSuccess(
      paymentMethod: 'CARD',
      paymentIntentId: 'pi_mock_qr_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  void _navigateToSuccessScreen(Map<String, dynamic> order) {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/order-success',
      (route) => route.isFirst,
      arguments: order,
    );
  }

  void _onSelectTab(PaymentMethodTab tab) {
    final session = _getSessionController();
    session.userInteracted();

    if (_isProcessing || _orderCreated) return;

    if (_selectedTab == PaymentMethodTab.nfc && tab != PaymentMethodTab.nfc) {
      _terminalService.cancelPayment();
    }

    setState(() {
      _selectedTab = tab;
    });

    if (tab == PaymentMethodTab.nfc) {
      _startNfcPayment();
    }
  }

  @override
  void dispose() {
    _cardDetectedSub?.cancel();
    if (_terminalStateListener != null) {
      _terminalService.stateNotifier.removeListener(_terminalStateListener!);
    }
    if (!_orderCreated) {
      _terminalService.cancelPayment();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _getSessionController();
    final cart = _getCartController();

    return Scaffold(
      backgroundColor: brandSurface,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('checkout_back_button'),
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: _isProcessing
              ? null
              : () {
                  _terminalService.cancelPayment();
                  Navigator.of(context).pop();
                },
        ),
        title: const Text(
          'Revisión y Pago de la Orden',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),
        centerTitle: false,
        actions: [
          // Order Type Badge
          Container(
            margin: const EdgeInsets.only(right: 24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  session.diningMode == DiningMode.dineIn
                      ? Icons.restaurant_rounded
                      : Icons.shopping_bag_outlined,
                  size: 18,
                  color: brandPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  session.diningMode?.label ?? 'Para Comer Aquí',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: darkText,
                  ),
                ),
                if (session.tableOrPagerNumber?.isNotEmpty == true) ...[
                  const Text('  •  ',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                  Text(
                    'Mesa/Localizador: ${session.tableOrPagerNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: brandPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Dual-Pane Layout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Pane: Order Breakdown & Live Tip Adjuster (450px)
                  SizedBox(
                    width: 440,
                    child: _buildOrderSummaryPane(session, cart),
                  ),

                  const SizedBox(width: 24),

                  // Right Pane: Multi-Payment Tabs & Active Method View
                  Expanded(
                    child: _buildPaymentPane(cart),
                  ),
                ],
              ),
            ),
          ),

          // Double-Tap & Processing Protection Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(brandPrimary),
                      strokeWidth: 4,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Registrando tu orden...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left Pane: Order Summary
  // ---------------------------------------------------------------------------

  Widget _buildOrderSummaryPane(
    KioskSessionController session,
    CartController cart,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Customer PII preview
          Row(
            children: [
              const Icon(
                Icons.person_pin_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cliente: ${session.session.formattedPhone}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Items preview header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Resumen de Productos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${cart.itemCount} items',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Scrollable items preview list
          Expanded(
            child: ListView.separated(
              itemCount: cart.items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 14, color: Color(0xFFF8FAFC)),
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quantity badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.quantity}x',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Product name & modifiers
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: darkText,
                            ),
                          ),
                          if (item.hasModifiers)
                            Text(
                              item.modifiersDescription,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Total line price
                    Text(
                      item.formattedTotalPrice,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Tip Selector
          TipSelectorWidget(
            subtotal: cart.subtotal,
            currentTip: cart.tipAmount,
            onTipSelected: _onTipChanged,
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Financial breakdown
          _buildFinancialRow('Subtotal', cart.formattedSubtotal),
          if (cart.taxAmount > 0)
            _buildFinancialRow('Impuestos (Tax)', cart.formattedTax),
          _buildFinancialRow(
            'Propina',
            cart.formattedTip,
            color: cart.tipAmount > 0 ? const Color(0xFF10B981) : null,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total a Pagar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                cart.formattedTotal,
                key: const Key('checkout_formatted_total'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: brandPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color ?? darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right Pane: Multi-Payment Alternatives
  // ---------------------------------------------------------------------------

  Widget _buildPaymentPane(CartController cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Payment Tabs Selector
        Row(
          children: [
            // Tab 1: NFC
            Expanded(
              child: _buildTabButton(
                key: const Key('tab_tap_to_pay'),
                tab: PaymentMethodTab.nfc,
                icon: Icons.contactless_rounded,
                title: 'Tap to Pay (NFC)',
                subtitle: 'Tarjetas, Apple & Google Pay',
              ),
            ),
            const SizedBox(width: 12),
            // Tab 2: QR
            Expanded(
              child: _buildTabButton(
                key: const Key('tab_qr_pay'),
                tab: PaymentMethodTab.qr,
                icon: Icons.qr_code_2_rounded,
                title: 'Código QR Móvil',
                subtitle: 'Paga con tu celular',
              ),
            ),
            const SizedBox(width: 12),
            // Tab 3: Mostrador / Caja
            Expanded(
              child: _buildTabButton(
                key: const Key('tab_counter_pay'),
                tab: PaymentMethodTab.counter,
                icon: Icons.storefront_rounded,
                title: 'Pagar en Caja',
                subtitle: 'Efectivo o terminal',
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Active Tab Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildActiveTabContent(cart),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required Key key,
    required PaymentMethodTab tab,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedTab == tab;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: _isProcessing ? null : () => _onSelectTab(tab),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? brandPrimary : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? brandPrimary.withOpacity(0.12)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: isSelected ? brandPrimary : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? brandPrimary : darkText,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(CartController cart) {
    switch (_selectedTab) {
      case PaymentMethodTab.nfc:
        return ValueListenableBuilder<ReaderState>(
          valueListenable: _terminalService.stateNotifier,
          builder: (context, state, child) {
            return NfcRadarWidget(
              key: const Key('checkout_nfc_radar_widget'),
              quadrant: _quadrant,
              isWaitingForCard: state.isWaitingForCard,
              isCardDetected: state.isCardDetected,
              isProcessing: state.isProcessing || _isProcessing,
              isSimulated: state.isSimulated,
              onSimulateTap: _terminalService.simulateCardTap,
            );
          },
        );

      case PaymentMethodTab.qr:
        return QrPaymentWidget(
          key: const Key('checkout_qr_payment_widget'),
          totalAmount: cart.total,
          onPaymentCompleted: _handleQrPaymentCompleted,
          onReturnToNfc: () => _onSelectTab(PaymentMethodTab.nfc),
        );

      case PaymentMethodTab.counter:
        return _buildCounterPaymentCard();
    }
  }

  Widget _buildCounterPaymentCard() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED), // Warm orange
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 42,
                    color: brandPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pagar en Caja / Mostrador',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Generaremos tu pedido de inmediato y la comanda comenzará a prepararse en cocina. Podrás pagar en efectivo o tarjeta directamente al cajero con tu número de comanda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                key: const Key('confirm_counter_payment_button'),
                onPressed: _isProcessing ? null : _handleCounterCheckout,
                icon: const Icon(Icons.check_circle_rounded, size: 22),
                label: const Text('Confirmar y Pagar en Caja'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
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
