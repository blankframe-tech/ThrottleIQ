import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/services/app_check_gate.dart';
import '../../core/theme/app_theme_context.dart';
import 'editorial.dart';

/// Shown instead of the whole app when App Check rejects an Android build
/// that was not installed from Google Play (see app_check_gate.dart): a
/// downloaded APK, or one the rider built themselves in release mode.
class SideloadBlockedScreen extends ConsumerWidget {
  const SideloadBlockedScreen({super.key});

  void _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shop_rounded,
                    size: 56, color: context.palette.primary),
                const SizedBox(height: 16),
                Text(
                  context.l10n.sideloadBlockedTitle,
                  textAlign: TextAlign.center,
                  style: display(context, 24),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.sideloadBlockedBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Alpha: the Play listing only opens for accepted testers.
                FilledButton.icon(
                  onPressed: () => _open(kTestingWhatsAppUrl),
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(context.l10n.sideloadBlockedWhatsAppAction),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.sideloadBlockedTesting,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(sideloadDemoProvider.notifier).state = true,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: Text(context.l10n.sideloadBlockedDemoAction),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _open(kPlayStoreUrl),
                  icon: const Icon(Icons.shop_rounded),
                  label: Text(context.l10n.sideloadBlockedPlayAction),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
