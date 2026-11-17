import 'package:flutter/material.dart';
import '../controllers/kiosk_session_controller.dart';
import '../models/kiosk_session.dart';
import '../widgets/custom_keypad.dart';

class DiningModeScreen extends StatefulWidget {
  final KioskSessionController sessionController;
  final VoidCallback? onProceedToCatalog;

  const DiningModeScreen({
    super.key,
    required this.sessionController,
    this.onProceedToCatalog,
  });

  @override
  State<DiningModeScreen> createState() => _DiningModeScreenState();
}

class _DiningModeScreenState extends State<DiningModeScreen> {
  @override
  void initState() {
    super.initState();
    widget.sessionController.resetInactivityTimer();
  }

  void _onTakeawaySelected() {
    widget.sessionController.userInteracted();
    widget.sessionController.setDiningMode(DiningMode.takeaway);
    widget.sessionController.setTableOrPagerNumber(null);
    _proceedToNext();
  }

  void _onDineInSelected() {
    widget.sessionController.userInteracted();
    widget.sessionController.setDiningMode(DiningMode.dineIn);
    _showTableOrPagerPrompt();
  }

  void _proceedToNext() {
    if (widget.onProceedToCatalog != null) {
      widget.onProceedToCatalog!();
    } else {
      // Navigate to /catalog if defined or show next step ready dialog
      Navigator.of(context).pushNamed('/catalog');
    }
  }

  void _cancelAndExit() {
    widget.sessionController.resetSession();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showTableOrPagerPrompt() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return _TableOrPagerBottomSheet(
          sessionController: widget.sessionController,
          onConfirmed: () {
            Navigator.of(modalContext).pop();
            _proceedToNext();
          },
          onSkipped: () {
            widget.sessionController.setTableOrPagerNumber(null);
            Navigator.of(modalContext).pop();
            _proceedToNext();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEA581E);
    const darkTextColor = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
            color: darkTextColor,
            tooltip: 'Volver',
            onPressed: () {
              widget.sessionController.userInteracted();
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _cancelAndExit,
            icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444)),
            label: const Text(
              'Cancelar',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => widget.sessionController.userInteracted(),
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 48.0 : 20.0,
                    vertical: 24.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 960 : 480,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Header
                        Text(
                          '¿Dónde vas a comer?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 38 : 28,
                            fontWeight: FontWeight.w900,
                            color: darkTextColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Selecciona tu modalidad preferida para esta orden.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 15,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Responsive Dining Mode Cards
                        if (isTablet)
                          Row(
                            children: [
                              Expanded(
                                child: _DiningOptionCard(
                                  icon: Icons.restaurant_rounded,
                                  iconColor: primaryColor,
                                  title: 'Para Comer Aquí',
                                  subtitle:
                                      'Te serviremos en tu mesa o con un localizador buzzer en salón.',
                                  badge: 'Servicio en Mesa',
                                  isTablet: true,
                                  onTap: _onDineInSelected,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: _DiningOptionCard(
                                  icon: Icons.shopping_bag_rounded,
                                  iconColor: const Color(0xFF10B981),
                                  title: 'Para Llevar',
                                  subtitle:
                                      'Empacado hermético listo para retirar en la zona de despacho.',
                                  badge: 'Takeaway Rápido',
                                  isTablet: true,
                                  onTap: _onTakeawaySelected,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _DiningOptionCard(
                                icon: Icons.restaurant_rounded,
                                iconColor: primaryColor,
                                title: 'Para Comer Aquí',
                                subtitle:
                                    'Te serviremos en tu mesa o con un localizador buzzer.',
                                badge: 'Servicio en Mesa',
                                isTablet: false,
                                onTap: _onDineInSelected,
                              ),
                              const SizedBox(height: 20),
                              _DiningOptionCard(
                                icon: Icons.shopping_bag_rounded,
                                iconColor: const Color(0xFF10B981),
                                title: 'Para Llevar',
                                subtitle:
                                    'Empacado listo para retirar en el mostrador.',
                                badge: 'Takeaway Rápido',
                                isTablet: false,
                                onTap: _onTakeawaySelected,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DiningOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final bool isTablet;
  final VoidCallback onTap;

  const _DiningOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          splashColor: iconColor.withOpacity(0.12),
          highlightColor: iconColor.withOpacity(0.06),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 32.0 : 24.0,
              vertical: isTablet ? 40.0 : 28.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon Avatar
                Container(
                  width: isTablet ? 90 : 72,
                  height: isTablet ? 90 : 72,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: isTablet ? 48 : 36,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isTablet ? 26 : 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Touch Target Button
                Container(
                  width: double.infinity,
                  height: 56, // Meets 56dp+ Fitts target
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SELECCIONAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TableOrPagerBottomSheet extends StatelessWidget {
  final KioskSessionController sessionController;
  final VoidCallback onConfirmed;
  final VoidCallback onSkipped;

  const _TableOrPagerBottomSheet({
    required this.sessionController,
    required this.onConfirmed,
    required this.onSkipped,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEA581E);
    const darkTextColor = Color(0xFF1E293B);

    return AnimatedBuilder(
      animation: sessionController,
      builder: (context, _) {
        final currentTable = sessionController.tableOrPagerNumber ?? '';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle pill
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Número de Mesa o Localizador',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: darkTextColor,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ingresa el número indicado en tu mesa o en el localizador físico.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

              // Display
              Container(
                width: 220,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: currentTable.isNotEmpty
                        ? primaryColor
                        : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    currentTable.isNotEmpty ? currentTable : '# --',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: currentTable.isNotEmpty
                          ? primaryColor
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Custom Keypad for table number
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: CustomKeypad(
                  buttonHeight: 56,
                  spacing: 10,
                  onDigitPressed: sessionController.appendTableDigit,
                  onBackspacePressed: sessionController.backspaceTableDigit,
                  onClearPressed: sessionController.clearTableDigit,
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56, // >= 56dp
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: onSkipped,
                          child: const Text(
                            'Omitir (No tengo)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56, // >= 56dp
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: onConfirmed,
                          child: const Text(
                            'Confirmar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
