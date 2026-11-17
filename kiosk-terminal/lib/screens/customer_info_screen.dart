import 'package:flutter/material.dart';
import '../controllers/kiosk_session_controller.dart';
import '../widgets/custom_keypad.dart';
import 'dining_mode_screen.dart';

enum CustomerInfoTab {
  phone,
  email,
}

class CustomerInfoScreen extends StatefulWidget {
  final KioskSessionController sessionController;

  const CustomerInfoScreen({
    super.key,
    required this.sessionController,
  });

  @override
  State<CustomerInfoScreen> createState() => _CustomerInfoScreenState();
}

class _CustomerInfoScreenState extends State<CustomerInfoScreen> {
  CustomerInfoTab _activeTab = CustomerInfoTab.phone;

  static const List<String> _quickDomains = [
    '@gmail.com',
    '@yahoo.com',
    '@icloud.com',
    '@outlook.com',
  ];

  @override
  void initState() {
    super.initState();
    widget.sessionController.resetInactivityTimer();
  }

  void _onContinue() {
    if (!widget.sessionController.isPhoneValid) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DiningModeScreen(
          sessionController: widget.sessionController,
        ),
      ),
    );
  }

  void _cancelAndExit() {
    widget.sessionController.resetSession();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _appendEmailDomain(String domain) {
    widget.sessionController.userInteracted();
    final current = widget.sessionController.email ?? '';
    // If already contains @, replace existing domain or append
    final atIndex = current.indexOf('@');
    final prefix = atIndex >= 0 ? current.substring(0, atIndex) : current;
    if (prefix.isNotEmpty) {
      widget.sessionController.setEmail('$prefix$domain');
    } else {
      widget.sessionController.setEmail(domain);
    }
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
        child: AnimatedBuilder(
          animation: widget.sessionController,
          builder: (context, _) {
            final isPhoneValid = widget.sessionController.isPhoneValid;
            final isEmailValid = widget.sessionController.isEmailValid;
            final canProceed = isPhoneValid && isEmailValid;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => widget.sessionController.userInteracted(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 900 : double.infinity,
                      ),
                      child: isTablet
                          ? _buildTabletLayout(primaryColor, darkTextColor, canProceed)
                          : _buildMobileLayout(primaryColor, darkTextColor, canProceed),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet Layout (Spacious 2-column)
  // ---------------------------------------------------------------------------
  Widget _buildTabletLayout(
    Color primaryColor,
    Color darkTextColor,
    bool canProceed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Instructions, Tabs, Display & Action Button
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderTitle(darkTextColor, true),
                  const SizedBox(height: 24),
                  _buildTabSwitcher(primaryColor),
                  const SizedBox(height: 24),
                  if (_activeTab == CustomerInfoTab.phone) ...[
                    _buildPhoneDisplay(primaryColor),
                    const SizedBox(height: 12),
                    _buildPhoneNotice(),
                  ] else ...[
                    _buildEmailDisplay(primaryColor),
                    const SizedBox(height: 16),
                    _buildQuickDomainChips(primaryColor),
                  ],
                  const SizedBox(height: 36),
                  _buildContinueButton(primaryColor, canProceed, 64),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),

          // Right Column: Dedicated Touch Keypad
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              child: _activeTab == CustomerInfoTab.phone
                  ? CustomKeypad(
                      buttonHeight: 70,
                      spacing: 16,
                      onDigitPressed: widget.sessionController.appendPhoneDigit,
                      onBackspacePressed: widget.sessionController.backspacePhone,
                      onClearPressed: widget.sessionController.clearPhone,
                    )
                  : _buildEmailKeyboard(primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile Layout (Single Column Scrollable)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(
    Color primaryColor,
    Color darkTextColor,
    bool canProceed,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderTitle(darkTextColor, false),
          const SizedBox(height: 18),
          _buildTabSwitcher(primaryColor),
          const SizedBox(height: 20),
          if (_activeTab == CustomerInfoTab.phone) ...[
            _buildPhoneDisplay(primaryColor),
            const SizedBox(height: 8),
            _buildPhoneNotice(),
            const SizedBox(height: 20),
            CustomKeypad(
              buttonHeight: 60,
              spacing: 12,
              onDigitPressed: widget.sessionController.appendPhoneDigit,
              onBackspacePressed: widget.sessionController.backspacePhone,
              onClearPressed: widget.sessionController.clearPhone,
            ),
          ] else ...[
            _buildEmailDisplay(primaryColor),
            const SizedBox(height: 14),
            _buildQuickDomainChips(primaryColor),
            const SizedBox(height: 20),
            _buildEmailKeyboard(primaryColor),
          ],
          const SizedBox(height: 28),
          _buildContinueButton(primaryColor, canProceed, 58),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Components
  // ---------------------------------------------------------------------------

  Widget _buildHeaderTitle(Color darkTextColor, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tus Datos de Contacto',
          style: TextStyle(
            fontSize: isTablet ? 32 : 24,
            fontWeight: FontWeight.w900,
            color: darkTextColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Necesitamos tu teléfono para avisarte cuando tu pedido esté listo.',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSwitcher(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              icon: Icons.phone_android_rounded,
              label: 'Teléfono *',
              isActive: _activeTab == CustomerInfoTab.phone,
              primaryColor: primaryColor,
              onTap: () {
                widget.sessionController.userInteracted();
                setState(() => _activeTab = CustomerInfoTab.phone);
              },
            ),
          ),
          Expanded(
            child: _TabButton(
              icon: Icons.alternate_email_rounded,
              label: 'Correo (Opcional)',
              isActive: _activeTab == CustomerInfoTab.email,
              primaryColor: primaryColor,
              onTap: () {
                widget.sessionController.userInteracted();
                setState(() => _activeTab = CustomerInfoTab.email);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneDisplay(Color primaryColor) {
    final phone = widget.sessionController.phone;
    final formatted = widget.sessionController.session.formattedPhone;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: phone.isNotEmpty ? primaryColor : const Color(0xFFCBD5E1),
          width: phone.isNotEmpty ? 2.0 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.call_rounded, color: primaryColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Número Celular',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatted.isNotEmpty ? formatted : 'Ingresa tu teléfono...',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: formatted.isNotEmpty ? 1.0 : 0.0,
                    color: formatted.isNotEmpty
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8)),
              onPressed: widget.sessionController.clearPhone,
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneNotice() {
    final digitsCount = widget.sessionController.session.rawPhone.length;
    final isValid = digitsCount >= 7;

    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 16,
          color: isValid ? const Color(0xFF10B981) : const Color(0xFF64748B),
        ),
        const SizedBox(width: 6),
        Text(
          isValid
              ? 'Teléfono válido ($digitsCount dígitos ingresados)'
              : 'Mínimo 7 dígitos requeridos ($digitsCount/7)',
          style: TextStyle(
            fontSize: 13,
            color: isValid ? const Color(0xFF10B981) : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailDisplay(Color primaryColor) {
    final email = widget.sessionController.email ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: email.isNotEmpty ? primaryColor : const Color(0xFFCBD5E1),
          width: email.isNotEmpty ? 2.0 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.email_rounded, color: primaryColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Correo Electrónico (Para tu factura)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isNotEmpty ? email : 'ejemplo@correo.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: email.isNotEmpty
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (email.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8)),
              onPressed: widget.sessionController.clearEmail,
            ),
        ],
      ),
    );
  }

  Widget _buildQuickDomainChips(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Terminaciones rápidas:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _quickDomains.map((domain) {
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _appendEmailDomain(domain),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  domain,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmailKeyboard(Color primaryColor) {
    // Generates an on-screen QWERTY touch layout for kiosk users
    final rows = [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['z', 'x', 'c', 'v', 'b', 'n', 'm', '.', '_', '-'],
    ];

    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((char) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Container(
                    height: 56, // Meets 56dp+ Fitts target
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => widget.sessionController.appendEmailChar(char),
                        child: Center(
                          child: Text(
                            char,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
        ],
        // Bottom control row: @, numbers 1-5, backspace
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => widget.sessionController.appendEmailChar('@'),
                      child: const Center(
                        child: Text(
                          '@',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.sessionController.clearEmail,
                      child: const Center(
                        child: Text(
                          'Limpiar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.sessionController.backspaceEmail,
                      child: const Center(
                        child: Icon(
                          Icons.backspace_outlined,
                          size: 22,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContinueButton(
    Color primaryColor,
    bool canProceed,
    double height,
  ) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canProceed ? primaryColor : const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          elevation: canProceed ? 3 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: canProceed ? _onContinue : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              canProceed ? 'CONTINUAR' : 'INGRESA TU TELÉFONO',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            if (canProceed) ...[
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded, size: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color primaryColor;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56, // Meets 56dp+ Fitts target
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive
            ? const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? primaryColor : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? primaryColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
