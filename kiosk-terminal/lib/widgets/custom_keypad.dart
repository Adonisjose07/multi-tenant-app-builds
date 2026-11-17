import 'package:flutter/material.dart';

class CustomKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback? onClearPressed;
  final VoidCallback? onDonePressed;
  final String? doneLabel;
  final bool showDoneButton;
  final double buttonHeight;
  final double spacing;

  const CustomKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    this.onClearPressed,
    this.onDonePressed,
    this.doneLabel,
    this.showDoneButton = false,
    this.buttonHeight = 64.0,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    // Ensures kiosk touch targets are strictly >= 56dp (Fitts's Law compliance)
    final effectiveHeight = buttonHeight < 56.0 ? 56.0 : buttonHeight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3'], effectiveHeight),
        SizedBox(height: spacing),
        _buildRow(['4', '5', '6'], effectiveHeight),
        SizedBox(height: spacing),
        _buildRow(['7', '8', '9'], effectiveHeight),
        SizedBox(height: spacing),
        _buildBottomRow(effectiveHeight),
      ],
    );
  }

  Widget _buildRow(List<String> digits, double height) {
    return Row(
      children: digits.map((digit) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: _KeypadButton(
              height: height,
              onTap: () => onDigitPressed(digit),
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow(double height) {
    return Row(
      children: [
        // Left Action: Clear ("C") or custom
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: _KeypadButton(
              height: height,
              backgroundColor: const Color(0xFFF1F5F9),
              onTap: onClearPressed ?? () {},
              child: const Text(
                'C',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ),
        // Middle: '0'
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: _KeypadButton(
              height: height,
              onTap: () => onDigitPressed('0'),
              child: const Text(
                '0',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ),
        // Right Action: Done or Backspace
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: showDoneButton && onDonePressed != null
                ? _KeypadButton(
                    height: height,
                    backgroundColor: const Color(0xFFEA581E),
                    splashColor: Colors.white24,
                    onTap: onDonePressed!,
                    child: Text(
                      doneLabel ?? 'OK',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : _KeypadButton(
                    height: height,
                    backgroundColor: const Color(0xFFF1F5F9),
                    onTap: onBackspacePressed,
                    child: const Icon(
                      Icons.backspace_outlined,
                      size: 26,
                      color: Color(0xFF475569),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final double height;
  final VoidCallback onTap;
  final Widget child;
  final Color backgroundColor;
  final Color? splashColor;

  const _KeypadButton({
    required this.height,
    required this.onTap,
    required this.child,
    this.backgroundColor = Colors.white,
    this.splashColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: const BoxConstraints(minHeight: 56.0, minWidth: 56.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: splashColor ?? const Color(0xFFEA581E).withOpacity(0.15),
          highlightColor: const Color(0xFFEA581E).withOpacity(0.08),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
