import 'package:flutter_test/flutter_test.dart';
import 'package:elorigen_kiosk/controllers/cart_controller.dart';
import 'package:elorigen_kiosk/models/store_category.dart';
import 'package:elorigen_kiosk/models/store_modifier.dart';
import 'package:elorigen_kiosk/models/store_product.dart';

void main() {
  group('StoreCategory & StoreModifier Models', () {
    test('StoreCategory fromJson and toJson serialization', () {
      final json = {
        'id': 'cat_1',
        'name': 'Hamburguesas',
        'segment': 'RETAIL',
        'order': 1,
        'active': true,
        'productCount': 5,
      };

      final category = StoreCategory.fromJson(json);
      expect(category.id, 'cat_1');
      expect(category.name, 'Hamburguesas');
      expect(category.segment, 'RETAIL');
      expect(category.order, 1);
      expect(category.active, isTrue);
      expect(category.productCount, 5);
      expect(category.toJson()['name'], 'Hamburguesas');
    });

    test('StoreModifierGroup requirement logic', () {
      const requiredGroup = StoreModifierGroup(
        name: 'Término de la Carne',
        minSelection: 1,
        maxSelection: 1,
        options: [
          StoreModifierOption(id: 'm1', name: 'Medio', price: 0.0),
          StoreModifierOption(id: 'm2', name: 'Bien Cocido', price: 0.0),
        ],
      );

      expect(requiredGroup.isRequired, isTrue);
      expect(requiredGroup.isSingleSelect, isTrue);
      expect(requiredGroup.isMultiSelect, isFalse);
      expect(requiredGroup.requirementBadge, contains('Obligatorio'));

      const optionalMultiGroup = StoreModifierGroup(
        name: 'Extras',
        minSelection: 0,
        maxSelection: 3,
        options: [
          StoreModifierOption(id: 'e1', name: 'Tocino', price: 1.5),
          StoreModifierOption(id: 'e2', name: 'Queso', price: 1.0),
        ],
      );

      expect(optionalMultiGroup.isRequired, isFalse);
      expect(optionalMultiGroup.isSingleSelect, isFalse);
      expect(optionalMultiGroup.isMultiSelect, isTrue);
      expect(optionalMultiGroup.requirementBadge, contains('Opcional'));
    });
  });

  group('CartController & CartItem Logic', () {
    late CartController cartController;
    late StoreProduct burgerProduct;
    late StoreModifierOption baconOption;
    late StoreModifierOption cheeseOption;

    setUp(() {
      cartController = CartController();
      baconOption = const StoreModifierOption(
        id: 'opt_bacon',
        name: 'Tocino Ahumado',
        price: 1.50,
      );
      cheeseOption = const StoreModifierOption(
        id: 'opt_cheese',
        name: 'Extra Queso',
        price: 1.00,
      );
      burgerProduct = const StoreProduct(
        id: 'prod_burger_1',
        name: 'Hamburguesa Especial',
        price: 10.00,
        categoryId: 'cat_1',
      );
    });

    test('Initial cart state is empty', () {
      expect(cartController.isEmpty, isTrue);
      expect(cartController.isNotEmpty, isFalse);
      expect(cartController.itemCount, 0);
      expect(cartController.subtotal, 0.0);
      expect(cartController.total, 0.0);
    });

    test('Adding item calculates unitPrice, totalPrice and aggregates correctly', () {
      cartController.addItem(
        burgerProduct,
        [baconOption, cheeseOption],
        notes: 'Sin cebolla',
        quantity: 2,
      );

      expect(cartController.isEmpty, isFalse);
      expect(cartController.items.length, 1);
      expect(cartController.itemCount, 2);

      final item = cartController.items.first;
      // Unit price = 10.00 base + 1.50 bacon + 1.00 cheese = 12.50
      expect(item.unitPrice, 12.50);
      // Total price = 12.50 * 2 = 25.00
      expect(item.totalPrice, 25.00);
      expect(cartController.subtotal, 25.00);
      expect(cartController.total, 25.00);
      expect(item.specialNotes, 'Sin cebolla');
      expect(item.hasModifiers, isTrue);
    });

    test('Adding identical item increments quantity instead of duplicate line', () {
      cartController.addItem(
        burgerProduct,
        [baconOption],
        notes: 'Bien cocida',
        quantity: 1,
      );

      expect(cartController.items.length, 1);
      expect(cartController.itemCount, 1);

      // Add identical
      cartController.addItem(
        burgerProduct,
        [baconOption],
        notes: 'Bien cocida',
        quantity: 3,
      );

      expect(cartController.items.length, 1);
      expect(cartController.itemCount, 4);
      expect(cartController.items.first.quantity, 4);
      // Unit price = 10 + 1.5 = 11.5 * 4 = 46.00
      expect(cartController.subtotal, 46.00);
    });

    test('Adding item with different modifiers creates distinct line item', () {
      cartController.addItem(burgerProduct, [baconOption], quantity: 1);
      cartController.addItem(burgerProduct, [cheeseOption], quantity: 1);

      expect(cartController.items.length, 2);
      expect(cartController.itemCount, 2);
    });

    test('Updating quantity and removing items', () {
      cartController.addItem(burgerProduct, []);
      expect(cartController.itemCount, 1);

      cartController.incrementQuantity(0);
      expect(cartController.items.first.quantity, 2);

      cartController.decrementQuantity(0);
      expect(cartController.items.first.quantity, 1);

      // Decrementing to 0 removes the item
      cartController.decrementQuantity(0);
      expect(cartController.isEmpty, isTrue);
    });

    test('Tax and Tip calculation in CartController', () {
      cartController.addItem(burgerProduct, [], quantity: 2); // 20.00
      cartController.setTaxRate(0.10); // 10% tax
      cartController.setTipAmount(3.00); // $3 tip

      expect(cartController.subtotal, 20.00);
      expect(cartController.taxAmount, 2.00);
      expect(cartController.tipAmount, 3.00);
      expect(cartController.total, 25.00);
    });

    test('Clear resets all items and tip amount', () {
      cartController.addItem(burgerProduct, []);
      cartController.setTipAmount(5.00);

      cartController.clear();
      expect(cartController.isEmpty, isTrue);
      expect(cartController.tipAmount, 0.0);
      expect(cartController.total, 0.0);
    });
  });
}
