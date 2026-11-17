import 'package:flutter/material.dart';
import '../controllers/cart_controller.dart';
import '../models/cart_item.dart';
import '../models/kiosk_session.dart';

class CartSidebar extends StatelessWidget {
  final CartController cartController;
  final KioskSession? session;
  final VoidCallback? onCheckout;

  const CartSidebar({
    super.key,
    required this.cartController,
    this.session,
    this.onCheckout,
  });

  static const Color primaryColor = Color(0xFFEA581E);
  static const Color darkTextColor = Color(0xFF1E293B);
  static const Color subtleTextColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cartController,
      builder: (context, _) {
        final isEmpty = cartController.isEmpty;

        return Container(
          width: 380,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: primaryColor,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Mi Pedido',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isEmpty
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${cartController.itemCount}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isEmpty ? subtleTextColor : primaryColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!isEmpty)
                      TextButton.icon(
                        onPressed: () => _confirmClearCart(context),
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                        label: const Text(
                          'Vaciar',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Dining Mode Info Card
              if (session != null && session!.diningMode != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          session!.isDineIn
                              ? Icons.restaurant_rounded
                              : Icons.shopping_bag_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session!.diningMode!.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: darkTextColor,
                              ),
                            ),
                            if (session!.tableOrPagerNumber != null &&
                                session!.tableOrPagerNumber!.isNotEmpty)
                              Text(
                                'Mesa/Localizador: #${session!.tableOrPagerNumber}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: subtleTextColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Scrollable Items List (or Empty State)
              Expanded(
                child: isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: cartController.items.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: Color(0xFFF1F5F9),
                          height: 20,
                        ),
                        itemBuilder: (context, index) {
                          final item = cartController.items[index];
                          return _buildItemRow(index, item);
                        },
                      ),
              ),

              // Summary & Checkout Action
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(fontSize: 14, color: subtleTextColor),
                        ),
                        Text(
                          cartController.formattedSubtotal,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkTextColor,
                          ),
                        ),
                      ],
                    ),
                    if (cartController.taxAmount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Impuestos',
                            style:
                                TextStyle(fontSize: 14, color: subtleTextColor),
                          ),
                          Text(
                            cartController.formattedTax,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: darkTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Color(0xFFE2E8F0), height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total a Pagar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkTextColor,
                          ),
                        ),
                        Text(
                          cartController.formattedTotal,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Checkout Button (State 5: Disabled when cart is empty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isEmpty ? null : onCheckout,
                        icon: const Icon(
                          Icons.credit_card_rounded,
                          size: 22,
                        ),
                        label: const Text('Continuar al Pago'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: isEmpty ? 0 : 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 52,
                color: Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tu pedido está vacío',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: darkTextColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona deliciosos platillos y bebidas del menú para agregarlos a tu orden.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subtleTextColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index, CartItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quantity Buttons
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => cartController.incrementQuantity(index),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.add_rounded, size: 18, color: darkTextColor),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: darkTextColor,
                  ),
                ),
              ),
              InkWell(
                onTap: () => cartController.decrementQuantity(index),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child:
                      Icon(Icons.remove_rounded, size: 18, color: darkTextColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: darkTextColor,
                ),
              ),
              if (item.hasModifiers) ...[
                const SizedBox(height: 4),
                Text(
                  item.modifiersDescription,
                  style: const TextStyle(
                    fontSize: 12,
                    color: subtleTextColor,
                    height: 1.25,
                  ),
                ),
              ],
              if (item.specialNotes != null &&
                  item.specialNotes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Nota: "${item.specialNotes}"',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Price & Remove
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.formattedTotalPrice,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => cartController.removeItem(index),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmClearCart(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Vaciar pedido?'),
        content: const Text(
          'Se eliminarán todos los productos seleccionados de tu orden actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              cartController.clear();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Sí, Vaciar'),
          ),
        ],
      ),
    );
  }
}
