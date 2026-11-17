import 'package:flutter/material.dart';

/// Interactive tip selection widget for Kiosk self-service checkout.
/// Options: [10%], [15%], [20%], [Otro], [Sin Propina].
/// Computes exact dollar tip amount based on cart subtotal and notifies caller.
class TipSelectorWidget extends StatefulWidget {
  final double subtotal;
  final double currentTip;
  final ValueChanged<double> onTipSelected;

  const TipSelectorWidget({
    super.key,
    required this.subtotal,
    required this.currentTip,
    required this.onTipSelected,
  });

  @override
  State<TipSelectorWidget> createState() => _TipSelectorWidgetState();
}

enum _TipChoice {
  none,
  ten,
  fifteen,
  twenty,
  custom,
}

class _TipSelectorWidgetState extends State<TipSelectorWidget> {
  static const Color brandPrimary = Color(0xFFEA581E);
  static const Color darkText = Color(0xFF1E293B);

  late _TipChoice _selectedChoice;
  double _customTipAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _determineInitialChoice();
  }

  @override
  void didUpdateWidget(covariant TipSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTip != widget.currentTip ||
        oldWidget.subtotal != widget.subtotal) {
      _determineInitialChoice();
    }
  }

  void _determineInitialChoice() {
    if (widget.currentTip <= 0.0) {
      _selectedChoice = _TipChoice.none;
      return;
    }

    final tenAmount = (widget.subtotal * 0.10);
    final fifteenAmount = (widget.subtotal * 0.15);
    final twentyAmount = (widget.subtotal * 0.20);

    if ((widget.currentTip - tenAmount).abs() < 0.01) {
      _selectedChoice = _TipChoice.ten;
    } else if ((widget.currentTip - fifteenAmount).abs() < 0.01) {
      _selectedChoice = _TipChoice.fifteen;
    } else if ((widget.currentTip - twentyAmount).abs() < 0.01) {
      _selectedChoice = _TipChoice.twenty;
    } else {
      _selectedChoice = _TipChoice.custom;
      _customTipAmount = widget.currentTip;
    }
  }

  void _selectTip(_TipChoice choice, double amount) {
    setState(() {
      _selectedChoice = choice;
      if (choice != _TipChoice.custom) {
        _customTipAmount = 0.0;
      }
    });
    widget.onTipSelected(amount);
  }

  Future<void> _showCustomTipDialog() async {
    final controller = TextEditingController(
      text: _customTipAmount > 0
          ? _customTipAmount.toStringAsFixed(2)
          : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Ingresar Otra Propina',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: darkText,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Indica el monto que deseas agregar para el equipo:',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: brandPrimary,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: brandPrimary, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final entered = double.tryParse(controller.text.trim()) ?? 0.0;
                Navigator.pop(dialogCtx, entered < 0 ? 0.0 : entered);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Aplicar Propina'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _customTipAmount = result;
      });
      _selectTip(_TipChoice.custom, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ten = widget.subtotal * 0.10;
    final fifteen = widget.subtotal * 0.15;
    final twenty = widget.subtotal * 0.20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                '¿Deseas agregar propina para el equipo?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
            ),
            if (widget.currentTip > 0) ...[
              const SizedBox(width: 8),
              Text(
                '+\$${widget.currentTip.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // [10%]
            _TipChip(
              key: const Key('tip_chip_10'),
              label: '10%',
              subLabel: '\$${ten.toStringAsFixed(2)}',
              isSelected: _selectedChoice == _TipChoice.ten,
              onTap: () => _selectTip(_TipChoice.ten, ten),
            ),

            // [15%]
            _TipChip(
              key: const Key('tip_chip_15'),
              label: '15%',
              subLabel: '\$${fifteen.toStringAsFixed(2)}',
              isSelected: _selectedChoice == _TipChoice.fifteen,
              onTap: () => _selectTip(_TipChoice.fifteen, fifteen),
            ),

            // [20%]
            _TipChip(
              key: const Key('tip_chip_20'),
              label: '20%',
              subLabel: '\$${twenty.toStringAsFixed(2)}',
              isSelected: _selectedChoice == _TipChoice.twenty,
              onTap: () => _selectTip(_TipChoice.twenty, twenty),
            ),

            // [Otro]
            _TipChip(
              key: const Key('tip_chip_custom'),
              label: 'Otro',
              subLabel: _selectedChoice == _TipChoice.custom
                  ? '\$${_customTipAmount.toStringAsFixed(2)}'
                  : 'Manual',
              isSelected: _selectedChoice == _TipChoice.custom,
              onTap: _showCustomTipDialog,
            ),

            // [Sin Propina]
            _TipChip(
              key: const Key('tip_chip_none'),
              label: 'Sin Propina',
              subLabel: '\$0.00',
              isSelected: _selectedChoice == _TipChoice.none,
              onTap: () => _selectTip(_TipChoice.none, 0.0),
            ),
          ],
        ),
      ],
    );
  }
}

class _TipChip extends StatelessWidget {
  final String label;
  final String subLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _TipChip({
    super.key,
    required this.label,
    required this.subLabel,
    required this.isSelected,
    required this.onTap,
  });

  static const Color brandPrimary = Color(0xFFEA581E);
  static const Color darkText = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? brandPrimary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? brandPrimary : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: brandPrimary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : darkText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white.withOpacity(0.9)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
