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
    // The fill has to live in the same decoration as the shadow. A hard
    // (blur-less) BoxShadow paints a solid offset copy of the whole card, so a
    // fill supplied by a widget *behind* this one — as it used to be, via a
    // Material — is painted over by that copy, and the card renders as a block
    // of border color with its own text unreadable on top (issues §74: near-
    // black cards on Retro Light). Decoration order is shadow, fill, border.
    return Container(
      decoration: BoxDecoration(
        color: color ?? context.palette.surface,
        borderRadius: radius,
        border: Border.all(
          color: context.palette.border,
          width: hardShadow ? 2 : 1,
        ),
        boxShadow: hardShadow
            ? [BoxShadow(color: context.palette.border, offset: const Offset(4, 4))]
            : null,
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
