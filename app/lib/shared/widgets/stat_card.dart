import 'package:flutter/material.dart';
import '../../core/theme/app_theme_context.dart';
import '../../core/constants/app_dimensions.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? valueColor;
  final bool isPrimary;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.valueColor,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final hardShadow = context.palette.hasHardShadow;
    final borderColor = isPrimary ? context.palette.primary : context.palette.border;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        border: Border.all(
          color: borderColor,
          width: isPrimary || hardShadow ? 1.5 : 1,
        ),
        boxShadow: hardShadow
            ? [BoxShadow(color: context.palette.border, offset: const Offset(3, 3))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, size: 18, color: isPrimary ? context.palette.primary : context.palette.textSecondary),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? (isPrimary ? context.palette.primary : context.palette.textPrimary),
                    letterSpacing: -0.5,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isPrimary ? context.palette.primary.withValues(alpha: 0.8) : context.palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: isPrimary ? context.palette.primary.withValues(alpha: 0.7) : context.palette.textSecondary)),
        ],
      ),
    );
  }
}
