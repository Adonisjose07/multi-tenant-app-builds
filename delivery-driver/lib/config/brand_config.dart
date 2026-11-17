import 'package:flutter/material.dart';

/// Compile-time and runtime white-label branding configuration.
/// Values can be overridden during CI/CD builds using `--dart-define`.
class BrandConfig {
  const BrandConfig._();

  static const String tenantSlug = String.fromEnvironment(
    'TENANT_SLUG',
    defaultValue: 'default',
  );

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Delivery Driver',
  );

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:5050',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://10.0.2.2:5050/graphql',
  );

  static const String primaryColorHex = String.fromEnvironment(
    'PRIMARY_COLOR',
    defaultValue: '#EA581E',
  );

  static const String surfaceColorHex = String.fromEnvironment(
    'SURFACE_COLOR',
    defaultValue: '#F8FAFC',
  );

  static const String logoUrl = String.fromEnvironment(
    'LOGO_URL',
    defaultValue: '',
  );

  static Color parseHexColor(String hex, Color fallback) {
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length == 6) {
      final parsed = int.tryParse('FF$cleaned', radix: 16);
      if (parsed != null) return Color(parsed);
    } else if (cleaned.length == 8) {
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }

  static Color get primaryColor =>
      parseHexColor(primaryColorHex, const Color(0xFFEA581E));

  static Color get surfaceColor =>
      parseHexColor(surfaceColorHex, const Color(0xFFF8FAFC));
}
