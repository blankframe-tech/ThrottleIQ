import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_context.dart';

/// One tappable segment of a label-plus-description segmented control, used
/// by Settings (Brightness, Language) and Settings → Advanced (Community).
class SettingsSegmentedOption extends StatelessWidget {
  const SettingsSegmentedOption({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.shape.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? context.palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(context.shape.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? context.palette.surface
                        : context.palette.textPrimary)),
            const SizedBox(height: 2),
            Text(description,
                style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? context.palette.surface.withValues(alpha: 0.8)
                        : context.palette.textTertiary)),
          ],
        ),
      ),
    );
  }
}
