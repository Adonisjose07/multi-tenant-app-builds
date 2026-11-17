import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/nfc_quadrant.dart';

/// Widget rendering animated concentric radar waves positioned dynamically
/// over the tablet's NFC antenna quadrant. Guides the customer to tap their
/// contactless card, phone (Google/Apple Pay) or smartwatch.
class NfcRadarWidget extends StatefulWidget {
  final NfcQuadrant quadrant;
  final bool isWaitingForCard;
  final bool isCardDetected;
  final bool isProcessing;
  final bool isSimulated;
  final VoidCallback? onSimulateTap;

  const NfcRadarWidget({
    super.key,
    this.quadrant = NfcQuadrant.topRight,
    this.isWaitingForCard = true,
    this.isCardDetected = false,
    this.isProcessing = false,
    this.isSimulated = false,
    this.onSimulateTap,
  });

  @override
  State<NfcRadarWidget> createState() => _NfcRadarWidgetState();
}

class _NfcRadarWidgetState extends State<NfcRadarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  static const Color brandPrimary = Color(0xFFEA581E);
  static const Color brandGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDetectedOrProcessing = widget.isCardDetected || widget.isProcessing;

    return Stack(
      children: [
        // Background target area with subtle boundary
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDetectedOrProcessing
                  ? brandGreen.withOpacity(0.4)
                  : brandPrimary.withOpacity(0.2),
              width: 2,
            ),
          ),
        ),

        // Dynamic Positioned/Aligned Radar Waves
        Align(
          alignment: widget.quadrant.alignment,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated pulsing concentric waves
                  if (widget.isWaitingForCard && !isDetectedOrProcessing)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(260, 260),
                          painter: _RadarWavesPainter(
                            progress: _pulseController.value,
                            color: brandPrimary,
                          ),
                        );
                      },
                    ),

                  // Center circular hub / disc
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isDetectedOrProcessing
                            ? [brandGreen, const Color(0xFF059669)]
                            : [brandPrimary, const Color(0xFFC2410C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDetectedOrProcessing
                                  ? brandGreen
                                  : brandPrimary)
                              .withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isProcessing
                          ? const SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                strokeWidth: 3.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              widget.isCardDetected
                                  ? Icons.check_circle_rounded
                                  : widget.quadrant.icon,
                              size: 48,
                              color: Colors.white,
                            ),
                    ),
                  ),

                  // Directional instruction pill anchored to the hub
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isProcessing
                                ? 'Procesando pago...'
                                : widget.isCardDetected
                                    ? 'Tarjeta leída'
                                    : widget.quadrant.instructions,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
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

        // Centered general callout text & supported payment symbols
        Positioned(
          left: 32,
          bottom: 32,
          right: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pago sin contacto (Contactless)',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Aceptamos tarjetas de débito/crédito, Apple Pay, Google Pay y billeteras digitales NFC.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              // Simulation Trigger Button (Visible when isSimulated is active)
              if (widget.isSimulated && widget.onSimulateTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton.icon(
                    key: const Key('simulate_nfc_tap_button'),
                    onPressed: widget.isWaitingForCard ? widget.onSimulateTap : null,
                    icon: const Icon(Icons.touch_app_rounded, size: 22),
                    label: const Text('Simular Toque de Tarjeta (NFC)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1), // Indigo
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter that renders 3 expanding radar waves with fading opacity
class _RadarWavesPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;

  _RadarWavesPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    const minRadius = 55.0;
    const waveCount = 3;

    for (int i = 0; i < waveCount; i++) {
      final waveProgress = (progress + (i / waveCount)) % 1.0;
      final currentRadius = minRadius + (maxRadius - minRadius) * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.45;

      final fillPaint = Paint()
        ..color = color.withOpacity(opacity * 0.25)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, currentRadius, fillPaint);
      canvas.drawCircle(center, currentRadius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
