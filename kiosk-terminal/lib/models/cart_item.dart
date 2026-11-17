import 'store_product.dart';
import 'store_modifier.dart';

class CartItem {
  final String id;
  final StoreProduct product;
  final int quantity;
  final List<StoreModifierOption> selectedModifiers;
  final String? specialNotes;

  const CartItem({
    required this.id,
    required this.product,
    this.quantity = 1,
    this.selectedModifiers = const [],
    this.specialNotes,
  });

  /// Sum of selected modifier prices per unit
  double get modifiersPrice =>
      selectedModifiers.fold(0.0, (sum, mod) => sum + mod.price);

  /// Single item price including modifiers
  double get unitPrice => product.price + modifiersPrice;

  /// Total price for this line item based on quantity
  double get totalPrice => unitPrice * quantity;

  String get formattedUnitPrice => '\$${unitPrice.toStringAsFixed(2)}';
  String get formattedTotalPrice => '\$${totalPrice.toStringAsFixed(2)}';

  bool get hasModifiers => selectedModifiers.isNotEmpty;

  String get modifiersDescription =>
      selectedModifiers.map((m) => m.name).join(', ');

  CartItem copyWith({
    String? id,
    StoreProduct? product,
    int? quantity,
    List<StoreModifierOption>? selectedModifiers,
    String? specialNotes,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      specialNotes: specialNotes ?? this.specialNotes,
    );
  }

  /// Determines if another selection has the identical product, modifiers, and notes
  bool hasSameConfiguration(
    StoreProduct otherProduct,
    List<StoreModifierOption> otherModifiers,
    String? otherNotes,
  ) {
    if (product.id != otherProduct.id) return false;
    if ((specialNotes?.trim() ?? '') != (otherNotes?.trim() ?? '')) return false;
    if (selectedModifiers.length != otherModifiers.length) return false;

    final thisModIds = selectedModifiers.map((m) => m.id).toSet();
    final otherModIds = otherModifiers.map((m) => m.id).toSet();
    return thisModIds.containsAll(otherModIds);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': product.id,
      'productName': product.name,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'modifiers': selectedModifiers.map((m) => m.toJson()).toList(),
      'specialNotes': specialNotes,
    };
  }
}
