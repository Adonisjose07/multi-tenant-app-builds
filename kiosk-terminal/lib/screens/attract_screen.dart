import 'dart:async';
import 'package:flutter/material.dart';
import '../config/brand_config.dart';
import '../controllers/kiosk_session_controller.dart';
import '../widgets/admin_pin_dialog.dart';
import 'customer_info_screen.dart';

class AttractScreen extends StatefulWidget {
  final KioskSessionController sessionController;

  const AttractScreen({
    super.key,
    required this.sessionController,
  });

  @override
  State<AttractScreen> createState() => _AttractScreenState();
}

class _AttractScreenState extends State<AttractScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Stop any active session timeout on screensaver
    widget.sessionController.stopInactivityTimer();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Timer? _adminGestureTimer;

  void _startAdminGesture() {
    _adminGestureTimer?.cancel();
    _adminGestureTimer = Timer(const Duration(seconds: 3), () {
      _triggerAdminPinDialog();
    });
  }

  void _cancelAdminGesture() {
    _adminGestureTimer?.cancel();
    _adminGestureTimer = null;
  }

  Future<void> _triggerAdminPinDialog() async {
    _cancelAdminGesture();
    final authenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AdminPinDialog(),
    );

    if (authenticated == true && mounted) {
      Navigator.of(context).pushNamed('/admin-settings');
    }
  }

  @override
  void dispose() {
    _adminGestureTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startOrderJourney() {
    widget.sessionController.resetSession();
    widget.sessionController.startInactivityTimer();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomerInfoScreen(
          sessionController: widget.sessionController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = BrandConfig.primaryColor;
    const darkTextColor = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: BrandConfig.surfaceColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _startOrderJourney,
              child: Stack(
                children: [
                  // Decorative background shapes
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -80,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF3B82F6).withOpacity(0.04),
                      ),
                    ),
                  ),

                  // Main Content
                  Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 64.0 : 24.0,
                        vertical: 32.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Restaurant Brand Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: BrandConfig.logoUrl.isNotEmpty
                                    ? Image.network(
                                        BrandConfig.logoUrl,
                                        height: 40,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.restaurant_menu_rounded,
                                          size: 32,
                                          color: primaryColor,
                                        ),
                                      )
                                    : Icon(
                                        Icons.restaurant_menu_rounded,
                                        size: 32,
                                        color: primaryColor,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                BrandConfig.tenantSlug == 'default' &&
                                        BrandConfig.appName ==
                                            'Self-Service Kiosk'
                                    ? 'KIOSK TERMINAL'
                                    : BrandConfig.appName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  color: darkTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Hero Animation Container
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  width: isTablet ? 240 : 180,
                                  height: isTablet ? 240 : 180,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      colors: [
                                        Color(0xFFFFF7ED),
                                        Color(0xFFFFEDD5),
                                        Color(0xFFFDBA74),
                                      ],
                                      stops: [0.3, 0.7, 1.0],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.3),
                                        blurRadius: _glowAnimation.value * 2,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.fastfood_rounded,
                                      size: 88,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 36),

                          // Slogan & Welcome
                          Text(
                            '¡Haz tu Pedido al Instante!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isTablet ? 42 : 30,
                              fontWeight: FontWeight.w900,
                              color: darkTextColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Text(
                              'Personaliza tu comida favorita, paga con tu tarjeta Contactless y disfruta la experiencia rápida de autoservicio.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isTablet ? 19 : 15,
                                color: const Color(0xFF64748B),
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Pulsing "Tocar para ordenar" CTA Button
                          AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  width: isTablet ? 420 : double.infinity,
                                  height: 72,
                                  constraints: const BoxConstraints(minHeight: 56.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor,
                                        const Color(0xFFF97316),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.4),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: _startOrderJourney,
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.touch_app_rounded,
                                            size: 32,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 12),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                'TOCAR PARA ORDENAR',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 36),

                          // Feature highlights / badges
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: const [
                              _KioskFeatureChip(
                                icon: Icons.contactless_rounded,
                                label: 'Stripe NFC Contactless',
                              ),
                              _KioskFeatureChip(
                                icon: Icons.bolt_rounded,
                                label: 'Entrega Rápida',
                              ),
                              _KioskFeatureChip(
                                icon: Icons.receipt_long_rounded,
                                label: 'Ticket & QR Móvil',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Secret Admin Gesture Touch Zone (holding top-right corner for 3s triggers PIN dialog)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      key: const Key('admin_secret_gesture_zone'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _startAdminGesture(),
                      onTapUp: (_) => _cancelAdminGesture(),
                      onTapCancel: _cancelAdminGesture,
                      onTap: () {
                        _cancelAdminGesture();
                        _startOrderJourney();
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KioskFeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _KioskFeatureChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: BrandConfig.primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
