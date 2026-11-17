enum DiningMode {
  dineIn('Para Comer Aquí', 'dine_in'),
  takeaway('Para Llevar', 'takeaway');

  final String label;
  final String code;

  const DiningMode(this.label, this.code);
}

extension DiningModeExtension on DiningMode {
  String get displayLabel => label;
  String get deliveryCode => code;
}

class KioskSession {
  final String phone;
  final String? email;
  final DiningMode? diningMode;
  final String? tableOrPagerNumber;
  final DateTime startedAt;

  KioskSession({
    this.phone = '',
    this.email,
    this.diningMode,
    this.tableOrPagerNumber,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  /// Validates that phone has at least 7 numeric digits (Fitts/Kiosk validation)
  bool get isPhoneValid {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 7;
  }

  /// Optional email validation: valid if empty/null or matches standard email regex
  bool get isEmailValid {
    if (email == null || email!.trim().isEmpty) return true;
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email!.trim());
  }

  bool get isDineIn => diningMode == DiningMode.dineIn;
  bool get isTakeaway => diningMode == DiningMode.takeaway;

  /// Returns cleaned raw phone digits
  String get rawPhone => phone.replaceAll(RegExp(r'\D'), '');

  /// Formatted presentation string for phone
  String get formattedPhone {
    final digits = rawPhone;
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    }
    if (digits.length <= 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return '+${digits.substring(0, digits.length - 10)} (${digits.substring(digits.length - 10, digits.length - 7)}) ${digits.substring(digits.length - 7, digits.length - 4)}-${digits.substring(digits.length - 4)}';
  }

  KioskSession copyWith({
    String? phone,
    String? email,
    DiningMode? diningMode,
    String? tableOrPagerNumber,
    bool clearEmail = false,
    bool clearTableOrPager = false,
  }) {
    return KioskSession(
      phone: phone ?? this.phone,
      email: clearEmail ? null : (email ?? this.email),
      diningMode: diningMode ?? this.diningMode,
      tableOrPagerNumber: clearTableOrPager
          ? null
          : (tableOrPagerNumber ?? this.tableOrPagerNumber),
      startedAt: startedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': rawPhone,
      'email': email?.trim(),
      'diningMode': diningMode?.code,
      'tableOrPagerNumber': tableOrPagerNumber?.trim(),
      'startedAt': startedAt.toIso8601String(),
    };
  }
}
