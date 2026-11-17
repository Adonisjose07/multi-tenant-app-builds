import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Antenna positioning quadrant for Android tablets.
/// Tablets place NFC antennae in different physical locations (top-right,
/// top-left, top-edge center, center of glass, or attached USB/BLE reader).
enum NfcQuadrant {
  topRight,
  topLeft,
  topCenter,
  screenCenter,
  externalReader,
}

extension NfcQuadrantExtension on NfcQuadrant {
  /// Visual alignment inside the radar container or viewport
  Alignment get alignment {
    switch (this) {
      case NfcQuadrant.topRight:
        return const Alignment(0.80, -0.80);
      case NfcQuadrant.topLeft:
        return const Alignment(-0.80, -0.80);
      case NfcQuadrant.topCenter:
        return const Alignment(0.0, -0.85);
      case NfcQuadrant.screenCenter:
        return Alignment.center;
      case NfcQuadrant.externalReader:
        return const Alignment(0.90, 0.0);
    }
  }

  /// Readable human label
  String get label {
    switch (this) {
      case NfcQuadrant.topRight:
        return 'Esquina Superior Derecha';
      case NfcQuadrant.topLeft:
        return 'Esquina Superior Izquierda';
      case NfcQuadrant.topCenter:
        return 'Borde Superior Central';
      case NfcQuadrant.screenCenter:
        return 'Centro de la Pantalla';
      case NfcQuadrant.externalReader:
        return 'Lector Lateral Externo';
    }
  }

  /// Customer instruction message with directional hint
  String get instructions {
    switch (this) {
      case NfcQuadrant.topRight:
        return 'Acerca tu tarjeta aquí ↗️';
      case NfcQuadrant.topLeft:
        return 'Acerca tu tarjeta aquí ↖️';
      case NfcQuadrant.topCenter:
        return 'Acerca tu tarjeta aquí ⬆️';
      case NfcQuadrant.screenCenter:
        return 'Acerca tu tarjeta al centro 🎯';
      case NfcQuadrant.externalReader:
        return 'Usa el lector lateral adjunto 💳';
    }
  }

  /// Directional arrow or emoji indicator
  String get arrow {
    switch (this) {
      case NfcQuadrant.topRight:
        return '↗️';
      case NfcQuadrant.topLeft:
        return '↖️';
      case NfcQuadrant.topCenter:
        return '⬆️';
      case NfcQuadrant.screenCenter:
        return '🎯';
      case NfcQuadrant.externalReader:
        return '➡️';
    }
  }

  /// Serialization string code
  String get code => name;

  /// Icon representing the reader type / location
  IconData get icon {
    switch (this) {
      case NfcQuadrant.externalReader:
        return Icons.credit_card_rounded;
      default:
        return Icons.contactless_rounded;
    }
  }

  /// Parses a string safely into an [NfcQuadrant], defaulting to [topRight]
  static NfcQuadrant fromString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return NfcQuadrant.topRight;
    }
    final normalized = value.trim().toLowerCase();
    for (final q in NfcQuadrant.values) {
      if (q.name.toLowerCase() == normalized) {
        return q;
      }
    }
    // Also match legacy / snake_case variants if any
    switch (normalized) {
      case 'top_right':
        return NfcQuadrant.topRight;
      case 'top_left':
        return NfcQuadrant.topLeft;
      case 'top_center':
        return NfcQuadrant.topCenter;
      case 'screen_center':
      case 'center':
        return NfcQuadrant.screenCenter;
      case 'external_reader':
      case 'external':
        return NfcQuadrant.externalReader;
      default:
        return NfcQuadrant.topRight;
    }
  }

  /// SharedPreferences key for kiosk calibration
  static const String prefsKey = 'kiosk_nfc_quadrant';

  /// Loads the stored NFC quadrant from device preferences
  static Future<NfcQuadrant> loadConfigured() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(prefsKey);
      return fromString(val);
    } catch (_) {
      return NfcQuadrant.topRight;
    }
  }

  /// Persists the calibrated NFC quadrant
  static Future<void> saveConfigured(NfcQuadrant quadrant) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, quadrant.name);
    } catch (_) {}
  }
}
