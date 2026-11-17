import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elorigen_kiosk/controllers/cart_controller.dart';
import 'package:elorigen_kiosk/controllers/kiosk_session_controller.dart';
import 'package:elorigen_kiosk/models/nfc_quadrant.dart';
import 'package:elorigen_kiosk/models/store_product.dart';
import 'package:elorigen_kiosk/screens/admin_settings_screen.dart';
import 'package:elorigen_kiosk/screens/attract_screen.dart';
import 'package:elorigen_kiosk/services/kiosk_api_service.dart';
import 'package:elorigen_kiosk/services/kiosk_lock_service.dart';
import 'package:elorigen_kiosk/services/stripe_terminal_service.dart';
import 'package:elorigen_kiosk/widgets/admin_pin_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdminPinDialog.resetLockoutState();
  });

  group('KioskLockService Unit Tests', () {
    const channel = MethodChannel(KioskLockService.channelName);
    final methodCalls = <MethodCall>[];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'startLockTask':
            return {'success': true, 'locked': true};
          case 'stopLockTask':
            return {'success': true, 'locked': false};
          case 'isInLockTaskMode':
            return {'inLockTaskMode': true};
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('default state is unlocked', () async {
      final service = KioskLockService();
      expect(await service.isLockEnabled(), isFalse);
      expect(service.isKioskModeEnabled, isFalse);
      service.dispose();
    });

    test('enableKioskLock persists to SharedPreferences and calls native startLockTask',
        () async {
      final service = KioskLockService();
      final success = await service.enableKioskLock();

      expect(success, isTrue);
      expect(await service.isLockEnabled(), isTrue);
      expect(service.isKioskModeEnabled, isTrue);
      expect(methodCalls.any((call) => call.method == 'startLockTask'), isTrue);
      service.dispose();
    });

    test('disableKioskLock persists to SharedPreferences and calls native stopLockTask',
        () async {
      final service = KioskLockService();
      await service.enableKioskLock();
      methodCalls.clear();

      final success = await service.disableKioskLock();
      expect(success, isTrue);
      expect(await service.isLockEnabled(), isFalse);
      expect(service.isKioskModeEnabled, isFalse);
      expect(methodCalls.any((call) => call.method == 'stopLockTask'), isTrue);
      service.dispose();
    });

    test('init re-engages lockTask if preference was enabled', () async {
      SharedPreferences.setMockInitialValues({
        KioskLockService.prefsLockEnabledKey: true,
      });

      final service = KioskLockService();
      await service.init();

      expect(service.isKioskModeEnabled, isTrue);
      expect(methodCalls.any((call) => call.method == 'startLockTask'), isTrue);
      service.dispose();
    });
  });

  group('AdminPinDialog Widget & Rate-Limiting Tests', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    testWidgets('authenticates with correct default PIN 1234', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      bool? authResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  authResult = await showDialog<bool>(
                    context: context,
                    builder: (_) => const AdminPinDialog(),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_pin_dialog')), findsOneWidget);

      // Tap digits 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      expect(authResult, isTrue);
      expect(find.byKey(const Key('admin_pin_dialog')), findsNothing);
    });

    testWidgets('wrong PIN shows remaining attempts feedback', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminPinDialog(expectedPin: '9999'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 1, 2, 3, 4 (incorrect)
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pump();

      expect(find.byKey(const Key('admin_pin_error_text')), findsOneWidget);
      expect(find.textContaining('Intentos restantes: 4'), findsOneWidget);
      expect(AdminPinDialog.failedAttempts, 1);
    });

    testWidgets(
        '5 consecutive failed attempts trigger 60-second lockout and disable keypad',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminPinDialog(expectedPin: '8888'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter wrong PIN 5 times
      for (int attempt = 1; attempt <= 5; attempt++) {
        await tester.tap(find.text('1'));
        await tester.pump();
        await tester.tap(find.text('2'));
        await tester.pump();
        await tester.tap(find.text('3'));
        await tester.pump();
        await tester.tap(find.text('4'));
        await tester.pump();
      }

      // Check lockout banner is now visible
      expect(find.byKey(const Key('admin_pin_lockout_banner')), findsOneWidget);
      expect(find.textContaining('Reintentar en:'), findsOneWidget);
      expect(AdminPinDialog.failedAttempts, 5);
      expect(AdminPinDialog.lockoutUntil, isNotNull);

      // Tapping digits while locked out does not enter digits
      await tester.tap(find.text('8'));
      await tester.pump();
      expect(find.byKey(const Key('admin_pin_dots_row')), findsNothing);
    });

    testWidgets('cancel button dismisses dialog with false', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      bool? authResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  authResult = await showDialog<bool>(
                    context: context,
                    builder: (_) => const AdminPinDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_pin_cancel_button')));
      await tester.pumpAndSettle();

      expect(authResult, isFalse);
      expect(find.byKey(const Key('admin_pin_dialog')), findsNothing);
    });
  });

  group('AttractScreen Secret Gesture Wiring', () {
    testWidgets('secret gesture touch zone exists in top-right corner',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final sessionController = KioskSessionController();

      await tester.pumpWidget(
        MaterialApp(
          home: AttractScreen(sessionController: sessionController),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('admin_secret_gesture_zone')), findsOneWidget);
    });

    testWidgets('holding top-right corner for 3 seconds opens AdminPinDialog',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final sessionController = KioskSessionController();

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (_) => AttractScreen(sessionController: sessionController),
            '/admin-settings': (_) => const Scaffold(body: Text('AdminSettings')),
          },
        ),
      );
      await tester.pump();

      final gestureFinder = find.byKey(const Key('admin_secret_gesture_zone'));

      // Press down on gesture zone
      final gesture = await tester.startGesture(tester.getCenter(gestureFinder));
      await tester.pump(const Duration(seconds: 1));
      // Not triggered yet after 1 second
      expect(find.byKey(const Key('admin_pin_dialog')), findsNothing);

      // Advance remaining 2.1 seconds to reach 3.1s total
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // PIN dialog is now open!
      expect(find.byKey(const Key('admin_pin_dialog')), findsOneWidget);

      await gesture.up();
    });
  });

  group('AdminSettingsScreen Widget & Features Tests', () {
    late KioskSessionController sessionController;
    late CartController cartController;

    setUp(() {
      sessionController = KioskSessionController();
      cartController = CartController();
    });

    testWidgets('renders all configuration fields and initial values',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({
        AdminSettingsScreen.prefsBranchIdKey: 'branch_hq_01',
        AdminSettingsScreen.prefsApiUrlKey: 'https://api.elorigen.com/graphql',
        AdminSettingsScreen.prefsDeviceNameKey: 'Tótem Entrada 1',
        AdminPinDialog.prefsPinKey: '4321',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            sessionController: sessionController,
            cartController: cartController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_branch_id_field')), findsOneWidget);
      expect(find.byKey(const Key('admin_api_url_field')), findsOneWidget);
      expect(find.byKey(const Key('admin_device_name_field')), findsOneWidget);
      expect(find.byKey(const Key('admin_pin_field')), findsOneWidget);

      expect(find.text('branch_hq_01'), findsOneWidget);
      expect(find.text('https://api.elorigen.com/graphql'), findsOneWidget);
      expect(find.text('Tótem Entrada 1'), findsWidgets);
      expect(find.text('4321'), findsOneWidget);
    });

    testWidgets('operating mode toggle reveals table number field when Table Mode',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            sessionController: sessionController,
            cartController: cartController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default is Totem: table field is not visible
      expect(find.byKey(const Key('admin_table_number_field')), findsNothing);

      // Switch to Table Mode
      await tester.tap(find.byKey(const Key('admin_mode_table')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_table_number_field')), findsOneWidget);
    });

    testWidgets(
        'NFC quadrant calibration chips update selection and live visual preview',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            sessionController: sessionController,
            cartController: cartController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nfc_quadrant_live_preview')), findsOneWidget);

      // Select top-left quadrant
      await tester.tap(find.byKey(const Key('nfc_chip_topLeft')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Esquina Superior Izquierda'), findsWidgets);
      expect(find.textContaining('↖️'), findsWidgets);

      // Select screenCenter quadrant
      await tester.tap(find.byKey(const Key('nfc_chip_screenCenter')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Centro de la Pantalla'), findsWidgets);
      expect(find.textContaining('🎯'), findsWidgets);
    });

    testWidgets('diagnostics: API test and NFC hardware test trigger results',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const terminalChannel = MethodChannel(StripeTerminalService.channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(terminalChannel, (MethodCall call) async {
        if (call.method == 'checkHardwareSupport') {
          return {'hasNfc': true, 'isEmulator': false, 'isSupported': true};
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(terminalChannel, null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            sessionController: sessionController,
            cartController: cartController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Test API
      await tester.tap(find.byKey(const Key('admin_test_api_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_api_test_result')), findsOneWidget);

      // Tap Test NFC
      await tester.tap(find.byKey(const Key('admin_test_nfc_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('admin_nfc_test_result')), findsOneWidget);
    });

    testWidgets('memory sanitization button wipes cart and customer PII',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      // Pre-fill cart and session
      sessionController.setPhone('5551234567');
      sessionController.setEmail('customer@test.com');
      cartController.addItem(
        const StoreProduct(
          id: 'prod_1',
          categoryId: 'cat_1',
          name: 'Burger Test',
          price: 10.0,
        ),
        [],
      );

      expect(sessionController.phone, '5551234567');
      expect(cartController.isEmpty, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            sessionController: sessionController,
            cartController: cartController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap sanitize memory button
      await tester.ensureVisible(find.byKey(const Key('admin_sanitize_memory_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_sanitize_memory_button')));
      await tester.pump();

      // Verify customer PII and cart are wiped clean
      expect(sessionController.phone, '');
      expect(sessionController.email, isNull);
      expect(cartController.isEmpty, isTrue);
      expect(find.byKey(const Key('admin_sanitize_snackbar')), findsOneWidget);
    });

    testWidgets('save configuration persists updated values to SharedPreferences',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            sessionController: sessionController,
            cartController: cartController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter new values
      await tester.enterText(
          find.byKey(const Key('admin_branch_id_field')), 'branch_new_99');
      await tester.enterText(
          find.byKey(const Key('admin_device_name_field')), 'Kiosk Tablet Beta');
      await tester.enterText(find.byKey(const Key('admin_pin_field')), '9876');

      // Tap Save
      await tester.ensureVisible(find.byKey(const Key('admin_save_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_save_button')));
      await tester.pump();

      expect(find.byKey(const Key('admin_save_snackbar')), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AdminSettingsScreen.prefsBranchIdKey), 'branch_new_99');
      expect(prefs.getString(AdminSettingsScreen.prefsDeviceNameKey), 'Kiosk Tablet Beta');
      expect(prefs.getString(AdminPinDialog.prefsPinKey), '9876');
    });
  });
}
