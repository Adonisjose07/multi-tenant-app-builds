import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elorigen_kiosk/controllers/cart_controller.dart';
import 'package:elorigen_kiosk/controllers/kiosk_session_controller.dart';
import 'package:elorigen_kiosk/models/kiosk_session.dart';
import 'package:elorigen_kiosk/models/nfc_quadrant.dart';
import 'package:elorigen_kiosk/models/store_product.dart';
import 'package:elorigen_kiosk/screens/checkout_screen.dart';
import 'package:elorigen_kiosk/services/kiosk_api_service.dart';
import 'package:elorigen_kiosk/services/sound_service.dart';
import 'package:elorigen_kiosk/services/stripe_terminal_service.dart';
import 'package:elorigen_kiosk/widgets/nfc_error_dialog.dart';
import 'package:elorigen_kiosk/widgets/nfc_radar_widget.dart';
import 'package:elorigen_kiosk/widgets/qr_payment_widget.dart';
import 'package:elorigen_kiosk/widgets/tip_selector_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NfcQuadrant Enum & Extensions', () {
    test('NfcQuadrant has all 5 hardware antenna positions', () {
      expect(NfcQuadrant.values.length, 5);
      expect(NfcQuadrant.values, contains(NfcQuadrant.topRight));
      expect(NfcQuadrant.values, contains(NfcQuadrant.topLeft));
      expect(NfcQuadrant.values, contains(NfcQuadrant.topCenter));
      expect(NfcQuadrant.values, contains(NfcQuadrant.screenCenter));
      expect(NfcQuadrant.values, contains(NfcQuadrant.externalReader));
    });

    test('NfcQuadrant alignments match physical tablet regions', () {
      expect(NfcQuadrant.topRight.alignment, const Alignment(0.80, -0.80));
      expect(NfcQuadrant.topLeft.alignment, const Alignment(-0.80, -0.80));
      expect(NfcQuadrant.topCenter.alignment, const Alignment(0.0, -0.85));
      expect(NfcQuadrant.screenCenter.alignment, Alignment.center);
      expect(NfcQuadrant.externalReader.alignment, const Alignment(0.90, 0.0));
    });

    test('NfcQuadrant instructions and arrow emoji indicators', () {
      expect(NfcQuadrant.topRight.instructions, contains('↗️'));
      expect(NfcQuadrant.topLeft.instructions, contains('↖️'));
      expect(NfcQuadrant.topCenter.instructions, contains('⬆️'));
      expect(NfcQuadrant.screenCenter.instructions, contains('🎯'));
      expect(NfcQuadrant.externalReader.instructions, contains('💳'));
    });

    test('NfcQuadrant fromString safely parses and falls back to topRight', () {
      expect(NfcQuadrantExtension.fromString('topRight'), NfcQuadrant.topRight);
      expect(NfcQuadrantExtension.fromString('TOPLEFT'), NfcQuadrant.topLeft);
      expect(NfcQuadrantExtension.fromString('top_center'), NfcQuadrant.topCenter);
      expect(NfcQuadrantExtension.fromString('screenCenter'), NfcQuadrant.screenCenter);
      expect(NfcQuadrantExtension.fromString('external_reader'), NfcQuadrant.externalReader);
      expect(NfcQuadrantExtension.fromString('unknown_val'), NfcQuadrant.topRight);
      expect(NfcQuadrantExtension.fromString(null), NfcQuadrant.topRight);
      expect(NfcQuadrantExtension.fromString(''), NfcQuadrant.topRight);
    });
  });

  group('SoundService Unit Tests', () {
    test('SoundService invokes custom player for all sound types', () async {
      final playedSounds = <KioskSoundType>[];
      final soundService = SoundService(
        customPlayer: (type) async {
          playedSounds.add(type);
        },
      );

      await soundService.playCardDetected();
      await soundService.playPaymentSuccess();
      await soundService.playError();
      await soundService.playClick();

      expect(playedSounds, [
        KioskSoundType.cardDetected,
        KioskSoundType.paymentSuccess,
        KioskSoundType.error,
        KioskSoundType.click,
      ]);
    });

    test('SoundService respects isEnabled mute toggle', () async {
      final playedSounds = <KioskSoundType>[];
      final soundService = SoundService(
        customPlayer: (type) async {
          playedSounds.add(type);
        },
      );

      soundService.isEnabled = false;
      await soundService.playCardDetected();
      await soundService.playPaymentSuccess();

      expect(playedSounds, isEmpty);
    });
  });

  group('Tip Calculations & TipSelectorWidget', () {
    test('Tip percentage calculations on cart subtotal', () {
      const subtotal = 40.0;
      final tip10 = subtotal * 0.10;
      final tip15 = subtotal * 0.15;
      final tip20 = subtotal * 0.20;

      expect(tip10, 4.00);
      expect(tip15, 6.00);
      expect(tip20, 8.00);
    });

    testWidgets('TipSelectorWidget displays chips and notifies on selection',
        (tester) async {
      double selectedTip = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TipSelectorWidget(
              subtotal: 50.0,
              currentTip: 0.0,
              onTipSelected: (tip) {
                selectedTip = tip;
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('tip_chip_10')), findsOneWidget);
      expect(find.byKey(const Key('tip_chip_15')), findsOneWidget);
      expect(find.byKey(const Key('tip_chip_20')), findsOneWidget);
      expect(find.byKey(const Key('tip_chip_custom')), findsOneWidget);
      expect(find.byKey(const Key('tip_chip_none')), findsOneWidget);

      // Select 15% ($7.50 on $50.00 subtotal)
      await tester.tap(find.byKey(const Key('tip_chip_15')));
      await tester.pumpAndSettle();
      expect(selectedTip, 7.50);

      // Select 10% ($5.00)
      await tester.tap(find.byKey(const Key('tip_chip_10')));
      await tester.pumpAndSettle();
      expect(selectedTip, 5.00);

      // Select Sin Propina ($0.00)
      await tester.tap(find.byKey(const Key('tip_chip_none')));
      await tester.pumpAndSettle();
      expect(selectedTip, 0.0);
    });
  });

  group('NfcRadarWidget & Quadrant Positioning', () {
    testWidgets('NfcRadarWidget renders dynamic quadrant instructions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: NfcRadarWidget(
                quadrant: NfcQuadrant.topLeft,
                isWaitingForCard: true,
                isSimulated: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text(NfcQuadrant.topLeft.instructions), findsOneWidget);
      expect(find.byIcon(Icons.contactless_rounded), findsOneWidget);
    });

    testWidgets('NfcRadarWidget displays simulation button when isSimulated is true',
        (tester) async {
      bool simulatedTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 500,
              child: NfcRadarWidget(
                quadrant: NfcQuadrant.topRight,
                isWaitingForCard: true,
                isSimulated: true,
                onSimulateTap: () {
                  simulatedTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      final simButtonFinder = find.byKey(const Key('simulate_nfc_tap_button'));
      expect(simButtonFinder, findsOneWidget);

      await tester.tap(simButtonFinder);
      await tester.pump();
      expect(simulatedTapped, isTrue);
    });
  });

  group('QrPaymentWidget Tests', () {
    testWidgets('QrPaymentWidget renders amount and handles confirmation',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      bool qrCompleted = false;
      bool returnedToNfc = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: QrPaymentWidget(
                totalAmount: 27.50,
                onPaymentCompleted: () {
                  qrCompleted = true;
                },
                onReturnToNfc: () {
                  returnedToNfc = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('\$27.50'), findsOneWidget);
      expect(find.text('Escanea con la cámara de tu celular'), findsOneWidget);

      // Confirm QR payment
      await tester.tap(find.byKey(const Key('confirm_qr_payment_button')));
      await tester.pump();
      expect(qrCompleted, isTrue);

      // Return to NFC
      await tester.tap(find.byKey(const Key('return_to_nfc_button')));
      await tester.pump();
      expect(returnedToNfc, isTrue);
    });
  });

  group('NfcErrorDialog & 1-Click Fallbacks', () {
    testWidgets('NfcErrorDialog shows 3 fallback action buttons',
        (tester) async {
      bool retried = false;
      bool paidWithQr = false;
      bool paidAtCounter = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NfcErrorDialog(
              errorMessage: 'Chip contactless no detectado.',
              onRetry: () => retried = true,
              onPayWithQr: () => paidWithQr = true,
              onPayAtCounter: () => paidAtCounter = true,
            ),
          ),
        ),
      );

      expect(find.text('No pudimos leer tu tarjeta'), findsOneWidget);
      expect(find.text('Chip contactless no detectado.'), findsOneWidget);

      // Verify all 3 fallback buttons exist
      expect(find.byKey(const Key('nfc_dialog_retry_button')), findsOneWidget);
      expect(find.byKey(const Key('nfc_dialog_qr_button')), findsOneWidget);
      expect(find.byKey(const Key('nfc_dialog_counter_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('nfc_dialog_retry_button')));
      expect(retried, isTrue);

      await tester.tap(find.byKey(const Key('nfc_dialog_qr_button')));
      expect(paidWithQr, isTrue);

      await tester.tap(find.byKey(const Key('nfc_dialog_counter_button')));
      expect(paidAtCounter, isTrue);
    });
  });

  group('CheckoutScreen Integration & Payment Transitions', () {
    late KioskSessionController sessionController;
    late CartController cartController;
    late StripeTerminalService terminalService;
    late KioskApiService apiService;

    const testBurger = StoreProduct(
      id: 'prod_test_burger',
      name: 'Hamburguesa Kiosk Test',
      description: 'Deliciosa hamburguesa de prueba',
      price: 15.00,
      categoryId: 'cat_burgers',
    );

    setUp(() {
      sessionController = KioskSessionController();
      sessionController.setPhone('8095551234');
      sessionController.setDiningMode(DiningMode.dineIn);
      sessionController.setTableOrPagerNumber('14');

      cartController = CartController();
      cartController.addItem(testBurger, [], quantity: 2); // 2 x 15.00 = 30.00

      apiService = KioskApiService();
      terminalService = StripeTerminalService(apiService: apiService);
    });

    tearDown(() {
      sessionController.stopInactivityTimer();
      sessionController.dispose();
      terminalService.dispose();
    });

    testWidgets('CheckoutScreen renders order review and payment tabs',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: CheckoutScreen(
            sessionController: sessionController,
            cartController: cartController,
            terminalService: terminalService,
            apiService: apiService,
            initialQuadrant: NfcQuadrant.topRight,
          ),
        ),
      );
      await tester.pump();

      // Order review items & total
      expect(find.text('Revisión y Pago de la Orden'), findsOneWidget);
      expect(find.text('Hamburguesa Kiosk Test'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.byKey(const Key('checkout_formatted_total')), findsOneWidget);

      // Payment method tabs
      expect(find.byKey(const Key('tab_tap_to_pay')), findsOneWidget);
      expect(find.byKey(const Key('tab_qr_pay')), findsOneWidget);
      expect(find.byKey(const Key('tab_counter_pay')), findsOneWidget);
    });

    testWidgets('CheckoutScreen allows switching to QR and Counter tabs',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: CheckoutScreen(
            sessionController: sessionController,
            cartController: cartController,
            terminalService: terminalService,
            apiService: apiService,
          ),
        ),
      );
      await tester.pump();

      // Switch to QR tab
      await tester.tap(find.byKey(const Key('tab_qr_pay')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout_qr_payment_widget')), findsOneWidget);

      // Switch to Counter tab
      await tester.tap(find.byKey(const Key('tab_counter_pay')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm_counter_payment_button')), findsOneWidget);
      expect(find.text('Pagar en Caja / Mostrador'), findsOneWidget);

      // Switch back to Tap to Pay
      await tester.tap(find.byKey(const Key('tab_tap_to_pay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('checkout_nfc_radar_widget')), findsOneWidget);

      sessionController.stopInactivityTimer();
    });
  });
}
