import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'kiosk_api_service.dart';

/// Connection status between the Kiosk app and the Stripe Terminal reader
enum TerminalConnectionStatus {
  uninitialized,
  initializing,
  discovering,
  connecting,
  connected,
  disconnected,
  error,
}

/// Payment lifecycle status when interacting with contactless NFC tap
enum PaymentProcessStatus {
  idle,
  waitingForCard,
  cardDetected,
  cardCollected,
  processing,
  success,
  failed,
  canceled,
}

/// Immutable state representation of the local Stripe Terminal reader
class ReaderState {
  final TerminalConnectionStatus connectionStatus;
  final PaymentProcessStatus paymentStatus;
  final String? readerId;
  final String? errorMessage;
  final String? errorCode;
  final bool isSimulated;
  final bool hasNfc;
  final String? lastPaymentIntentId;

  const ReaderState({
    this.connectionStatus = TerminalConnectionStatus.uninitialized,
    this.paymentStatus = PaymentProcessStatus.idle,
    this.readerId,
    this.errorMessage,
    this.errorCode,
    this.isSimulated = false,
    this.hasNfc = true,
    this.lastPaymentIntentId,
  });

  bool get isReadyToCollect =>
      connectionStatus == TerminalConnectionStatus.connected &&
      paymentStatus == PaymentProcessStatus.idle;

  bool get isWaitingForCard =>
      paymentStatus == PaymentProcessStatus.waitingForCard;

  bool get isCardDetected => paymentStatus == PaymentProcessStatus.cardDetected;

  bool get isProcessing => paymentStatus == PaymentProcessStatus.processing;

  bool get isSuccess => paymentStatus == PaymentProcessStatus.success;

  bool get isFailed => paymentStatus == PaymentProcessStatus.failed;

  bool get isCanceled => paymentStatus == PaymentProcessStatus.canceled;

  ReaderState copyWith({
    TerminalConnectionStatus? connectionStatus,
    PaymentProcessStatus? paymentStatus,
    String? readerId,
    String? errorMessage,
    String? errorCode,
    bool? isSimulated,
    bool? hasNfc,
    String? lastPaymentIntentId,
  }) {
    return ReaderState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      readerId: readerId ?? this.readerId,
      errorMessage: errorMessage,
      errorCode: errorCode,
      isSimulated: isSimulated ?? this.isSimulated,
      hasNfc: hasNfc ?? this.hasNfc,
      lastPaymentIntentId: lastPaymentIntentId ?? this.lastPaymentIntentId,
    );
  }

  @override
  String toString() {
    return 'ReaderState(connection: $connectionStatus, payment: $paymentStatus, isSimulated: $isSimulated, hasNfc: $hasNfc)';
  }
}

/// Result returned after collecting and processing a terminal payment
class TerminalPaymentResult {
  final bool success;
  final String? paymentIntentId;
  final String? errorMessage;
  final String? errorCode;
  final bool isSimulated;

  const TerminalPaymentResult({
    required this.success,
    this.paymentIntentId,
    this.errorMessage,
    this.errorCode,
    this.isSimulated = false,
  });

  @override
  String toString() {
    return 'TerminalPaymentResult(success: $success, pi: $paymentIntentId, isSimulated: $isSimulated, err: $errorMessage)';
  }
}

/// Service managing the lifecycle of Stripe Terminal Tap to Pay on Android.
/// Integrates with KioskApiService for backend ConnectionTokens, handles
/// native Kotlin MethodChannel events, and includes a complete, seamless
/// simulation mode for emulators, non-NFC tablets, and local development.
class StripeTerminalService {
  static const String channelName = 'com.elorigen.kiosk/stripe_terminal';

  final MethodChannel _channel;
  final KioskApiService _apiService;

  final ValueNotifier<ReaderState> _stateNotifier =
      ValueNotifier<ReaderState>(const ReaderState());

  final StreamController<void> _cardDetectedController =
      StreamController<void>.broadcast(sync: true);

  Completer<TerminalPaymentResult>? _activePaymentCompleter;

  // Simulation timers for fallback environments
  Timer? _simCardDetectTimer;
  Timer? _simCardCollectTimer;
  Timer? _simProcessTimer;
  Timer? _simSuccessTimer;

  StripeTerminalService({
    MethodChannel? channel,
    KioskApiService? apiService,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _apiService = apiService ?? KioskApiService() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  /// Reactive notifier for UI observation
  ValueListenable<ReaderState> get stateNotifier => _stateNotifier;

  /// Current snapshot value
  ReaderState get currentState => _stateNotifier.value;

  /// Stream firing when a card is touched against the NFC antenna (triggers chime)
  Stream<void> get onCardDetected => _cardDetectedController.stream;

  // ---------------------------------------------------------------------------
  // Terminal Hardware Support & Diagnostics
  // ---------------------------------------------------------------------------

  /// Checks hardware NFC capabilities and environment
  Future<Map<String, dynamic>> checkHardwareSupport() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final hwResult = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkHardwareSupport');
        if (hwResult != null) {
          final hasNfc = hwResult['hasNfc'] as bool? ?? true;
          final isEmulator = hwResult['isEmulator'] as bool? ?? false;
          return {
            'hasNfc': hasNfc,
            'isEmulator': isEmulator,
            'isSupported': hasNfc && !isEmulator,
          };
        }
      } catch (e) {
        return {
          'hasNfc': false,
          'isEmulator': false,
          'isSupported': false,
          'error': e.toString(),
        };
      }
    }
    return {
      'hasNfc': true,
      'isEmulator': true,
      'isSupported': true,
      'isSimulated': true,
    };
  }

  // ---------------------------------------------------------------------------
  // Terminal Initialization & Reader Setup
  // ---------------------------------------------------------------------------

  /// Initializes the Stripe Terminal instance and connects to the local mobile reader.
  /// If hardware does not have NFC, or on emulator, or if [forceSimulated] is true,
  /// smoothly enters simulation mode.
  Future<bool> initialize(
    String branchId, {
    bool forceSimulated = false,
    String? locationId,
  }) async {
    _stateNotifier.value = _stateNotifier.value.copyWith(
      connectionStatus: TerminalConnectionStatus.initializing,
      errorMessage: null,
      errorCode: null,
    );

    try {
      // 1. Fetch ConnectionToken from El Origen backend
      final tokenData = await _apiService.createConnectionToken(branchId);
      final secret = tokenData['secret'] as String? ?? '';

      if (kDebugMode) {
        print('StripeTerminalService: Retrieved ConnectionToken (length: ${secret.length})');
      }

      // 2. Query hardware support if on native Android
      bool hasNfc = true;
      bool isEmulator = false;

      if (!forceSimulated && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final hwResult = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkHardwareSupport');
          if (hwResult != null) {
            hasNfc = hwResult['hasNfc'] as bool? ?? true;
            isEmulator = hwResult['isEmulator'] as bool? ?? false;
          }
        } catch (_) {
          // Native channel not available in non-Android host/test
          hasNfc = false;
        }
      } else {
        hasNfc = !forceSimulated;
      }

      final shouldSimulate = forceSimulated || !hasNfc || isEmulator;

      // 3. Initialize Terminal native or simulated
      Map<dynamic, dynamic>? initResult;
      try {
        initResult = await _channel.invokeMethod<Map<dynamic, dynamic>>('initTerminal', {
          'locationId': locationId ?? 'loc_kiosk_branch_$branchId',
          'simulated': shouldSimulate,
        });
      } catch (e) {
        // Fallback to pure Dart simulation if native channel fails
        return _initializeDartSimulation(hasNfc: hasNfc);
      }

      final isSim = (initResult?['simulated'] as bool?) ?? shouldSimulate;
      _stateNotifier.value = _stateNotifier.value.copyWith(
        isSimulated: isSim,
        hasNfc: hasNfc,
        connectionStatus: TerminalConnectionStatus.discovering,
      );

      // 4. Discover local mobile reader
      final discoverResult = await _channel.invokeMethod<Map<dynamic, dynamic>>('discoverLocalMobileReader');
      final readerId = discoverResult?['readerId'] as String? ?? 'local_mobile_reader';

      _stateNotifier.value = _stateNotifier.value.copyWith(
        readerId: readerId,
        connectionStatus: TerminalConnectionStatus.connecting,
      );

      // 5. Connect local mobile reader
      await _channel.invokeMethod('connectLocalMobileReader', {
        'locationId': locationId ?? 'loc_kiosk_branch_$branchId',
      });

      _stateNotifier.value = _stateNotifier.value.copyWith(
        connectionStatus: TerminalConnectionStatus.connected,
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('StripeTerminalService: Native init failed ($e). Entering simulation mode.');
      }
      return _initializeDartSimulation(hasNfc: false);
    }
  }

  /// Pure Dart fallback simulation when native bridge is not reachable
  Future<bool> _initializeDartSimulation({bool hasNfc = false}) async {
    _stateNotifier.value = _stateNotifier.value.copyWith(
      isSimulated: true,
      hasNfc: hasNfc,
      connectionStatus: TerminalConnectionStatus.discovering,
      errorMessage: null,
      errorCode: null,
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    _stateNotifier.value = _stateNotifier.value.copyWith(
      readerId: 'simulated_dart_local_reader',
      connectionStatus: TerminalConnectionStatus.connecting,
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    _stateNotifier.value = _stateNotifier.value.copyWith(
      connectionStatus: TerminalConnectionStatus.connected,
    );

    return true;
  }

  // ---------------------------------------------------------------------------
  // Payment Collection & Processing
  // ---------------------------------------------------------------------------

  /// Collects payment via contactless card tap and processes the payment intent.
  /// Returns [TerminalPaymentResult] with success status and Stripe paymentIntentId.
  Future<TerminalPaymentResult> collectAndProcessPayment({
    required String clientSecret,
    required double amount,
  }) async {
    _cancelSimulationTimers();

    _stateNotifier.value = _stateNotifier.value.copyWith(
      paymentStatus: PaymentProcessStatus.waitingForCard,
      errorMessage: null,
      errorCode: null,
      lastPaymentIntentId: _extractPaymentIntentId(clientSecret),
    );

    final completer = Completer<TerminalPaymentResult>();
    _activePaymentCompleter = completer;

    // If in simulated mode or outside native Android, run smooth timed simulation
    if (_stateNotifier.value.isSimulated ||
        defaultTargetPlatform != TargetPlatform.android) {
      _startDartPaymentSimulation(clientSecret);
      return completer.future;
    }

    // Native Android execution
    try {
      final collectResult = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'collectPaymentMethod',
        {'clientSecret': clientSecret},
      );

      if (collectResult?['simulated'] == true) {
        // Native side is running simulation
        return completer.future;
      }

      // If native collect returned synchronously or awaits processPayment
      final processResult = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'processPayment',
      );

      final piId = processResult?['paymentIntentId'] as String? ??
          _extractPaymentIntentId(clientSecret);

      _stateNotifier.value = _stateNotifier.value.copyWith(
        paymentStatus: PaymentProcessStatus.success,
        lastPaymentIntentId: piId,
      );

      final result = TerminalPaymentResult(
        success: true,
        paymentIntentId: piId,
        isSimulated: false,
      );

      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('StripeTerminalService: Native payment error: $e');
      }
      _stateNotifier.value = _stateNotifier.value.copyWith(
        paymentStatus: PaymentProcessStatus.failed,
        errorMessage: e.toString(),
        errorCode: 'PAYMENT_FAILED',
      );

      final result = TerminalPaymentResult(
        success: false,
        errorMessage: e.toString(),
        errorCode: 'PAYMENT_FAILED',
        isSimulated: false,
      );

      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
    }
  }

  /// Cancels any in-flight card reading or payment process
  Future<void> cancelPayment() async {
    _cancelSimulationTimers();

    try {
      await _channel.invokeMethod('cancelPayment');
    } catch (_) {
      // Ignored in simulated/host mode
    }

    _stateNotifier.value = _stateNotifier.value.copyWith(
      paymentStatus: PaymentProcessStatus.canceled,
    );

    if (_activePaymentCompleter != null &&
        !_activePaymentCompleter!.isCompleted) {
      _activePaymentCompleter!.complete(
        const TerminalPaymentResult(
          success: false,
          errorMessage: 'Operación cancelada por el usuario',
          errorCode: 'CANCELED',
        ),
      );
    }
  }

  /// Developer / testing helper to trigger an immediate simulated card tap
  void simulateCardTap() {
    if (_stateNotifier.value.paymentStatus !=
        PaymentProcessStatus.waitingForCard) {
      return;
    }

    _cancelSimulationTimers();

    _cardDetectedController.add(null);
    _stateNotifier.value = _stateNotifier.value.copyWith(
      paymentStatus: PaymentProcessStatus.cardDetected,
    );

    _simCardCollectTimer = Timer(const Duration(milliseconds: 50), () {
      _stateNotifier.value = _stateNotifier.value.copyWith(
        paymentStatus: PaymentProcessStatus.cardCollected,
      );

      _simProcessTimer = Timer(const Duration(milliseconds: 50), () {
        _stateNotifier.value = _stateNotifier.value.copyWith(
          paymentStatus: PaymentProcessStatus.processing,
        );

        _simSuccessTimer = Timer(const Duration(milliseconds: 50), () {
          final piId = _stateNotifier.value.lastPaymentIntentId ??
              'pi_simulated_${DateTime.now().millisecondsSinceEpoch}';

          _stateNotifier.value = _stateNotifier.value.copyWith(
            paymentStatus: PaymentProcessStatus.success,
            lastPaymentIntentId: piId,
          );

          if (_activePaymentCompleter != null &&
              !_activePaymentCompleter!.isCompleted) {
            _activePaymentCompleter!.complete(
              TerminalPaymentResult(
                success: true,
                paymentIntentId: piId,
                isSimulated: true,
              ),
            );
          }
        });
      });
    });
  }

  /// Resets payment state back to idle for the next checkout attempt
  void resetPaymentState() {
    _cancelSimulationTimers();
    _stateNotifier.value = _stateNotifier.value.copyWith(
      paymentStatus: PaymentProcessStatus.idle,
      errorMessage: null,
      errorCode: null,
    );
  }

  // ---------------------------------------------------------------------------
  // Simulation Internals
  // ---------------------------------------------------------------------------

  void _startDartPaymentSimulation(String clientSecret) {
    // 1. Wait 1500ms before card touches NFC
    _simCardDetectTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_stateNotifier.value.paymentStatus !=
          PaymentProcessStatus.waitingForCard) {
        return;
      }

      _cardDetectedController.add(null);
      _stateNotifier.value = _stateNotifier.value.copyWith(
        paymentStatus: PaymentProcessStatus.cardDetected,
      );

      // 2. Wait 800ms to collect card data
      _simCardCollectTimer = Timer(const Duration(milliseconds: 800), () {
        _stateNotifier.value = _stateNotifier.value.copyWith(
          paymentStatus: PaymentProcessStatus.cardCollected,
        );

        // 3. Wait 600ms to begin processing
        _simProcessTimer = Timer(const Duration(milliseconds: 600), () {
          _stateNotifier.value = _stateNotifier.value.copyWith(
            paymentStatus: PaymentProcessStatus.processing,
          );

          // 4. Wait 1200ms for Stripe authorization success
          _simSuccessTimer = Timer(const Duration(milliseconds: 1200), () {
            final piId = _stateNotifier.value.lastPaymentIntentId ??
                _extractPaymentIntentId(clientSecret);

            _stateNotifier.value = _stateNotifier.value.copyWith(
              paymentStatus: PaymentProcessStatus.success,
              lastPaymentIntentId: piId,
            );

            if (_activePaymentCompleter != null &&
                !_activePaymentCompleter!.isCompleted) {
              _activePaymentCompleter!.complete(
                TerminalPaymentResult(
                  success: true,
                  paymentIntentId: piId,
                  isSimulated: true,
                ),
              );
            }
          });
        });
      });
    });
  }

  void _cancelSimulationTimers() {
    _simCardDetectTimer?.cancel();
    _simCardCollectTimer?.cancel();
    _simProcessTimer?.cancel();
    _simSuccessTimer?.cancel();
    _simCardDetectTimer = null;
    _simCardCollectTimer = null;
    _simProcessTimer = null;
    _simSuccessTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Native MethodChannel Callbacks Handler
  // ---------------------------------------------------------------------------

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onReaderStatusChanged':
        final statusStr = call.arguments?['status'] as String? ?? '';
        _updateConnectionStatusFromNative(statusStr);
        break;

      case 'onPaymentStatusChanged':
        final statusStr = call.arguments?['status'] as String? ?? '';
        _updatePaymentStatusFromNative(statusStr);
        break;

      case 'onCardDetected':
        _cardDetectedController.add(null);
        _stateNotifier.value = _stateNotifier.value.copyWith(
          paymentStatus: PaymentProcessStatus.cardDetected,
        );
        break;

      case 'onError':
        final code = call.arguments?['code'] as String? ?? 'UNKNOWN';
        final msg =
            call.arguments?['message'] as String? ?? 'Error de terminal Stripe';
        _handleNativeError(code, msg);
        break;
    }
  }

  void _updateConnectionStatusFromNative(String status) {
    TerminalConnectionStatus connStatus;
    switch (status) {
      case 'INITIALIZED':
        connStatus = TerminalConnectionStatus.discovering;
        break;
      case 'DISCOVERING':
        connStatus = TerminalConnectionStatus.discovering;
        break;
      case 'READER_FOUND':
        connStatus = TerminalConnectionStatus.connecting;
        break;
      case 'CONNECTING':
        connStatus = TerminalConnectionStatus.connecting;
        break;
      case 'CONNECTED':
        connStatus = TerminalConnectionStatus.connected;
        break;
      case 'DISCONNECTED':
        connStatus = TerminalConnectionStatus.disconnected;
        break;
      default:
        connStatus = _stateNotifier.value.connectionStatus;
    }

    _stateNotifier.value = _stateNotifier.value.copyWith(
      connectionStatus: connStatus,
    );
  }

  void _updatePaymentStatusFromNative(String status) {
    PaymentProcessStatus pStatus;
    switch (status) {
      case 'WAITING_FOR_CARD':
        pStatus = PaymentProcessStatus.waitingForCard;
        break;
      case 'CARD_DETECTED':
        pStatus = PaymentProcessStatus.cardDetected;
        break;
      case 'CARD_COLLECTED':
        pStatus = PaymentProcessStatus.cardCollected;
        break;
      case 'PROCESSING':
        pStatus = PaymentProcessStatus.processing;
        break;
      case 'SUCCESS':
        pStatus = PaymentProcessStatus.success;
        if (_activePaymentCompleter != null &&
            !_activePaymentCompleter!.isCompleted) {
          _activePaymentCompleter!.complete(
            TerminalPaymentResult(
              success: true,
              paymentIntentId: _stateNotifier.value.lastPaymentIntentId,
              isSimulated: _stateNotifier.value.isSimulated,
            ),
          );
        }
        break;
      case 'CANCELED':
        pStatus = PaymentProcessStatus.canceled;
        if (_activePaymentCompleter != null &&
            !_activePaymentCompleter!.isCompleted) {
          _activePaymentCompleter!.complete(
            const TerminalPaymentResult(
              success: false,
              errorMessage: 'Pago cancelado',
              errorCode: 'CANCELED',
            ),
          );
        }
        break;
      default:
        pStatus = _stateNotifier.value.paymentStatus;
    }

    _stateNotifier.value = _stateNotifier.value.copyWith(
      paymentStatus: pStatus,
    );
  }

  void _handleNativeError(String code, String message) {
    _stateNotifier.value = _stateNotifier.value.copyWith(
      paymentStatus: PaymentProcessStatus.failed,
      errorMessage: message,
      errorCode: code,
    );

    if (_activePaymentCompleter != null &&
        !_activePaymentCompleter!.isCompleted) {
      _activePaymentCompleter!.complete(
        TerminalPaymentResult(
          success: false,
          errorMessage: message,
          errorCode: code,
          isSimulated: _stateNotifier.value.isSimulated,
        ),
      );
    }
  }

  String _extractPaymentIntentId(String clientSecret) {
    if (clientSecret.contains('_secret_')) {
      return clientSecret.split('_secret_').first;
    }
    return clientSecret;
  }

  /// Clean teardown of listeners, streams, and timers
  void dispose() {
    _cancelSimulationTimers();
    _channel.setMethodCallHandler(null);
    _cardDetectedController.close();
    _stateNotifier.dispose();
  }
}
