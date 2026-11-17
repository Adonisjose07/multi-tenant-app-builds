import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/brand_config.dart';
import '../controllers/cart_controller.dart';
import '../controllers/kiosk_session_controller.dart';
import '../main.dart';
import '../models/nfc_quadrant.dart';
import '../services/kiosk_api_service.dart';
import '../services/kiosk_lock_service.dart';
import '../services/stripe_terminal_service.dart';
import '../widgets/admin_pin_dialog.dart';

/// Operating modes for El Origen Kiosks
enum KioskOperatingMode {
  totem,
  table,
}

extension KioskOperatingModeExtension on KioskOperatingMode {
  String get code => name.toUpperCase();
  String get label => this == KioskOperatingMode.totem
      ? 'Tótem de Autoservicio'
      : 'Mesa Fija (Table Mode)';

  static KioskOperatingMode fromString(String? value) {
    if (value == null) return KioskOperatingMode.totem;
    final val = value.trim().toUpperCase();
    if (val == 'TABLE' || val == 'MESA') return KioskOperatingMode.table;
    return KioskOperatingMode.totem;
  }
}

class AdminSettingsScreen extends StatefulWidget {
  final KioskSessionController? sessionController;
  final CartController? cartController;
  final KioskLockService? lockService;
  final KioskApiService? apiService;
  final StripeTerminalService? terminalService;

  const AdminSettingsScreen({
    super.key,
    this.sessionController,
    this.cartController,
    this.lockService,
    this.apiService,
    this.terminalService,
  });

  static const String prefsBranchIdKey = 'kiosk_branch_id';
  static const String prefsApiUrlKey = 'kiosk_api_url';
  static const String prefsDeviceNameKey = 'kiosk_device_name';
  static const String prefsOperatingModeKey = 'kiosk_operating_mode';
  static const String prefsTableNumberKey = 'kiosk_table_number';

  static const String defaultBranchId = 'branch_demo_01';
  static const String defaultApiUrl = BrandConfig.apiUrl;
  static const String defaultDeviceName = 'Tótem Central #1';

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late final KioskLockService _lockService;
  late final KioskApiService _apiService;
  late final StripeTerminalService _terminalService;

  final TextEditingController _branchIdController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _adminPinController = TextEditingController();
  final TextEditingController _tableNumberController = TextEditingController();

  KioskOperatingMode _operatingMode = KioskOperatingMode.totem;
  NfcQuadrant _selectedQuadrant = NfcQuadrant.topRight;
  bool _isKioskLocked = false;
  bool _isLoading = true;

  // Diagnostics states
  bool _testingApi = false;
  Map<String, dynamic>? _apiTestResult;

  bool _testingNfc = false;
  Map<String, dynamic>? _nfcTestResult;

  static const Color primaryColor = Color(0xFFEA581E);
  static const Color darkTextColor = Color(0xFF1E293B);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _lockService = widget.lockService ?? KioskLockService();
    _apiService = widget.apiService ?? KioskApiService();
    _terminalService = widget.terminalService ?? StripeTerminalService();

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _branchIdController.text =
          prefs.getString(AdminSettingsScreen.prefsBranchIdKey) ??
              AdminSettingsScreen.defaultBranchId;
      _apiUrlController.text =
          prefs.getString(AdminSettingsScreen.prefsApiUrlKey) ??
              AdminSettingsScreen.defaultApiUrl;
      _deviceNameController.text =
          prefs.getString(AdminSettingsScreen.prefsDeviceNameKey) ??
              AdminSettingsScreen.defaultDeviceName;
      _adminPinController.text =
          prefs.getString(AdminPinDialog.prefsPinKey) ??
              AdminPinDialog.defaultPin;
      _tableNumberController.text =
          prefs.getString(AdminSettingsScreen.prefsTableNumberKey) ?? '1';

      final modeStr = prefs.getString(AdminSettingsScreen.prefsOperatingModeKey);
      _operatingMode = KioskOperatingModeExtension.fromString(modeStr);

      _selectedQuadrant = await NfcQuadrantExtension.loadConfigured();
      _isKioskLocked = await _lockService.isLockEnabled();
    } catch (_) {
      _branchIdController.text = AdminSettingsScreen.defaultBranchId;
      _apiUrlController.text = AdminSettingsScreen.defaultApiUrl;
      _deviceNameController.text = AdminSettingsScreen.defaultDeviceName;
      _adminPinController.text = AdminPinDialog.defaultPin;
      _tableNumberController.text = '1';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          AdminSettingsScreen.prefsBranchIdKey, _branchIdController.text.trim());
      await prefs.setString(
          AdminSettingsScreen.prefsApiUrlKey, _apiUrlController.text.trim());
      await prefs.setString(
          AdminSettingsScreen.prefsDeviceNameKey, _deviceNameController.text.trim());
      await prefs.setString(
          AdminPinDialog.prefsPinKey, _adminPinController.text.trim());
      await prefs.setString(
          AdminSettingsScreen.prefsOperatingModeKey, _operatingMode.code);
      await prefs.setString(
          AdminSettingsScreen.prefsTableNumberKey, _tableNumberController.text.trim());

      await NfcQuadrantExtension.saveConfigured(_selectedQuadrant);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('admin_save_snackbar'),
            content: Text('Configuración guardada exitosamente'),
            backgroundColor: successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar configuración: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _toggleKioskLock() async {
    final newState = !_isKioskLocked;
    bool success;
    if (newState) {
      success = await _lockService.enableKioskLock();
    } else {
      success = await _lockService.disableKioskLock();
    }

    if (mounted) {
      setState(() {
        _isKioskLocked = newState;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState
              ? 'Modo Kiosko activado (Android LockTask)'
              : 'Modo Kiosko desactivado'),
          backgroundColor: newState ? primaryColor : const Color(0xFF64748B),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _testingApi = true;
      _apiTestResult = null;
    });

    final testService = KioskApiService(endpoint: _apiUrlController.text.trim());
    final result = await testService.testConnection();

    if (mounted) {
      setState(() {
        _testingApi = false;
        _apiTestResult = result;
      });
    }
  }

  Future<void> _testNfcHardware() async {
    setState(() {
      _testingNfc = true;
      _nfcTestResult = null;
    });

    final result = await _terminalService.checkHardwareSupport();

    if (mounted) {
      setState(() {
        _testingNfc = false;
        _nfcTestResult = result;
      });
    }
  }

  void _sanitizeMemory() {
    final session = widget.sessionController ??
        (context.findAncestorWidgetOfExactType<KioskScope>()?.notifier);
    final cart = widget.cartController ??
        (context.findAncestorWidgetOfExactType<CartScope>()?.notifier);

    session?.resetSession();
    cart?.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('admin_sanitize_snackbar'),
        content: Text(
            'Memoria sanitizada: Se borraron todos los datos de clientes, teléfonos y carritos.'),
        backgroundColor: successColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _exitAdminSettings() {
    _sanitizeMemory();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  void dispose() {
    _branchIdController.dispose();
    _apiUrlController.dispose();
    _deviceNameController.dispose();
    _adminPinController.dispose();
    _tableNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Configuración de Administrador',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: darkTextColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          key: const Key('admin_exit_button'),
          icon: const Icon(Icons.arrow_back_rounded, color: darkTextColor),
          onPressed: _exitAdminSettings,
        ),
        actions: [
          IconButton(
            key: const Key('admin_save_appbar_button'),
            icon: const Icon(Icons.save_rounded, color: primaryColor),
            tooltip: 'Guardar Configuración',
            onPressed: _saveSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status summary card
                  _buildStatusOverviewCard(),
                  const SizedBox(height: 20),

                  // 1. Kiosk Identity & Server Connection
                  _buildSectionCard(
                    title: 'Identidad del Kiosko y Conexión de Servidor',
                    icon: Icons.store_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          key: const Key('admin_branch_id_field'),
                          controller: _branchIdController,
                          label: 'Branch ID (Sucursal)',
                          hint: 'branch_demo_01',
                          icon: Icons.business_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          key: const Key('admin_api_url_field'),
                          controller: _apiUrlController,
                          label: 'Endpoint GraphQL Backend',
                          hint: 'http://10.0.2.2:5000/graphql',
                          icon: Icons.link_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          key: const Key('admin_device_name_field'),
                          controller: _deviceNameController,
                          label: 'Nombre de la Terminal / Dispositivo',
                          hint: 'Tótem Central #1',
                          icon: Icons.tablet_android_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          key: const Key('admin_pin_field'),
                          controller: _adminPinController,
                          label: 'PIN de Seguridad Administrador (4 dígitos)',
                          hint: '1234',
                          icon: Icons.pin_rounded,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Operating Mode (Totem vs Table)
                  _buildSectionCard(
                    title: 'Modo de Operación',
                    icon: Icons.tune_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selecciona el formato en el que opera este dispositivo:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildModeOption(
                                mode: KioskOperatingMode.totem,
                                title: 'Tótem Autoservicio',
                                subtitle: 'Para pedestal de pie en la entrada',
                                icon: Icons.touch_app_rounded,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildModeOption(
                                mode: KioskOperatingMode.table,
                                title: 'Mesa Fija (Table)',
                                subtitle: 'Terminal anclada a mesa fija',
                                icon: Icons.table_restaurant_rounded,
                              ),
                            ),
                          ],
                        ),
                        if (_operatingMode == KioskOperatingMode.table) ...[
                          const SizedBox(height: 18),
                          _buildTextField(
                            key: const Key('admin_table_number_field'),
                            controller: _tableNumberController,
                            label: 'Número de Mesa Asignada',
                            hint: '1',
                            icon: Icons.table_chart_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. NFC Sensor Position Calibrator with LIVE VISUAL PREVIEW
                  _buildSectionCard(
                    title: 'Calibración de Antena NFC (Contactless)',
                    icon: Icons.contactless_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Indica la ubicación física de la antena NFC de esta tableta para guiar a los clientes en el cobro:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Segmented Quadrant Selector
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: NfcQuadrant.values.map((q) {
                            final isSelected = _selectedQuadrant == q;
                            return ChoiceChip(
                              key: Key('nfc_chip_${q.name}'),
                              label: Text('${q.label} ${q.arrow}'),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedQuadrant = q;
                                  });
                                }
                              },
                              selectedColor: primaryColor.withOpacity(0.18),
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? primaryColor
                                    : const Color(0xFF334155),
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? primaryColor
                                    : const Color(0xFFCBD5E1),
                                width: isSelected ? 2 : 1,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // LIVE VISUAL PREVIEW CONTAINER
                        const Text(
                          'Vista Previa en Vivo de la Tableta:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: darkTextColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildLiveNfcPreview(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Hardware & Diagnostics
                  _buildSectionCard(
                    title: 'Diagnósticos de Hardware y Conectividad',
                    icon: Icons.fact_check_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // API Diagnostics
                        _buildDiagnosticItem(
                          title: 'Conexión con Servidor GraphQL',
                          subtitle: 'Verifica la disponibilidad y latencia del backend',
                          buttonKey: const Key('admin_test_api_button'),
                          buttonLabel: 'Probar Conexión con API',
                          buttonIcon: Icons.network_check_rounded,
                          isLoading: _testingApi,
                          onPressed: _testApiConnection,
                          resultWidget: _buildApiResultWidget(),
                        ),
                        const Divider(height: 32),

                        // NFC Diagnostics
                        _buildDiagnosticItem(
                          title: 'Hardware NFC & Stripe Tap to Pay',
                          subtitle: 'Detecta adaptador NFC y estado de emulación',
                          buttonKey: const Key('admin_test_nfc_button'),
                          buttonLabel: 'Probar Lector NFC',
                          buttonIcon: Icons.nfc_rounded,
                          isLoading: _testingNfc,
                          onPressed: _testNfcHardware,
                          resultWidget: _buildNfcResultWidget(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Kiosk Lockdown & Memory Sanitization
                  _buildSectionCard(
                    title: 'Seguridad y Privacidad del Sistema',
                    icon: Icons.security_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LockTask Toggle
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isKioskLocked
                                    ? successColor.withOpacity(0.12)
                                    : const Color(0xFF64748B).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _isKioskLocked
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                color: _isKioskLocked
                                    ? successColor
                                    : const Color(0xFF64748B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isKioskLocked
                                        ? 'Modo Kiosko Activo (LockTask)'
                                        : 'Modo Kiosko Desactivado',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: darkTextColor,
                                    ),
                                  ),
                                  Text(
                                    _isKioskLocked
                                        ? 'La tableta está anclada a la pantalla de la app'
                                        : 'Se permite salir a Android OS para mantenimiento',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              key: const Key('admin_kiosk_lock_toggle_button'),
                              onPressed: _toggleKioskLock,
                              icon: Icon(_isKioskLocked
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded),
                              label: Text(_isKioskLocked
                                  ? 'Desbloquear Tableta'
                                  : 'Bloquear Tableta'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isKioskLocked
                                    ? const Color(0xFF334155)
                                    : primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // Sanitization
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.cleaning_services_rounded,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sanitización de Memoria y PII',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: darkTextColor,
                                    ),
                                  ),
                                  Text(
                                    'Limpia teléfonos, carritos y sesiones residuales de clientes',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const Key('admin_sanitize_memory_button'),
                              onPressed: _sanitizeMemory,
                              icon: const Icon(Icons.delete_sweep_rounded),
                              label: const Text('Sanitizar Memoria'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF3B82F6),
                                side: const BorderSide(
                                    color: Color(0xFF93C5FD)),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('admin_cancel_bottom_button'),
                          onPressed: _exitAdminSettings,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Salir sin Guardar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const Key('admin_save_button'),
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Guardar Configuración'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: primaryColor.withOpacity(0.12),
            child: const Icon(Icons.settings_suggest_rounded,
                color: primaryColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _deviceNameController.text.isNotEmpty
                      ? _deviceNameController.text
                      : 'Terminal El Origen',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: darkTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Modo: ${_operatingMode.label} • Sucursal: ${_branchIdController.text}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _isKioskLocked
                  ? successColor.withOpacity(0.15)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isKioskLocked
                    ? successColor
                    : const Color(0xFFF59E0B),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isKioskLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 16,
                  color: _isKioskLocked ? successColor : const Color(0xFFB45309),
                ),
                const SizedBox(width: 6),
                Text(
                  _isKioskLocked ? 'BLOQUEADO' : 'DESBLOQUEADO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        _isKioskLocked ? successColor : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: darkTextColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required KioskOperatingMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _operatingMode == mode;
    return InkWell(
      key: Key('admin_mode_${mode.name}'),
      onTap: () {
        setState(() {
          _operatingMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? primaryColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primaryColor : darkTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Radio<KioskOperatingMode>(
              value: mode,
              groupValue: _operatingMode,
              activeColor: primaryColor,
              onChanged: (val) {
                if (val != null) setState(() => _operatingMode = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Live visual representation of tablet screen showing where the NFC antenna falls
  Widget _buildLiveNfcPreview() {
    return Container(
      key: const Key('nfc_quadrant_live_preview'),
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Tablet glass
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF334155), width: 8), // Tablet bezel
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Simulated front camera notch
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Grid lines for quadrants
          Center(
            child: Container(
              width: double.infinity,
              height: 1,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          Center(
            child: Container(
              width: 1,
              height: double.infinity,
              color: Colors.white.withOpacity(0.06),
            ),
          ),

          // Interactive Quadrant Targets
          ...NfcQuadrant.values.map((quadrant) {
            final isTarget = _selectedQuadrant == quadrant;
            return Align(
              alignment: quadrant.alignment,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _selectedQuadrant = quadrant;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: isTarget ? 88 : 48,
                    height: isTarget ? 88 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTarget
                          ? primaryColor.withOpacity(0.3)
                          : Colors.white.withOpacity(0.06),
                      border: Border.all(
                        color: isTarget
                            ? primaryColor
                            : Colors.white.withOpacity(0.2),
                        width: isTarget ? 2.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: isTarget
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.contactless_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedQuadrant.arrow,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : Icon(
                              quadrant.icon,
                              color: Colors.white.withOpacity(0.4),
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ),
            );
          }),

          // Pill indicator displaying selected quadrant instructions
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'Antena Configurada: ${_selectedQuadrant.label} (${_selectedQuadrant.instructions})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem({
    required String title,
    required String subtitle,
    required Key buttonKey,
    required String buttonLabel,
    required IconData buttonIcon,
    required bool isLoading,
    required VoidCallback onPressed,
    Widget? resultWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              key: buttonKey,
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(buttonIcon, size: 18),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (resultWidget != null) ...[
          const SizedBox(height: 12),
          resultWidget,
        ],
      ],
    );
  }

  Widget _buildApiResultWidget() {
    if (_apiTestResult == null) return const SizedBox.shrink();
    final isSuccess = _apiTestResult!['success'] == true;
    final latency = _apiTestResult!['latencyMs'] ?? 0;
    final statusCode = _apiTestResult!['statusCode'];
    final error = _apiTestResult!['error'];

    return Container(
      key: const Key('admin_api_test_result'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSuccess
            ? successColor.withOpacity(0.08)
            : errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess ? successColor : errorColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isSuccess ? successColor : errorColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSuccess
                  ? 'Conexión Exitosa ($statusCode OK) • Latencia: ${latency}ms'
                  : 'Fallo de Conexión: ${error ?? 'No se pudo contactar el host'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNfcResultWidget() {
    if (_nfcTestResult == null) return const SizedBox.shrink();
    final hasNfc = _nfcTestResult!['hasNfc'] == true;
    final isEmulator = _nfcTestResult!['isEmulator'] == true;
    final isSimulated = _nfcTestResult!['isSimulated'] == true;
    final isSupported = _nfcTestResult!['isSupported'] == true;

    return Container(
      key: const Key('admin_nfc_test_result'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSupported
            ? successColor.withOpacity(0.08)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSupported ? successColor : const Color(0xFFF59E0B),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSupported ? Icons.check_circle_rounded : Icons.info_rounded,
            color: isSupported ? successColor : const Color(0xFFB45309),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'NFC: ${hasNfc ? "Detectado" : "No detectado"} • Emulador: ${isEmulator ? "Sí" : "No"} • Modo Tap to Pay: ${isSimulated ? "Simulado (Test/Demo)" : "Hardware Nativo"}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSupported
                    ? const Color(0xFF065F46)
                    : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
