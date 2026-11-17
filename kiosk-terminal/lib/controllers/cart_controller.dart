import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/store_modifier.dart';
import '../models/store_product.dart';

class CartController extends ChangeNotifier {
  final List<CartItem> _items = [];
  double _taxRate = 0.0; // Configurable tax rate (e.g. 0.07 for 7%)
  double _tipAmount = 0.0;

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  int get totalItemCount => itemCount;

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  double get subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get taxRate => _taxRate;
  double get taxAmount => subtotal * _taxRate;
  double get tipAmount => _tipAmount;

  double get total => subtotal + taxAmount + tipAmount;

  String get formattedSubtotal => '\$${subtotal.toStringAsFixed(2)}';
  String get formattedTax => '\$${taxAmount.toStringAsFixed(2)}';
  String get formattedTip => '\$${tipAmount.toStringAsFixed(2)}';
  String get formattedTotal => '\$${total.toStringAsFixed(2)}';

  void setTaxRate(double rate) {
    if (_taxRate != rate) {
      _taxRate = rate;
      notifyListeners();
    }
  }

  void setTipAmount(double tip) {
    if (_tipAmount != tip) {
      _tipAmount = tip < 0 ? 0.0 : tip;
      notifyListeners();
    }
  }

  /// Adds a product to the cart with specified modifiers and notes.
  /// If an identical item is already present, increases its quantity.
  void addItem(
    StoreProduct product,
    List<StoreModifierOption> modifiers, {
    String? notes,
    int quantity = 1,
  }) {
    if (quantity <= 0) return;

    final existingIndex = _items.indexWhere(
      (item) => item.hasSameConfiguration(product, modifiers, notes),
    );

    if (existingIndex != -1) {
      final existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      final uniqueId =
          '${product.id}_${DateTime.now().microsecondsSinceEpoch}_${_items.length}';
      _items.add(
        CartItem(
          id: uniqueId,
          product: product,
          quantity: quantity,
          selectedModifiers: List.unmodifiable(modifiers),
          specialNotes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        ),
      );
    }

    notifyListeners();
  }

  /// Removes item at index
  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  /// Removes item by unique ID
  void removeItemById(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  /// Updates quantity of an item. Removes it if qty <= 0
  void updateQuantity(int index, int qty) {
    if (index < 0 || index >= _items.length) return;

    if (qty <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: qty);
    }
    notifyListeners();
  }

  void incrementQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      updateQuantity(index, _items[index].quantity + 1);
    }
  }

  void decrementQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      updateQuantity(index, _items[index].quantity - 1);
    }
  }

  /// Clears all cart items and resets tips
  void clear() {
    _items.clear();
    _tipAmount = 0.0;
    notifyListeners();
  }
}
