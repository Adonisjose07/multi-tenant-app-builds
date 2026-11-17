import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/brand_config.dart';
import 'services/print_bridge_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrintCompanionApp());
}

class PrintCompanionApp extends StatelessWidget {
  const PrintCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = BrandConfig.primaryColor;
    return MaterialApp(
      title: BrandConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          surface: BrandConfig.surfaceColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const PrintCompanionHomePage(),
    );
  }
}

class PrintCompanionHomePage extends StatefulWidget {
  const PrintCompanionHomePage({super.key});

  @override
  State<PrintCompanionHomePage> createState() => _PrintCompanionHomePageState();
}

class _PrintCompanionHomePageState extends State<PrintCompanionHomePage> {
  final PrintBridgeService _bridgeService = PrintBridgeService();

  final TextEditingController _apiUrlController = TextEditingController(
    text: BrandConfig.apiUrl,
  );
  final TextEditingController _branchIdController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _printerIpController = TextEditingController(
    text: '192.168.1.100',
  );
  final TextEditingController _printerPortController = TextEditingController(
    text: '9100',
  );
  final TextEditingController _printerMacController = TextEditingController();

  PrinterTransportType _transportType = PrinterTransportType.network;
  List<Map<String, String>> _pairedBtDevices = [];
  bool _isLoading = true;
  bool _isAutoConnect = true;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTransport = prefs.getString('transport_type') ?? 'network';

    setState(() {
      _apiUrlController.text =
          prefs.getString('api_url') ?? BrandConfig.apiUrl;
      _branchIdController.text = prefs.getString('branch_id') ?? '';
      _tokenController.text = prefs.getString('print_token') ?? '';
      _printerIpController.text =
          prefs.getString('printer_ip') ?? '192.168.1.100';
      _printerPortController.text = prefs.getString('printer_port') ?? '9100';
      _printerMacController.text = prefs.getString('printer_mac') ?? '';
      _transportType = savedTransport == 'bluetooth'
          ? PrinterTransportType.bluetooth
          : PrinterTransportType.network;
      _isAutoConnect = prefs.getBool('auto_connect') ?? true;
      _isLoading = false;
    });

    _refreshBluetoothDevices();

    if (_isAutoConnect &&
        _branchIdController.text.isNotEmpty &&
        _tokenController.text.isNotEmpty) {
      _startBridge();
    }
  }

  Future<void> _refreshBluetoothDevices() async {
    final devices = await _bridgeService.getPairedBluetoothDevices();
    setState(() {
      _pairedBtDevices = devices;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', _apiUrlController.text.trim());
    await prefs.setString('branch_id', _branchIdController.text.trim());
    await prefs.setString('print_token', _tokenController.text.trim());
    await prefs.setString('printer_ip', _printerIpController.text.trim());
    await prefs.setString('printer_port', _printerPortController.text.trim());
    await prefs.setString('printer_mac', _printerMacController.text.trim());
    await prefs.setString(
        'transport_type',
        _transportType == PrinterTransportType.bluetooth
            ? 'bluetooth'
            : 'network');
    await prefs.setBool('auto_connect', _isAutoConnect);
  }

  void _startBridge() {
    _savePreferences();
    _bridgeService.updateConfig(
      apiUrl: _apiUrlController.text.trim(),
      branchId: _branchIdController.text.trim(),
      token: _tokenController.text.trim(),
      defaultPrinterIp: _printerIpController.text.trim(),
      defaultPrinterPort:
          int.tryParse(_printerPortController.text.trim()) ?? 9100,
      defaultPrinterMac: _printerMacController.text.trim(),
      defaultTransport: _transportType,
    );
    _bridgeService.start();
  }

  void _stopBridge() {
    _bridgeService.stop();
  }

  Future<void> _testPrinter() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _bridgeService.sendTestPrint(
      transportType: _transportType,
      printerIp: _printerIpController.text.trim(),
      printerPort: int.tryParse(_printerPortController.text.trim()) ?? 9100,
      printerMac: _printerMacController.text.trim(),
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '✅ Ticket de prueba emitido correctamente (${_transportType.name.toUpperCase()})'
              : '❌ Error: No se pudo comunicar con la impresora térmica',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  void _copyLogs() {
    final logs = _bridgeService.logsListNotifier.value.join('\n');
    if (logs.isEmpty) return;
    Clipboard.setData(ClipboardData(text: logs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Registro de logs copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _bridgeService.dispose();
    _apiUrlController.dispose();
    _branchIdController.dispose();
    _tokenController.dispose();
    _printerIpController.dispose();
    _printerPortController.dispose();
    _printerMacController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.print, color: BrandConfig.primaryColor),
            const SizedBox(width: 8),
            Text(BrandConfig.appName),
          ],
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _bridgeService.printCountNotifier,
            builder: (context, count, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Chip(
                    avatar: const Icon(Icons.receipt_long, size: 16),
                    label: Text('$count tickets'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            ValueListenableBuilder<BridgeConnectionStatus>(
              valueListenable: _bridgeService.statusNotifier,
              builder: (context, status, _) {
                Color statusColor;
                String statusText;
                IconData statusIcon;

                switch (status) {
                  case BridgeConnectionStatus.connected:
                    statusColor = Colors.green;
                    statusText = 'Túnel Autenticado & En Línea';
                    statusIcon = Icons.verified_user;
                    break;
                  case BridgeConnectionStatus.connecting:
                    statusColor = Colors.orange;
                    statusText = 'Verificando credenciales con el servidor...';
                    statusIcon = Icons.sync;
                    break;
                  case BridgeConnectionStatus.disconnected:
                  case BridgeConnectionStatus.error:
                    statusColor = Colors.red;
                    statusText = 'Túnel Desconectado';
                    statusIcon = Icons.cancel;
                    break;
                }

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: statusColor, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.2),
                          radius: 24,
                          child: Icon(statusIcon, color: statusColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ValueListenableBuilder<String>(
                                valueListenable: _bridgeService.logNotifier,
                                builder: (context, log, _) {
                                  return Text(
                                    log,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Controls
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<BridgeConnectionStatus>(
                    valueListenable: _bridgeService.statusNotifier,
                    builder: (context, status, _) {
                      final isConn =
                          status == BridgeConnectionStatus.connected;
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConn
                              ? Colors.red.shade700
                              : BrandConfig.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isConn ? _stopBridge : _startBridge,
                        icon: Icon(isConn ? Icons.stop : Icons.play_arrow),
                        label: Text(
                          isConn ? 'Detener Túnel' : 'Conectar Túnel',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                  ),
                  onPressed: _testPrinter,
                  icon: const Icon(Icons.print),
                  label: const Text('Probar Impresora'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Thermal Printer Transport Selector
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo de Conexión de la Impresora',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<PrinterTransportType>(
                      segments: const [
                        ButtonSegment<PrinterTransportType>(
                          value: PrinterTransportType.network,
                          icon: Icon(Icons.wifi),
                          label: Text('Wi-Fi / Ethernet'),
                        ),
                        ButtonSegment<PrinterTransportType>(
                          value: PrinterTransportType.bluetooth,
                          icon: Icon(Icons.bluetooth),
                          label: Text('Bluetooth'),
                        ),
                      ],
                      selected: {_transportType},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _transportType = newSelection.first;
                        });
                        _savePreferences();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_transportType == PrinterTransportType.network) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _printerIpController,
                              decoration: const InputDecoration(
                                labelText: 'IP de Impresora en Red LAN',
                                hintText: '192.168.1.100',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lan),
                              ),
                              onChanged: (_) => _savePreferences(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _printerPortController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Puerto',
                                hintText: '9100',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _savePreferences(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Puerto estándar ESC/POS: 9100. Compatible con impresoras térmicas conectadas por Wi-Fi o cable Ethernet.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _printerMacController,
                              decoration: const InputDecoration(
                                labelText: 'Dirección MAC Bluetooth',
                                hintText: '00:11:22:33:44:55',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.bluetooth_searching),
                              ),
                              onChanged: (_) => _savePreferences(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Buscar Dispositivos Vinculados',
                            onPressed: _refreshBluetoothDevices,
                          ),
                        ],
                      ),
                      if (_pairedBtDevices.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Dispositivos Bluetooth Vinculados:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _pairedBtDevices.map((dev) {
                            final name = dev['name'] ?? '';
                            final addr = dev['address'] ?? '';
                            final isSelected =
                                _printerMacController.text.trim() == addr;
                            return ChoiceChip(
                              label: Text('$name ($addr)'),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _printerMacController.text = addr;
                                  });
                                  _savePreferences();
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Server Security Credentials
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Credenciales de Túnel Seguro (El Origen Cloud)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL de la API (Cloud VPS)',
                        hintText: 'https://apimono.elorigen.restaurant',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cloud),
                      ),
                      onChanged: (_) => _savePreferences(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _branchIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID de Sucursal (branchId)',
                        hintText: 'Ej. 66f1234567890abcdef',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.storefront),
                      ),
                      onChanged: (_) => _savePreferences(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tokenController,
                      obscureText: _obscureToken,
                      decoration: InputDecoration(
                        labelText:
                            'Token de Impresión de Sucursal (HMAC-SHA256)',
                        hintText:
                            'Pega el token copiado del monitor de comandas',
                        helperText: _tokenController.text.trim().length == 64
                            ? 'Token verificado (64 caracteres) ✅'
                            : (_tokenController.text.trim().isEmpty
                                ? 'El token debe tener 64 caracteres'
                                : '⚠️ Longitud: ${_tokenController.text.trim().length}/64 caracteres (incompleto)'),
                        helperStyle: TextStyle(
                          color: _tokenController.text.trim().length == 64
                              ? Colors.green
                              : (_tokenController.text.trim().isEmpty
                                  ? Colors.grey
                                  : Colors.orange),
                        ),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.security),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureToken = !_obscureToken;
                            });
                          },
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _savePreferences();
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Conectar automáticamente al abrir'),
                      subtitle: const Text(
                        'Inicia el túnel verificado con firma criptográfica al abrir la app',
                      ),
                      value: _isAutoConnect,
                      onChanged: (val) {
                        setState(() {
                          _isAutoConnect = val;
                        });
                        _savePreferences();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Live Diagnostics & Log Terminal Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.terminal, color: BrandConfig.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Consola de Diagnóstico en Vivo',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: 'Copiar todo el registro',
                              onPressed: _copyLogs,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Limpiar logs',
                              onPressed: () => _bridgeService.clearLogs(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade800),
                      ),
                      child: ValueListenableBuilder<List<String>>(
                        valueListenable: _bridgeService.logsListNotifier,
                        builder: (context, logs, _) {
                          if (logs.isEmpty) {
                            return const Center(
                              child: Text(
                                'Sin eventos registrados. Conecta el túnel para monitorear el tráfico.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            reverse: true,
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final line = logs[logs.length - 1 - index];
                              Color textColor = Colors.white70;
                              if (line.contains('❌') || line.contains('Error') || line.contains('ALERTA')) {
                                textColor = Colors.redAccent;
                              } else if (line.contains('✅')) {
                                textColor = Colors.lightGreenAccent;
                              } else if (line.contains('⚠️') || line.contains('Reconectando')) {
                                textColor = Colors.amberAccent;
                              } else if (line.contains('📥') || line.contains('🖨️')) {
                                textColor = Colors.cyanAccent;
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  line,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Colors.white,
                                  ).copyWith(color: textColor),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
