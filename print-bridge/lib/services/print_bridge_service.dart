import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

enum BridgeConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

enum PrinterTransportType {
  network,
  bluetooth,
}

class PrintBridgeService {
  static const MethodChannel _btChannel =
      MethodChannel('com.elorigen.printcompanion/bluetooth');

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  bool _isDisposed = false;
  String _apiWsUrl = '';
  String _branchId = '';
  String _token = '';
  String _defaultPrinterIp = '192.168.1.100';
  int _defaultPrinterPort = 9100;
  String _defaultPrinterMac = '';
  PrinterTransportType _defaultTransport = PrinterTransportType.network;

  final ValueNotifier<BridgeConnectionStatus> statusNotifier =
      ValueNotifier<BridgeConnectionStatus>(BridgeConnectionStatus.disconnected);
  final ValueNotifier<String> logNotifier =
      ValueNotifier<String>('Listo para conectar');
  final ValueNotifier<List<String>> logsListNotifier =
      ValueNotifier<List<String>>([]);
  final ValueNotifier<int> printCountNotifier = ValueNotifier<int>(0);

  bool get isConnected =>
      statusNotifier.value == BridgeConnectionStatus.connected;

  void updateConfig({
    required String apiUrl,
    required String branchId,
    required String token,
    String? defaultPrinterIp,
    int? defaultPrinterPort,
    String? defaultPrinterMac,
    PrinterTransportType? defaultTransport,
  }) {
    String wsBase = apiUrl.trim();
    if (wsBase.startsWith('https://')) {
      wsBase = wsBase.replaceFirst('https://', 'wss://');
    } else if (wsBase.startsWith('http://')) {
      wsBase = wsBase.replaceFirst('http://', 'ws://');
    } else if (!wsBase.startsWith('ws://') && !wsBase.startsWith('wss://')) {
      wsBase = 'wss://$wsBase';
    }
    if (wsBase.endsWith('/')) {
      wsBase = wsBase.substring(0, wsBase.length - 1);
    }

    _apiWsUrl = '$wsBase/ws/print-bridge';
    _branchId = branchId.trim();
    _token = token.trim();
    if (defaultPrinterIp != null) _defaultPrinterIp = defaultPrinterIp.trim();
    if (defaultPrinterPort != null) _defaultPrinterPort = defaultPrinterPort;
    if (defaultPrinterMac != null) _defaultPrinterMac = defaultPrinterMac.trim();
    if (defaultTransport != null) _defaultTransport = defaultTransport;
  }

  void start() {
    _isDisposed = false;
    _connect();
  }

  void stop() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    statusNotifier.value = BridgeConnectionStatus.disconnected;
    _log('Túnel detenido manualmente');
  }

  Future<void> _connect() async {
    if (_isDisposed) return;
    if (_apiWsUrl.isEmpty || _branchId.isEmpty || _token.isEmpty) {
      statusNotifier.value = BridgeConnectionStatus.disconnected;
      _log('Configura la URL, Branch ID y Token de Seguridad');
      return;
    }

    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();

    statusNotifier.value = BridgeConnectionStatus.connecting;
    _log('Conectando túnel autenticado con el servidor...');

    try {
      final uri = Uri.parse('$_apiWsUrl?branchId=$_branchId&token=$_token');
      final ws = await WebSocket.connect(
        uri.toString(),
        compression: CompressionOptions.compressionOff,
      ).timeout(const Duration(seconds: 15));

      _channel = IOWebSocketChannel(ws);

      _subscription = _channel!.stream.listen(
        (data) {
          _handleIncomingMessage(data);
        },
        onDone: () {
          final code = _channel?.closeCode;
          final reason = _channel?.closeReason;
          if (code == 1008) {
            _log('❌ Autenticación rechazada (Código 1008): Token o Branch ID inválidos en el servidor.');
          } else if (code != null) {
            _log('⚠️ Conexión cerrada por el servidor (Código $code${reason != null && reason.isNotEmpty ? ": $reason" : ""})');
          } else {
            _log('Conexión cerrada por el servidor');
          }
          _scheduleReconnect();
        },
        onError: (err) {
          _log('❌ Error en túnel WebSocket: $err');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      statusNotifier.value = BridgeConnectionStatus.connecting;
      _log('Esperando confirmación de enlace con el servidor...');

      // Heartbeat Keepalive
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
        if (_channel != null && isConnected) {
          try {
            _channel!.sink.add(jsonEncode({'type': 'PONG'}));
          } catch (_) {}
        }
      });
    } catch (e) {
      _log('Error conectando túnel: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    statusNotifier.value = BridgeConnectionStatus.disconnected;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _log('Reconectando en 5 segundos...');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connect();
    });
  }

  Future<void> _handleIncomingMessage(dynamic raw) async {
    try {
      final messageStr = raw.toString();
      final Map<String, dynamic> data =
          jsonDecode(messageStr) as Map<String, dynamic>;

      if (data['type'] == 'CONNECTED') {
        statusNotifier.value = BridgeConnectionStatus.connected;
        _log('✅ Túnel autenticado y confirmado por el servidor (Sucursal: ${data['branchId']})');
        return;
      }

      if (data['type'] == 'PRINT_JOB') {
        final String messageId = data['messageId'] ?? '';
        final String payloadBase64 = data['payloadBase64'] ?? '';
        final String orderId = data['orderId'] ?? '---';
        final String branchId = data['branchId'] ?? _branchId;
        final dynamic timestampRaw = data['timestamp'];
        final int timestamp = (timestampRaw is int)
            ? timestampRaw
            : int.tryParse(timestampRaw.toString()) ?? 0;
        final String signature = data['signature'] ?? '';

        // Determine transport: default to local configured or message spec
        final String connectionType = (data['connectionType'] ??
                (_defaultTransport == PrinterTransportType.bluetooth
                    ? 'BLUETOOTH'
                    : 'NETWORK'))
            .toString()
            .toUpperCase();

        final String printerIp = data['printerIp'] ?? _defaultPrinterIp;
        final int printerPort = (data['printerPort'] is int)
            ? data['printerPort']
            : int.tryParse(data['printerPort'].toString()) ??
                _defaultPrinterPort;
        final String printerMac = data['printerMac'] ?? _defaultPrinterMac;

        // 1. Anti-Replay: Verify message is not expired (max 60 seconds)
        final int now = DateTime.now().millisecondsSinceEpoch;
        if (timestamp == 0 || (now - timestamp).abs() > 60000) {
          _log('🚨 ALERTA: Mensaje expirado o desfasado descartado (Anti-Replay).');
          _sendAck(messageId, 'SECURITY_EXPIRED');
          return;
        }

        // 2. Cryptographic HMAC-SHA256 signature verification (STRICT CONTRACT INVARIANT)
        final String dataToVerify =
            '$branchId:$orderId:$timestamp:$payloadBase64';
        final String computedSig = Hmac(sha256, utf8.encode(_token))
            .convert(utf8.encode(dataToVerify))
            .toString();

        if (signature.isEmpty || computedSig != signature) {
          _log('🛑 ALERTA DE SEGURIDAD: Firma HMAC inválida. Mensaje no autorizado descartado.');
          _sendAck(messageId, 'INVALID_SIGNATURE');
          return; // Fail-Closed: Never open socket to printer!
        }

        final rawBytes = base64Decode(payloadBase64);
        bool success = false;

        // 3. Multi-Transport Routing
        if (connectionType == 'BLUETOOTH') {
          if (printerMac.isEmpty) {
            _log('🛑 ALERTA: Dirección MAC Bluetooth no configurada.');
            _sendAck(messageId, 'BLUETOOTH_NO_MAC');
            return;
          }
          _log('📥 Comanda firmada recibida para orden #$orderId. Enviando por Bluetooth a $printerMac...');
          success = await printBluetoothRawBytes(printerMac, rawBytes);
        } else {
          // Transport: NETWORK (Wi-Fi / Ethernet LAN TCP)
          // Anti-SSRF: Verify printer IP belongs to private LAN RFC 1918 range
          if (!_isPrivateLanIp(printerIp)) {
            _log('🛑 ALERTA: IP $printerIp rechazada por estar fuera del rango LAN privado.');
            _sendAck(messageId, 'SECURITY_INVALID_IP');
            return;
          }
          _log('📥 Comanda firmada recibida para orden #$orderId. Enviando por LAN a $printerIp:$printerPort...');
          success = await printRawBytes(
            printerIp: printerIp,
            printerPort: printerPort,
            bytes: rawBytes,
          );
        }

        if (success) {
          printCountNotifier.value = printCountNotifier.value + 1;
          _log('🖨️ Comanda #$orderId impresa con éxito');
          _sendAck(messageId, 'SUCCESS');
        } else {
          _log('❌ Falló el envío a la impresora térmica ($connectionType)');
          _sendAck(messageId, 'PRINTER_ERROR');
        }
      }
    } catch (e) {
      _log('Error procesando mensaje: $e');
    }
  }

  bool _isPrivateLanIp(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) return false;
    final octets = parts.map((p) => int.tryParse(p)).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) return false;

    // 10.0.0.0/8
    if (octets[0] == 10) return true;
    // 172.16.0.0/12
    if (octets[0] == 172 && octets[1]! >= 16 && octets[1]! <= 31) return true;
    // 192.168.0.0/16
    if (octets[0] == 192 && octets[1] == 168) return true;

    return false;
  }

  void _sendAck(String messageId, String status) {
    if (_channel != null && isConnected) {
      try {
        _channel!.sink.add(jsonEncode({
          'type': 'PRINT_ACK',
          'messageId': messageId,
          'status': status,
        }));
      } catch (_) {}
    }
  }

  /// Sends raw ESC/POS bytes over LAN TCP Socket (Wi-Fi / Ethernet port 9100)
  Future<bool> printRawBytes({
    required String printerIp,
    int printerPort = 9100,
    required Uint8List bytes,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        printerIp,
        printerPort,
        timeout: const Duration(seconds: 4),
      );
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      _log('Error de socket TCP ($printerIp:$printerPort): $e');
      try {
        socket?.destroy();
      } catch (_) {}
      return false;
    }
  }

  /// Sends raw ESC/POS bytes over Bluetooth SPP via native Android MethodChannel
  Future<bool> printBluetoothRawBytes(String address, Uint8List bytes) async {
    try {
      final bool? result = await _btChannel.invokeMethod<bool>(
        'printBluetoothBytes',
        {
          'address': address,
          'bytes': bytes,
        },
      );
      return result ?? false;
    } catch (e) {
      _log('Error enviando datos por Bluetooth ($address): $e');
      return false;
    }
  }

  /// Fetches paired Bluetooth devices on the Android device
  Future<List<Map<String, String>>> getPairedBluetoothDevices() async {
    try {
      final List<dynamic>? result =
          await _btChannel.invokeMethod<List<dynamic>>('getPairedDevices');
      if (result == null) return [];
      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return {
          'name': map['name']?.toString() ?? 'Dispositivo Desconocido',
          'address': map['address']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      _log('Error obteniendo dispositivos Bluetooth: $e');
      return [];
    }
  }

  /// Send test comanda to verify physical printer connectivity (Wi-Fi, Ethernet or Bluetooth)
  Future<bool> sendTestPrint({
    required PrinterTransportType transportType,
    String? printerIp,
    int? printerPort,
    String? printerMac,
  }) async {
    _log('Imprimiendo ticket de prueba (${transportType.name.toUpperCase()})...');

    final List<int> testBytes = [];
    // ESC @ Init
    testBytes.addAll([0x1B, 0x40]);
    // ESC a 1 Center
    testBytes.addAll([0x1B, 0x61, 0x01]);
    // GS ! 0x11 Double size
    testBytes.addAll([0x1D, 0x21, 0x11]);
    testBytes.addAll(utf8.encode('EL ORIGEN\n'));
    // GS ! 0x00 Normal
    testBytes.addAll([0x1D, 0x21, 0x00]);
    testBytes.addAll(utf8.encode(
        'TEST IMPRESION ${transportType == PrinterTransportType.bluetooth ? "BLUETOOTH" : "WIFI/ETHERNET"}\n'));
    testBytes.addAll(utf8.encode('--------------------------------\n'));
    testBytes.addAll(utf8.encode('Túnel Criptográfico HMAC-SHA256 OK\n'));
    testBytes.addAll(utf8.encode('Fecha: ${DateTime.now().toLocal()}\n'));
    testBytes.addAll(utf8.encode('--------------------------------\n\n\n\n'));
    // ESC B 2 2 Buzzer (2 beeps)
    testBytes.addAll([0x1B, 0x42, 0x02, 0x02]);
    // GS V 0 Cut
    testBytes.addAll([0x1D, 0x56, 0x00]);

    final rawBytes = Uint8List.fromList(testBytes);

    bool ok = false;
    if (transportType == PrinterTransportType.bluetooth) {
      final mac = printerMac ?? _defaultPrinterMac;
      if (mac.isEmpty) {
        _log('❌ Selecciona o introduce la dirección MAC de la impresora Bluetooth');
        return false;
      }
      ok = await printBluetoothRawBytes(mac, rawBytes);
    } else {
      final ip = printerIp ?? _defaultPrinterIp;
      final port = printerPort ?? _defaultPrinterPort;
      ok = await printRawBytes(
        printerIp: ip,
        printerPort: port,
        bytes: rawBytes,
      );
    }

    if (ok) {
      _log('✅ Ticket de prueba emitido correctamente');
    }
    return ok;
  }

  void _log(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$time] $message';
    logNotifier.value = entry;
    final updated = List<String>.from(logsListNotifier.value)..add(entry);
    if (updated.length > 200) {
      updated.removeAt(0);
    }
    logsListNotifier.value = updated;
    if (kDebugMode) {
      print(entry);
    }
  }

  void clearLogs() {
    logsListNotifier.value = [];
    logNotifier.value = 'Registro de logs limpiado';
  }

  void dispose() {
    stop();
    statusNotifier.dispose();
    logNotifier.dispose();
    logsListNotifier.dispose();
    printCountNotifier.dispose();
  }
}
