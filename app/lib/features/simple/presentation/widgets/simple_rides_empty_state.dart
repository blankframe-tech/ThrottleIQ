import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';

/// An empty Simple tab: what's missing, why, and the one button that fixes it.
/// Used by all three Simple tabs.
class SimpleEmptyState extends StatelessWidget {
  const SimpleEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: context.palette.textTertiary),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center, style: display(context, 20)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.textSecondary)),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
              onPressed: onPressed,
              child: Text(action, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
}
