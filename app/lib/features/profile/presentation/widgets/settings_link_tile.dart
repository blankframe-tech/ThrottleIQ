import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_context.dart';

/// A Settings row that opens something: icon, title, subtitle and a chevron.
/// [accent] tints the icon and border (defaults: primary icon, plain border).
class SettingsLinkTile extends StatelessWidget {
  const SettingsLinkTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.inkKey,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Key on the tappable area, for tests that tap it.
  final Key? inkKey;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: inkKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent ?? context.palette.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent ?? context.palette.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.palette.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: context.palette.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
