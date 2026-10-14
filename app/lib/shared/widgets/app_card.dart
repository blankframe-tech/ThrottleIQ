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
    final radius = BorderRadius.circular(context.shape.radiusXl);
    return Container(
      decoration: BoxDecoration(
        color: color ?? context.palette.surface,
        borderRadius: radius,
        border: Border.all(color: context.palette.border),
      ),
      // Transparent Material so InkWell still has somewhere to paint its
      // splash, above the decoration rather than beneath it.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppDimensions.paddingMd),
            child: child,
          ),
        ),
      ),
    );
  }
}
