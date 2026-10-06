import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme_context.dart';
import '../../core/theme/app_typography.dart';
import 'editorial.dart';

/// A 2D G-Force Friction Circle (traction envelope) displaying combined
/// cornering (lateral G) and braking/acceleration (longitudinal G) loads in real time.
class GForceFrictionCircle extends StatelessWidget {
  /// Lateral G (-2.0 to 2.0g): negative = left turn, positive = right turn.
  final double lateralG;

  /// Longitudinal G (-2.0 to 2.0g): negative = braking, positive = acceleration.
  final double longitudinalG;

  /// The outer ring radius threshold in Gs (typically 1.0g - 1.2g).
  final double maxG;

  final double size;
  final String? subtitle;

  const GForceFrictionCircle({
    super.key,
    required this.lateralG,
    required this.longitudinalG,
    this.maxG = 1.2,
    this.size = 180,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final combinedG =
        math.sqrt(lateralG * lateralG + longitudinalG * longitudinalG);

    final primaryColor = context.palette.primary;
    final surfaceColor = context.palette.surface;
    final borderColor = context.palette.border;
    final textSecondary = context.palette.textSecondary;
    final dangerColor = context.palette.danger;
    final warningColor = context.palette.warning;

    final gColor = combinedG >= 0.9
        ? dangerColor
        : combinedG >= 0.5
            ? warningColor
            : primaryColor;

    return Semantics(
      label: 'G-Force friction circle. Total ${combinedG.toStringAsFixed(2)} g. '
          'Lateral ${lateralG.toStringAsFixed(2)} g, Longitudinal ${longitudinalG.toStringAsFixed(2)} g',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: surfaceColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size - 16, size - 16),
              painter: _GForceFrictionPainter(
                lateralG: lateralG,
                longitudinalG: longitudinalG,
                maxG: maxG > 0 ? maxG : 1.2,
                borderColor: borderColor,
                gColor: gColor,
                textSecondary: textSecondary,
              ),
            ),
            Positioned(
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${combinedG.toStringAsFixed(2)}g',
                    style: display(context, (size * 0.14).clamp(16, 24),
                        weight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                  Text(
                    subtitle ?? 'TRACTION ENVELOPE',
                    style: AppTypography.cockpitLabel(context,
                        color: gColor, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GForceFrictionPainter extends CustomPainter {
  final double lateralG;
  final double longitudinalG;
  final double maxG;
  final Color borderColor;
  final Color gColor;
  final Color textSecondary;

  _GForceFrictionPainter({
    required this.lateralG,
    required this.longitudinalG,
    required this.maxG,
    required this.borderColor,
    required this.gColor,
    required this.textSecondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.44);
    final outerRadius = size.width * 0.38;

    final ringPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final axisPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Concentric rings (0.5g and maxG)
    final ring05Radius = outerRadius * (0.5 / maxG);
    if (ring05Radius > 0) {
      canvas.drawCircle(center, ring05Radius, ringPaint);
    }
    canvas.drawCircle(center, outerRadius, ringPaint);

    // 2. Crosshair axes
    canvas.drawLine(
      Offset(center.dx - outerRadius - 4, center.dy),
      Offset(center.dx + outerRadius + 4, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - outerRadius - 4),
      Offset(center.dx, center.dy + outerRadius + 4),
      axisPaint,
    );

    // 3. Vector point calculation
    // Clamp to outer envelope
    final clampedLat = lateralG.clamp(-maxG, maxG);
    final clampedLong = longitudinalG.clamp(-maxG, maxG);

    // X: Lateral G (+ = Right, - = Left)
    // Y: Longitudinal G (- = Braking/upward, + = Accel/downward)
    final ballX = center.dx + (clampedLat / maxG) * outerRadius;
    final ballY = center.dy - (clampedLong / maxG) * outerRadius;
    final ballPos = Offset(ballX, ballY);

    // 4. Vector line from origin to ball
    final vectorLinePaint = Paint()
      ..color = gColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(center, ballPos, vectorLinePaint);

    // 5. Glow and center point
    final glowPaint = Paint()
      ..color = gColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ballPos, 9, glowPaint);

    final ballPaint = Paint()
      ..color = gColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ballPos, 4.5, ballPaint);
  }

  @override
  bool shouldRepaint(covariant _GForceFrictionPainter oldDelegate) {
    return oldDelegate.lateralG != lateralG ||
        oldDelegate.longitudinalG != longitudinalG ||
        oldDelegate.maxG != maxG ||
        oldDelegate.gColor != gColor;
  }
}
