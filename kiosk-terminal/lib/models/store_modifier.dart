class StoreModifierOption {
  final String id;
  final String name;
  final double price;
  final bool isDefault;

  const StoreModifierOption({
    required this.id,
    required this.name,
    this.price = 0.0,
    this.isDefault = false,
  });

  String get formattedPrice {
    if (price <= 0.0) return 'Gratis';
    return '+\$${price.toStringAsFixed(2)}';
  }

  factory StoreModifierOption.fromJson(Map<String, dynamic> json) {
    return StoreModifierOption(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      isDefault: json['isDefault'] is bool ? json['isDefault'] as bool : false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'isDefault': isDefault,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreModifierOption &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}

class StoreModifierGroup {
  final String id;
  final String name;
  final int minSelection;
  final int maxSelection;
  final List<StoreModifierOption> options;

  const StoreModifierGroup({
    required this.name,
    String? id,
    this.minSelection = 0,
    this.maxSelection = 1,
    this.options = const [],
  }) : id = id ?? name;

  bool get isRequired => minSelection > 0;
  bool get isSingleSelect => maxSelection == 1;
  bool get isMultiSelect => maxSelection > 1;

  String get requirementBadge {
    if (isRequired) {
      if (minSelection == maxSelection) {
        return 'Obligatorio (Selecciona $minSelection)';
      }
      return 'Obligatorio (Mínimo $minSelection)';
    }
    if (maxSelection > 1) {
      return 'Opcional (Hasta $maxSelection)';
    }
    return 'Opcional (Máximo 1)';
  }

  factory StoreModifierGroup.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return StoreModifierGroup(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      minSelection: (json['minSelection'] is num)
          ? (json['minSelection'] as num).toInt()
          : 0,
      maxSelection: (json['maxSelection'] is num)
          ? (json['maxSelection'] as num).toInt()
          : 1,
      options: rawOptions
          .map((opt) => StoreModifierOption.fromJson(
              opt is Map<String, dynamic> ? opt : {}))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'minSelection': minSelection,
      'maxSelection': maxSelection,
      'options': options.map((opt) => opt.toJson()).toList(),
    };
  }
}
