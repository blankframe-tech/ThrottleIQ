import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../auth/presentation/screens/onboarding_tour_provider.dart';
import 'settings_analytics_tile.dart';
import 'settings_link_tile.dart';
import 'settings_public_live_link_tile.dart';

/// Settings → Privacy & Safety: blocked users, usage stats, the public live
/// link, and the demo feature tour.
class SettingsPrivacySection extends StatelessWidget {
  const SettingsPrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(context.l10n.privacySafety,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary)),
          ],
        ),
        const SizedBox(height: 12),
        SettingsLinkTile(
          icon: Icons.block,
          title: context.l10n.blockedUsers,
          subtitle: context.l10n.manageAccountsHaveBlocked,
          onTap: () => context.push('/blocked-users'),
        ),
        const SizedBox(height: 10),
        const SettingsAnalyticsTile(),
        const SizedBox(height: 10),
        const SettingsPublicLiveLinkTile(),
        const SizedBox(height: 10),
        SettingsLinkTile(
          icon: Icons.play_circle_outline,
          title: context.l10n.seeDemoFeatureTour,
          subtitle: context.l10n.replayInteractiveFeatureGuides,
          onTap: () async {
            await resetOnboardingTour();
            if (context.mounted) {
              context.push('/auth/onboarding?demo=1');
            }
          },
        ),
      ],
    );
  }
}
