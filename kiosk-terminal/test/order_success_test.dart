import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:elorigen_kiosk/controllers/cart_controller.dart';
import 'package:elorigen_kiosk/controllers/kiosk_session_controller.dart';
import 'package:elorigen_kiosk/models/kiosk_session.dart';
import 'package:elorigen_kiosk/models/store_product.dart';
import 'package:elorigen_kiosk/screens/order_success_screen.dart';
import 'package:elorigen_kiosk/services/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrderSuccessScreen - Order Details & Chips', () {
    late KioskSessionController sessionController;
    late CartController cartController;

    setUp(() {
      sessionController = KioskSessionController();
      cartController = CartController();
    });

    testWidgets('renders extra-large order number and paid status badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final orderData = {
        'id': 'ord_123456',
        'orderNumber': 42,
        'orderCode': '#42',
        'status': 'PENDING',
        'paymentStatus': 'PAID',
        'paymentMethod': 'CARD',
        'totalPrice': 35.50,
        'deliveryType': 'dine_in',
        'tableNumber': '12',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OrderSuccessScreen(
            order: orderData,
            sessionController: sessionController,
            cartController: cartController,
            initialCountdownSeconds: 60,
          ),
        ),
      );
      await tester.pump();

      // Check extra-large order number
      expect(find.byKey(const Key('order_success_order_number')), findsOneWidget);
      expect(find.text('#42'), findsOneWidget);

      // Check dining mode chip
      expect(find.byKey(const Key('order_success_dining_mode_chip')),
          findsOneWidget);
      expect(find.text('🍽️ COMER AQUÍ'), findsOneWidget);

      // Check table / pager number chip
      expect(find.byKey(const Key('order_success_table_pager_chip')),
          findsOneWidget);
      expect(find.text('Mesa / Localizador: #12'), findsOneWidget);

      // Check paid status badge
      expect(find.byKey(const Key('order_success_paid_badge')), findsOneWidget);
      expect(find.text('Pago completado con éxito'), findsOneWidget);
      expect(find.byKey(const Key('order_success_pending_badge')), findsNothing);

      // Check total price
      expect(find.byKey(const Key('order_success_total_amount')), findsOneWidget);
      expect(find.text('\$35.50'), findsOneWidget);

      // Clean up timer
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('renders pending payment warning chip when payment is at counter', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final orderData = {
        'id': 'ord_counter_99',
        'orderNumber': 99,
        'orderCode': '#99',
        'status': 'PENDING',
        'paymentStatus': 'PENDING',
        'paymentMethod': 'COUNTER',
        'totalPrice': 18.25,
        'deliveryType': 'takeaway',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OrderSuccessScreen(
            order: orderData,
            sessionController: sessionController,
            cartController: cartController,
            initialCountdownSeconds: 60,
          ),
        ),
      );
      await tester.pump();

      // Check order number
      expect(find.text('#99'), findsOneWidget);

      // Check takeaway chip
      expect(find.text('🛍️ PARA LLEVAR'), findsOneWidget);
      expect(find.byKey(const Key('order_success_table_pager_chip')), findsNothing);

      // Check pending banner
      expect(
          find.byKey(const Key('order_success_pending_badge')), findsOneWidget);
      expect(
          find.text(
              '⚠️ PAGO PENDIENTE EN CAJA - Pasa a mostrador con tu ticket para abonar'),
          findsOneWidget);
      expect(find.byKey(const Key('order_success_paid_badge')), findsNothing);

      // Clean up timer
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('OrderSuccessScreen - Dynamic QR Code & Tracking', () {
    testWidgets('renders QrImageView with exact tracking URL and instructional prompt', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final orderData = {
        'id': 'ord_alpha_789',
        'orderNumber': 105,
        'orderCode': '#105',
        'paymentStatus': 'PAID',
        'deliveryType': 'dine_in',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OrderSuccessScreen(
            order: orderData,
            trackingBaseUrl: 'https://apimono.elorigen.restaurant/order',
            initialCountdownSeconds: 60,
          ),
        ),
      );
      await tester.pump();

      // Check prompt specified in Task 9 brief
      expect(
        find.text(
            'Escanea con tu celular para ver el estado de tu pedido en vivo desde tu mesa'),
        findsOneWidget,
      );

      // Check QrImageView widget
      final qrFinder = find.byKey(const Key('order_tracking_qr_code'));
      expect(qrFinder, findsOneWidget);


      // Check tracking URL caption
      expect(
        find.text('https://apimono.elorigen.restaurant/order/ord_alpha_789'),
        findsOneWidget,
      );

      // Clean up timer
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('OrderSuccessScreen - Inactivity Countdown & 10s Warning Dialog', () {
    testWidgets('shows warning dialog at 10s remaining with extend and exit options', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      bool finishedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OrderSuccessScreen(
            order: const {
              'id': 'ord_countdown_test',
              'orderNumber': 10,
              'paymentStatus': 'PAID',
            },
            initialCountdownSeconds: 12,
            warningThresholdSeconds: 10,
            onFinished: () => finishedCalled = true,
          ),
        ),
      );
      await tester.pump();

      // Initially at 12s, no dialog
      expect(find.byKey(const Key('order_success_warning_dialog')), findsNothing);
      expect(find.text('Cerrando en 12s'), findsOneWidget);

      // Tick 2 seconds to reach 10s
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Cerrando en 10s'), findsOneWidget);

      // Warning dialog appears at 10s
      expect(find.byKey(const Key('order_success_warning_dialog')), findsOneWidget);
      expect(find.text('¿Necesitas más tiempo?'), findsOneWidget);
      expect(find.byKey(const Key('order_success_extend_time_button')),
          findsOneWidget);
      expect(find.byKey(const Key('order_success_exit_now_button')),
          findsOneWidget);

      // Tap +30 Segundos
      await tester.tap(find.byKey(const Key('order_success_extend_time_button')));
      await tester.pumpAndSettle();

      // Dialog is dismissed and countdown is extended by 30s (10 + 30 = 40s)
      expect(find.byKey(const Key('order_success_warning_dialog')), findsNothing);
      expect(find.text('Cerrando en 40s'), findsOneWidget);
      expect(finishedCalled, isFalse);

      // Clean up timer
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tapping Salir Ahora in warning dialog immediately completes session', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      bool finishedCalled = false;
      final sessionController = KioskSessionController();
      sessionController.setPhone('8095554321');

      await tester.pumpWidget(
        MaterialApp(
          home: OrderSuccessScreen(
            order: const {
              'id': 'ord_exit_test',
              'orderNumber': 22,
              'paymentStatus': 'PAID',
            },
            sessionController: sessionController,
            initialCountdownSeconds: 10,
            warningThresholdSeconds: 10,
            onFinished: () => finishedCalled = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Dialog is displayed
      expect(find.byKey(const Key('order_success_warning_dialog')), findsOneWidget);

      // Tap Salir Ahora
      await tester.tap(find.byKey(const Key('order_success_exit_now_button')));
      await tester.pumpAndSettle();

      // Callback invoked and session reset
      expect(finishedCalled, isTrue);
      expect(sessionController.phone, isEmpty);

      // Clean up timer
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('timer countdown expiration at 0s automatically completes session', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      bool finishedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OrderSuccessScreen(
            order: const {
              'id': 'ord_expire_test',
              'orderNumber': 33,
              'paymentStatus': 'PAID',
            },
            initialCountdownSeconds: 2,
            warningThresholdSeconds: 1,
            onFinished: () => finishedCalled = true,
          ),
        ),
      );
      await tester.pump();

      expect(finishedCalled, isFalse);

      // Advance clock by 3 seconds
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(finishedCalled, isTrue);

      // Clean up timer
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('OrderSuccessScreen - "Finalizar / Listo" Button', () {
    testWidgets('tapping Finalizar button clears cart, resets session and triggers completion',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      bool finishedCalled = false;
      final playedSounds = <KioskSoundType>[];

      final sessionController = KioskSessionController();
      sessionController.setPhone('8095559876');
      sessionController.setDiningMode(DiningMode.dineIn);

      final cartController = CartController();
      const testItem = StoreProduct(
        id: 'p1',
        name: 'Item 1',
        description: '',
        price: 10.0,
        categoryId: 'c1',
      );
      cartController.addItem(testItem, []);

      final soundService = SoundService(
        customPlayer: (type) async => playedSounds.add(type),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderSuccessScreen(
            order: const {
              'id': 'ord_finish_test',
              'orderNumber': 77,
              'paymentStatus': 'PAID',
            },
            sessionController: sessionController,
            cartController: cartController,
            soundService: soundService,
            initialCountdownSeconds: 60,
            onFinished: () => finishedCalled = true,
          ),
        ),
      );
      await tester.pump();

      // Initial sound played on enter
      expect(playedSounds, contains(KioskSoundType.paymentSuccess));

      // Button exists and is prominent
      final finishButton = find.byKey(const Key('order_success_finish_button'));
      expect(finishButton, findsOneWidget);
      expect(find.text('Finalizar / Listo'), findsOneWidget);

      // Cart has items before tapping finish
      expect(cartController.totalItemCount, 1);
      expect(sessionController.phone, '8095559876');

      // Tap finish
      await tester.tap(finishButton);
      await tester.pumpAndSettle();

      // Session and cart are wiped for privacy and clean state
      expect(finishedCalled, isTrue);
      expect(cartController.totalItemCount, 0);
      expect(sessionController.phone, isEmpty);
      expect(playedSounds, contains(KioskSoundType.click));

      // Clean up timer
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
