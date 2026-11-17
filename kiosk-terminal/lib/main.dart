import 'package:flutter/material.dart';
import 'config/brand_config.dart';
import 'controllers/cart_controller.dart';
import 'controllers/kiosk_session_controller.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/attract_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/customer_info_screen.dart';
import 'screens/dining_mode_screen.dart';
import 'screens/order_success_screen.dart';
import 'services/kiosk_lock_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElOrigenKioskApp());
}

/// Inherited scope to expose [KioskSessionController] down the widget tree
class KioskScope extends InheritedNotifier<KioskSessionController> {
  const KioskScope({
    super.key,
    required KioskSessionController super.notifier,
    required super.child,
  });

  static KioskSessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KioskScope>();
    assert(scope != null, 'No KioskScope found in context');
    return scope!.notifier!;
  }
}

/// Inherited scope to expose [CartController] down the widget tree
class CartScope extends InheritedNotifier<CartController> {
  const CartScope({
    super.key,
    required CartController super.notifier,
    required super.child,
  });

  static CartController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'No CartScope found in context');
    return scope!.notifier!;
  }
}

class ElOrigenKioskApp extends StatefulWidget {
  const ElOrigenKioskApp({super.key});

  static const Color primaryColor = Color(0xFFEA581E);
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color darkTextColor = Color(0xFF1E293B);

  @override
  State<ElOrigenKioskApp> createState() => _ElOrigenKioskAppState();
}

class _ElOrigenKioskAppState extends State<ElOrigenKioskApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final KioskSessionController _sessionController;
  late final CartController _cartController;
  late final KioskLockService _lockService;

  @override
  void initState() {
    super.initState();
    _lockService = KioskLockService()..init();
    _cartController = CartController();
    _sessionController = KioskSessionController(
      onSessionTimeout: _handleSessionTimeout,
    );
  }

  void _handleSessionTimeout() {
    // When idle for 60s, wipe all customer PII, clear cart and return to AttractScreen
    _sessionController.resetSession();
    _cartController.clear();
    _navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  void dispose() {
    _lockService.dispose();
    _cartController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KioskScope(
      notifier: _sessionController,
      child: CartScope(
        notifier: _cartController,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _sessionController.userInteracted(),
          onPointerMove: (_) => _sessionController.userInteracted(),
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            title: BrandConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: BrandConfig.primaryColor,
                primary: BrandConfig.primaryColor,
                surface: BrandConfig.surfaceColor,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: BrandConfig.surfaceColor,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                foregroundColor: ElOrigenKioskApp.darkTextColor,
                elevation: 0,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandConfig.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => AttractScreen(
                    sessionController: _sessionController,
                  ),
              '/admin-settings': (context) => AdminSettingsScreen(
                    sessionController: _sessionController,
                    cartController: _cartController,
                    lockService: _lockService,
                  ),
              '/customer-info': (context) => CustomerInfoScreen(
                    sessionController: _sessionController,
                  ),
              '/dining-mode': (context) => DiningModeScreen(
                    sessionController: _sessionController,
                  ),
              '/catalog': (context) => CatalogScreen(
                    sessionController: _sessionController,
                    cartController: _cartController,
                  ),
              '/checkout': (context) => CheckoutScreen(
                    sessionController: _sessionController,
                    cartController: _cartController,
                  ),
              '/order-success': (context) {
                final order = ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>? ??
                    {};
                return OrderSuccessScreen(
                  order: order,
                  sessionController: _sessionController,
                  cartController: _cartController,
                );
              },
            },
          ),
        ),
      ),
    );
  }
}
