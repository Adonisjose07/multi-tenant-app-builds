import 'store_modifier.dart';

class StoreProduct {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String categoryId;
  final List<StoreModifierGroup> modifierGroups;
  final bool isAvailable;

  const StoreProduct({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.categoryId,
    this.modifierGroups = const [],
    this.isAvailable = true,
  });

  String get formattedPrice => '\$${price.toStringAsFixed(2)}';

  bool get hasModifiers => modifierGroups.isNotEmpty;

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['modifierGroups'] as List<dynamic>? ?? [];
    return StoreProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      imageUrl: json['imageUrl']?.toString() ?? json['imagePath']?.toString(),
      categoryId: json['categoryId']?.toString() ?? '',
      modifierGroups: rawGroups
          .map((g) => StoreModifierGroup.fromJson(
              g is Map<String, dynamic> ? g : {}))
          .toList(),
      isAvailable: json['isAvailable'] is bool
          ? json['isAvailable'] as bool
          : (json['branchSettings']?['isAvailable'] is bool
              ? json['branchSettings']['isAvailable'] as bool
              : (json['active'] is bool ? json['active'] as bool : true)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'modifierGroups': modifierGroups.map((g) => g.toJson()).toList(),
      'isAvailable': isAvailable,
    };
  }

  StoreProduct copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? categoryId,
    List<StoreModifierGroup>? modifierGroups,
    bool? isAvailable,
  }) {
    return StoreProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId ?? this.categoryId,
      modifierGroups: modifierGroups ?? this.modifierGroups,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreProduct &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
