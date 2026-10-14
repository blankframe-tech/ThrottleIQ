import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/services/app_update_gate.dart';
import '../../core/theme/app_theme_context.dart';
import 'editorial.dart';

/// Shown instead of the whole app when this build is older than
/// `config/app.minBuild` (see app_update_gate.dart). No way past it but the
/// link to the install page.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_rounded,
                    size: 56, color: context.palette.primary),
                const SizedBox(height: 16),
                Text(
                  context.l10n.updateRequiredTitle,
                  textAlign: TextAlign.center,
                  style: display(context, 24),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(kInstallUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(context.l10n.updateRequiredAction),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
