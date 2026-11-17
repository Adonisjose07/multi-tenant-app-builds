import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:elorigen_kiosk/services/stripe_terminal_service.dart';
import 'package:elorigen_kiosk/services/kiosk_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderState Model & Logic', () {
    test('default ReaderState has uninitialized and idle status', () {
      const state = ReaderState();
      expect(state.connectionStatus, TerminalConnectionStatus.uninitialized);
      expect(state.paymentStatus, PaymentProcessStatus.idle);
      expect(state.isSimulated, isFalse);
      expect(state.hasNfc, isTrue);
      expect(state.isReadyToCollect, isFalse);
      expect(state.isWaitingForCard, isFalse);
    });

    test('ReaderState getters accurately reflect payment lifecycle', () {
      var state = const ReaderState(
        connectionStatus: TerminalConnectionStatus.connected,
        paymentStatus: PaymentProcessStatus.idle,
      );
      expect(state.isReadyToCollect, isTrue);

      state = state.copyWith(paymentStatus: PaymentProcessStatus.waitingForCard);
      expect(state.isWaitingForCard, isTrue);
      expect(state.isReadyToCollect, isFalse);

      state = state.copyWith(paymentStatus: PaymentProcessStatus.cardDetected);
      expect(state.isCardDetected, isTrue);

      state = state.copyWith(paymentStatus: PaymentProcessStatus.processing);
      expect(state.isProcessing, isTrue);

      state = state.copyWith(paymentStatus: PaymentProcessStatus.success);
      expect(state.isSuccess, isTrue);

      state = state.copyWith(paymentStatus: PaymentProcessStatus.failed);
      expect(state.isFailed, isTrue);

      state = state.copyWith(paymentStatus: PaymentProcessStatus.canceled);
      expect(state.isCanceled, isTrue);
    });

    test('ReaderState copyWith updates fields correctly', () {
      const initial = ReaderState(
        connectionStatus: TerminalConnectionStatus.uninitialized,
        isSimulated: false,
      );

      final updated = initial.copyWith(
        connectionStatus: TerminalConnectionStatus.connected,
        readerId: 'reader_nfc_01',
        isSimulated: true,
        errorMessage: 'Some error',
        errorCode: 'ERR_01',
      );

      expect(updated.connectionStatus, TerminalConnectionStatus.connected);
      expect(updated.readerId, 'reader_nfc_01');
      expect(updated.isSimulated, isTrue);
      expect(updated.errorMessage, 'Some error');
      expect(updated.errorCode, 'ERR_01');
    });
  });

  group('TerminalPaymentResult Model', () {
    test('creates successful and failed payment results', () {
      const successResult = TerminalPaymentResult(
        success: true,
        paymentIntentId: 'pi_123456789',
        isSimulated: true,
      );
      expect(successResult.success, isTrue);
      expect(successResult.paymentIntentId, 'pi_123456789');
      expect(successResult.isSimulated, isTrue);

      const failResult = TerminalPaymentResult(
        success: false,
        errorMessage: 'Card declined by issuing bank',
        errorCode: 'CARD_DECLINED',
      );
      expect(failResult.success, isFalse);
      expect(failResult.errorMessage, 'Card declined by issuing bank');
      expect(failResult.errorCode, 'CARD_DECLINED');
    });
  });

  group('StripeTerminalService Simulation & Lifecycle', () {
    late StripeTerminalService terminalService;

    setUp(() {
      terminalService = StripeTerminalService(
        apiService: KioskApiService(),
      );
    });

    tearDown(() {
      terminalService.dispose();
    });

    test('initial state is uninitialized', () {
      expect(
        terminalService.currentState.connectionStatus,
        TerminalConnectionStatus.uninitialized,
      );
      expect(terminalService.currentState.isSimulated, isFalse);
    });

    test('initialize with forceSimulated connects successfully', () async {
      final success = await terminalService.initialize(
        'branch_test_001',
        forceSimulated: true,
      );

      expect(success, isTrue);
      expect(terminalService.currentState.isSimulated, isTrue);
      expect(
        terminalService.currentState.connectionStatus,
        TerminalConnectionStatus.connected,
      );
      expect(terminalService.currentState.isReadyToCollect, isTrue);
    });

    test('collectAndProcessPayment with simulateCardTap completes payment', () async {
      await terminalService.initialize('branch_test_001', forceSimulated: true);

      bool cardChimeFired = false;
      terminalService.onCardDetected.listen((_) {
        cardChimeFired = true;
      });

      // Start payment collection
      final paymentFuture = terminalService.collectAndProcessPayment(
        clientSecret: 'pi_test_kiosk_9988_secret_abc',
        amount: 19.99,
      );

      expect(terminalService.currentState.isWaitingForCard, isTrue);

      // Trigger immediate developer card tap
      terminalService.simulateCardTap();

      expect(cardChimeFired, isTrue);
      expect(terminalService.currentState.isCardDetected, isTrue);

      // Await final result
      final result = await paymentFuture;
      expect(result.success, isTrue);
      expect(result.paymentIntentId, 'pi_test_kiosk_9988');
      expect(terminalService.currentState.isSuccess, isTrue);
    });

    test('cancelPayment interrupts waiting flow and sets canceled state', () async {
      await terminalService.initialize('branch_test_001', forceSimulated: true);

      final paymentFuture = terminalService.collectAndProcessPayment(
        clientSecret: 'pi_test_kiosk_1122_secret_xyz',
        amount: 45.00,
      );

      expect(terminalService.currentState.isWaitingForCard, isTrue);

      await terminalService.cancelPayment();

      expect(terminalService.currentState.isCanceled, isTrue);
      final result = await paymentFuture;
      expect(result.success, isFalse);
      expect(result.errorCode, 'CANCELED');
    });

    test('resetPaymentState clears errors and returns to idle', () async {
      await terminalService.initialize('branch_test_001', forceSimulated: true);

      await terminalService.collectAndProcessPayment(
        clientSecret: 'pi_test_kiosk_3344_secret_def',
        amount: 15.50,
      );

      await terminalService.cancelPayment();
      expect(terminalService.currentState.paymentStatus, PaymentProcessStatus.canceled);

      terminalService.resetPaymentState();
      expect(terminalService.currentState.paymentStatus, PaymentProcessStatus.idle);
      expect(terminalService.currentState.errorMessage, isNull);
    });
  });

  group('KioskApiService Stripe Terminal GraphQL Integration', () {
    test('createConnectionToken returns valid token structure', () async {
      final api = KioskApiService();
      final token = await api.createConnectionToken('branch_mock_001');

      expect(token['secret'], isNotNull);
      expect(token['secret'], isNotEmpty);
      expect(token['publishableKey'], isNotNull);
    });

    test('createPaymentIntent returns valid payment intent structure', () async {
      final api = KioskApiService();
      final pi = await api.createPaymentIntent(
        branchId: 'branch_mock_001',
        amount: 28.50,
      );

      expect(pi['id'], isNotNull);
      expect(pi['clientSecret'], contains('secret'));
      expect(pi['publishableKey'], isNotNull);
    });

    test('createKioskOrder returns mock order structure on offline demo', () async {
      final api = KioskApiService();
      final res = await api.createKioskOrder({
        'branchId': 'branch_mock_001',
        'customerName': 'Carlos Gomez',
        'customerPhone': '+13125550199',
        'deliveryType': 'dine_in',
        'paymentMethod': 'CARD',
        'items': [],
      });

      expect(res['success'], isTrue);
      expect(res['order']['id'], isNotNull);
      expect(res['order']['orderNumber'], isNotNull);
    });
  });
}
