import 'package:flutter/material.dart';
import '../controllers/cart_controller.dart';
import '../models/cart_item.dart';
import '../models/kiosk_session.dart';

class CartBottomBar extends StatelessWidget {
  final CartController cartController;
  final KioskSession? session;
  final VoidCallback? onCheckout;

  const CartBottomBar({
    super.key,
    required this.cartController,
    this.session,
    this.onCheckout,
  });

  static const Color primaryColor = Color(0xFFEA581E);
  static const Color darkTextColor = Color(0xFF1E293B);
  static const Color subtleTextColor = Color(0xFF64748B);

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimatedBuilder(
        animation: cartController,
        builder: (ctx, _) => FractionallySizedBox(
          heightFactor: 0.85,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        color: primaryColor,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Mi Pedido (${cartController.itemCount})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkTextColor,
                        ),
                      ),
                      const Spacer(),
                      if (cartController.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            cartController.clear();
                            Navigator.of(ctx).pop();
                          },
                          child: const Text(
                            'Vaciar',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 26),
                        color: darkTextColor,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),

                // Dining Mode Chip if available
                if (session != null && session!.diningMode != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          session!.isDineIn
                              ? Icons.restaurant_rounded
                              : Icons.shopping_bag_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          session!.diningMode!.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        if (session!.tableOrPagerNumber != null &&
                            session!.tableOrPagerNumber!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• Mesa/Localizador #${session!.tableOrPagerNumber}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: darkTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Cart Items List
                Expanded(
                  child: cartController.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Color(0xFFCBD5E1),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'El carrito está vacío',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: subtleTextColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: cartController.items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Color(0xFFF1F5F9), height: 24),
                          itemBuilder: (ctx, index) {
                            final item = cartController.items[index];
                            return _buildCartItemTile(index, item);
                          },
                        ),
                ),

                // Footer Financial Summary
                if (cartController.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(
                        top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
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
                                  style: TextStyle(
                                      fontSize: 14, color: subtleTextColor),
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
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 20,
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
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                onCheckout?.call();
                              },
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Continuar al Pago'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemTile(int index, CartItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quantity Controls
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
                  child: Icon(Icons.add_rounded, size: 20, color: darkTextColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: darkTextColor,
                  ),
                ),
              ),
              InkWell(
                onTap: () => cartController.decrementQuantity(index),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.remove_rounded, size: 20, color: darkTextColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Product Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkTextColor,
                ),
              ),
              if (item.hasModifiers) ...[
                const SizedBox(height: 4),
                Text(
                  item.modifiersDescription,
                  style: const TextStyle(
                    fontSize: 13,
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
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Item Price & Remove
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.formattedTotalPrice,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => cartController.removeItem(index),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cartController,
      builder: (context, _) {
        final isEmpty = cartController.isEmpty;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Item Count Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isEmpty
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 20,
                        color: isEmpty ? subtleTextColor : primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${cartController.itemCount}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isEmpty ? subtleTextColor : primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Total
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtleTextColor,
                        ),
                      ),
                      Text(
                        cartController.formattedTotal,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isEmpty ? subtleTextColor : darkTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Button (State 5: Disabled if cart is empty)
                ElevatedButton.icon(
                  onPressed: isEmpty ? null : () => _showCartSheet(context),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text('Ver Carrito'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
