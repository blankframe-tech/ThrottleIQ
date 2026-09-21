import 'package:flutter/material.dart';
import '../../core/theme/app_theme_context.dart';
import '../../core/constants/app_dimensions.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hardShadow = context.palette.hasHardShadow;
    final radius = BorderRadius.circular(context.shape.radiusXl);
    return Material(
      color: color ?? context.palette.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppDimensions.paddingMd),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: context.palette.border,
              width: hardShadow ? 2 : 1,
            ),
            boxShadow: hardShadow
                ? [BoxShadow(color: context.palette.border, offset: const Offset(4, 4))]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
