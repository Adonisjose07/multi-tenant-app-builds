import 'package:flutter/material.dart';
import '../models/store_modifier.dart';
import '../models/store_product.dart';

class ModifierModal extends StatefulWidget {
  final StoreProduct product;
  final Function(
    StoreProduct product,
    List<StoreModifierOption> selectedModifiers,
    String? notes,
    int quantity,
  ) onAddToCart;

  const ModifierModal({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  static const Color primaryColor = Color(0xFFEA581E);
  static const Color darkTextColor = Color(0xFF1E293B);
  static const Color subtleTextColor = Color(0xFF64748B);

  static Future<void> show(
    BuildContext context, {
    required StoreProduct product,
    required Function(
      StoreProduct product,
      List<StoreModifierOption> selectedModifiers,
      String? notes,
      int quantity,
    ) onAddToCart,
  }) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    if (isTablet) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 640,
              maxHeight: 760,
            ),
            child: ModifierModal(
              product: product,
              onAddToCart: onAddToCart,
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.90,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ModifierModal(
              product: product,
              onAddToCart: onAddToCart,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<ModifierModal> createState() => _ModifierModalState();
}

class _ModifierModalState extends State<ModifierModal> {
  // Map of group.id/group.name -> Set of selected options
  final Map<String, Set<StoreModifierOption>> _selections = {};
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _initDefaultSelections();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _initDefaultSelections() {
    for (final group in widget.product.modifierGroups) {
      final selected = <StoreModifierOption>{};
      for (final option in group.options) {
        if (option.isDefault) {
          selected.add(option);
          if (group.isSingleSelect) break;
        }
      }
      _selections[group.name] = selected;
    }
  }

  void _onOptionTapped(StoreModifierGroup group, StoreModifierOption option) {
    setState(() {
      final currentSet = _selections[group.name] ?? <StoreModifierOption>{};

      if (group.isSingleSelect) {
        // Single select: tapping selected option in optional group toggles off;
        // in required group, it remains selected or switches to new option
        if (currentSet.contains(option)) {
          if (!group.isRequired) {
            currentSet.clear();
          }
        } else {
          currentSet.clear();
          currentSet.add(option);
        }
      } else {
        // Multi select
        if (currentSet.contains(option)) {
          currentSet.remove(option);
        } else {
          if (currentSet.length < group.maxSelection) {
            currentSet.add(option);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Máximo ${group.maxSelection} opciones para "${group.name}"',
                ),
                duration: const Duration(milliseconds: 1500),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
      _selections[group.name] = currentSet;
    });
  }

  /// Finds the first group that has not met its minimum requirement
  StoreModifierGroup? _getFirstUnsatisfiedGroup() {
    for (final group in widget.product.modifierGroups) {
      final selectedCount = _selections[group.name]?.length ?? 0;
      if (selectedCount < group.minSelection) {
        return group;
      }
    }
    return null;
  }

  bool get _isValid => _getFirstUnsatisfiedGroup() == null;

  List<StoreModifierOption> get _allSelectedModifiers {
    final list = <StoreModifierOption>[];
    for (final set in _selections.values) {
      list.addAll(set);
    }
    return list;
  }

  double get _modifiersPrice =>
      _allSelectedModifiers.fold(0.0, (sum, opt) => sum + opt.price);

  double get _unitPrice => widget.product.price + _modifiersPrice;

  double get _totalPrice => _unitPrice * _quantity;

  void _submit() {
    if (!_isValid) return;

    widget.onAddToCart(
      widget.product,
      _allSelectedModifiers,
      _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      _quantity,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final unsatisfiedGroup = _getFirstUnsatisfiedGroup();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.product.name,
          style: const TextStyle(
            color: ModifierModal.darkTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 28),
          color: ModifierModal.darkTextColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Product Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.product.imageUrl != null &&
                          widget.product.imageUrl!.trim().isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.product.imageUrl!,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.formattedPrice,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ModifierModal.primaryColor,
                              ),
                            ),
                            if (widget.product.description != null &&
                                widget.product.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.product.description!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: ModifierModal.subtleTextColor,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Modifier Groups
                for (final group in widget.product.modifierGroups) ...[
                  _buildModifierGroupSection(group),
                  const SizedBox(height: 20),
                ],

                // Special Notes Field
                const Text(
                  'Instrucciones especiales para cocina',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ModifierModal.darkTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ej. Sin cebolla, aderezo aparte...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: ModifierModal.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Bottom Bar with Quantity and Add Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  // Validation Alert if unsatisfied (State 5: Disabled explanation)
                  if (unsatisfiedGroup != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selecciona: ${unsatisfiedGroup.name} (mínimo ${unsatisfiedGroup.minSelection})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      // Quantity Selector
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded),
                              color: _quantity > 1
                                  ? ModifierModal.darkTextColor
                                  : const Color(0xFF94A3B8),
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ModifierModal.darkTextColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded),
                              color: ModifierModal.darkTextColor,
                              onPressed: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Add to Cart Button (State 5: Disabled when invalid)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isValid ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ModifierModal.primaryColor,
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: _isValid ? 2 : 0,
                          ),
                          child: Text(
                            'Agregar al Pedido • \$${_totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModifierGroupSection(StoreModifierGroup group) {
    final currentSelected = _selections[group.name] ?? <StoreModifierOption>{};
    final isSatisfied = currentSelected.length >= group.minSelection;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSatisfied
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFFDBA74),
          width: isSatisfied ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with group title and requirement badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSatisfied
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFFFFF7ED),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ModifierModal.darkTextColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: group.isRequired
                        ? (isSatisfied
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2))
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    group.requirementBadge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: group.isRequired
                          ? (isSatisfied
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB91C1C))
                          : ModifierModal.subtleTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Options List
          for (final option in group.options) ...[
            _buildOptionTile(group, option, currentSelected.contains(option)),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    StoreModifierGroup group,
    StoreModifierOption option,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () => _onOptionTapped(group, option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF7ED)
              : Colors.transparent,
          border: const Border(
            top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Radio / Checkbox Indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: group.isSingleSelect
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius:
                    group.isSingleSelect ? null : BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? ModifierModal.primaryColor
                      : const Color(0xFFCBD5E1),
                  width: 2,
                ),
                color: isSelected
                    ? ModifierModal.primaryColor
                    : Colors.white,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // Option Name
            Expanded(
              child: Text(
                option.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? ModifierModal.darkTextColor
                      : const Color(0xFF334155),
                ),
              ),
            ),

            // Option Price
            Text(
              option.formattedPrice,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: option.price > 0
                    ? ModifierModal.primaryColor
                    : ModifierModal.subtleTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 70,
      height: 70,
      color: const Color(0xFFF1F5F9),
      child: const Icon(
        Icons.restaurant_rounded,
        size: 32,
        color: Color(0xFFCBD5E1),
      ),
    );
  }
}
