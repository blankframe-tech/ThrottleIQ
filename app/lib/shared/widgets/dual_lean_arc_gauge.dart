import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme_context.dart';
import '../../core/theme/app_typography.dart';
import 'editorial.dart';

/// A dual-arc telemetry gauge displaying real-time motorcycle lean angle (Left vs Right)
/// with peak-hold ghost indicators, cornering zones, and high-contrast Carbon styling.
class DualLeanArcGauge extends StatelessWidget {
  final double leftAngle;
  final double rightAngle;
  final double? peakLeftAngle;
  final double? peakRightAngle;
  final double size;
  final String? subtitle;

  const DualLeanArcGauge({
    super.key,
    required this.leftAngle,
    required this.rightAngle,
    this.peakLeftAngle,
    this.peakRightAngle,
    this.size = 180,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final activeAngle = leftAngle > rightAngle ? leftAngle : rightAngle;
    final isLeft = leftAngle > rightAngle && leftAngle > 1.0;
    final isRight = rightAngle > leftAngle && rightAngle > 1.0;

    final primaryColor = context.palette.primary;
    final surfaceColor = context.palette.surface;
    final borderColor = context.palette.border;
    final textSecondary = context.palette.textSecondary;
    final dangerColor = context.palette.danger;
    final warningColor = context.palette.warning;

    return Semantics(
      label: 'Lean angle gauge. Left ${leftAngle.toStringAsFixed(0)} degrees, '
          'Right ${rightAngle.toStringAsFixed(0)} degrees',
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
              painter: _DualLeanArcPainter(
                leftAngle: leftAngle.clamp(0, 60),
                rightAngle: rightAngle.clamp(0, 60),
                peakLeftAngle: peakLeftAngle?.clamp(0, 60),
                peakRightAngle: peakRightAngle?.clamp(0, 60),
                borderColor: borderColor,
                primaryColor: primaryColor,
                warningColor: warningColor,
                dangerColor: dangerColor,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isLeft)
                      Icon(Icons.arrow_left, color: primaryColor, size: 24),
                    Text(
                      '${activeAngle.round()}°',
                      style: display(context, (size * 0.22).clamp(24, 40),
                          weight: FontWeight.w700, letterSpacing: -1),
                    ),
                    if (isRight)
                      Icon(Icons.arrow_right, color: primaryColor, size: 24),
                  ],
                ),
                Text(
                  subtitle ??
                      (activeAngle >= 42
                          ? 'KNEE DOWN'
                          : activeAngle >= 25
                              ? 'SPORT'
                              : 'STREET'),
                  style: AppTypography.cockpitLabel(context,
                      color: activeAngle >= 42
                          ? dangerColor
                          : activeAngle >= 25
                              ? primaryColor
                              : textSecondary,
                      letterSpacing: 0.8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DualLeanArcPainter extends CustomPainter {
  final double leftAngle;
  final double rightAngle;
  final double? peakLeftAngle;
  final double? peakRightAngle;
  final Color borderColor;
  final Color primaryColor;
  final Color warningColor;
  final Color dangerColor;

  static const double _maxDegrees = 60.0;
  static const double _arcSweepMaxRad = math.pi * 0.42; // ~75 deg sweep each side

  _DualLeanArcPainter({
    required this.leftAngle,
    required this.rightAngle,
    this.peakLeftAngle,
    this.peakRightAngle,
    required this.borderColor,
    required this.primaryColor,
    required this.warningColor,
    required this.dangerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    const strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Top center start angle is -pi/2
    const topCenter = -math.pi / 2;

    // 1. Draw background arc tracks
    // Left track sweeps counter-clockwise
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      topCenter,
      -_arcSweepMaxRad,
      false,
      bgPaint,
    );
    // Right track sweeps clockwise
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      topCenter,
      _arcSweepMaxRad,
      false,
      bgPaint,
    );

    // 2. Ticks at 15, 30, 45 degrees
    final tickPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5;

    for (final deg in [15.0, 30.0, 45.0]) {
      final radOffset = (deg / _maxDegrees) * _arcSweepMaxRad;
      // Left tick
      _drawTick(canvas, center, radius, topCenter - radOffset, tickPaint);
      // Right tick
      _drawTick(canvas, center, radius, topCenter + radOffset, tickPaint);
    }

    // 3. Draw active left arc
    if (leftAngle > 0.5) {
      final leftSweep = (leftAngle / _maxDegrees) * _arcSweepMaxRad;
      final leftPaint = Paint()
        ..color = _colorForAngle(leftAngle)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        topCenter,
        -leftSweep,
        false,
        leftPaint,
      );
    }

    // 4. Draw active right arc
    if (rightAngle > 0.5) {
      final rightSweep = (rightAngle / _maxDegrees) * _arcSweepMaxRad;
      final rightPaint = Paint()
        ..color = _colorForAngle(rightAngle)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        topCenter,
        rightSweep,
        false,
        rightPaint,
      );
    }

    // 5. Draw ghost peak markers if present
    final ghostPaint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    if (peakLeftAngle != null && peakLeftAngle! > 1.0) {
      ghostPaint.color = _colorForAngle(peakLeftAngle!).withValues(alpha: 0.75);
      final rad = topCenter - (peakLeftAngle! / _maxDegrees) * _arcSweepMaxRad;
      _drawPeakMarker(canvas, center, radius, rad, ghostPaint);
    }

    if (peakRightAngle != null && peakRightAngle! > 1.0) {
      ghostPaint.color = _colorForAngle(peakRightAngle!).withValues(alpha: 0.75);
      final rad = topCenter + (peakRightAngle! / _maxDegrees) * _arcSweepMaxRad;
      _drawPeakMarker(canvas, center, radius, rad, ghostPaint);
    }
  }

  Color _colorForAngle(double deg) {
    if (deg >= 42) return dangerColor;
    if (deg >= 25) return warningColor;
    return primaryColor;
  }

  void _drawTick(
      Canvas canvas, Offset center, double radius, double rad, Paint paint) {
    final inner = Offset(
      center.dx + (radius - 5) * math.cos(rad),
      center.dy + (radius - 5) * math.sin(rad),
    );
    final outer = Offset(
      center.dx + (radius + 5) * math.cos(rad),
      center.dy + (radius + 5) * math.sin(rad),
    );
    canvas.drawLine(inner, outer, paint);
  }

  void _drawPeakMarker(
      Canvas canvas, Offset center, double radius, double rad, Paint paint) {
    final inner = Offset(
      center.dx + (radius - 7) * math.cos(rad),
      center.dy + (radius - 7) * math.sin(rad),
    );
    final outer = Offset(
      center.dx + (radius + 7) * math.cos(rad),
      center.dy + (radius + 7) * math.sin(rad),
    );
    canvas.drawLine(inner, outer, paint);
  }

  @override
  bool shouldRepaint(covariant _DualLeanArcPainter oldDelegate) {
    return oldDelegate.leftAngle != leftAngle ||
        oldDelegate.rightAngle != rightAngle ||
        oldDelegate.peakLeftAngle != peakLeftAngle ||
        oldDelegate.peakRightAngle != peakRightAngle ||
        oldDelegate.primaryColor != primaryColor;
  }
}
