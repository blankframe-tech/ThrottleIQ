import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ride/presentation/widgets/auto_tracking_tile.dart';
import '../widgets/settings_account_actions.dart';
import '../widgets/settings_appearance_section.dart';
import '../widgets/settings_emergency_contacts_section.dart';
import '../widgets/settings_language_section.dart';
import '../widgets/settings_link_tile.dart';
import '../widgets/settings_overspeed_tile.dart';
import '../widgets/settings_privacy_section.dart';
import '../widgets/settings_profile_card.dart';
import '../widgets/settings_sync_issues_tile.dart';
import '../../../auth/presentation/widgets/tour_floating_banner.dart';
import '../../../../shared/widgets/bug_report_sheet.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/app_modules.dart';

/// Settings & profile: account info, language, emergency contacts, sign out.
///
/// Each section is its own widget under `presentation/widgets/settings_*`;
/// this screen only lays them out. Every string has a key in
/// `lib/l10n/app_en.arb` and a Bangla translation in `app_bn.arb`;
/// `test/core/i18n/arb_parity_test.dart` fails the build if they drift apart.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rideTracking = ref.watch(appModulesProvider).rideTracking;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SettingsProfileCard(),
              const SizedBox(height: 24),
              const SettingsAppearanceSection(),
              const SizedBox(height: 24),
              const SettingsLanguageSection(),
              const SizedBox(height: 24),

              // ── Ride tracking ──────────────────────────────────────────────
              if (rideTracking) ...[
                const AutoTrackingTile(),
                const AutoTrackingScheduleTile(),
                const SizedBox(height: 12),
                const SettingsOverspeedLimitTile(),
                const SizedBox(height: 24),
              ],

              const SettingsEmergencyContactsSection(),
              const SizedBox(height: 24),

              // ── SafeQR ─────────────────────────────────────────────────────
              // A separate screen, not inlined here: it owns its own editable
              // fields plus a live QR preview, which doesn't fit this screen's
              // "one row per setting" shape. This tile is just the doorway.
              SettingsLinkTile(
                icon: Icons.qr_code_2_outlined,
                title: l10n.safeQrTitle,
                subtitle: l10n.safeQrSettingsSubtitle,
                onTap: () => context.push('/safe-qr'),
              ),
              const SizedBox(height: 24),

              const SettingsSyncIssuesTile(),
              const SettingsPrivacySection(),

              const SizedBox(height: 10),
              SettingsLinkTile(
                icon: Icons.bug_report_outlined,
                title: context.l10n.sendBugReport,
                subtitle: context.l10n.somethingBrokenLetTeam,
                onTap: () => BugReportSheet.show(context),
              ),

              const SizedBox(height: 10),
              // ── Advanced ───────────────────────────────────────────────────
              // App parts, offline data, research and Indriyo pairing: kept off
              // this screen so everyday settings stay short.
              SettingsLinkTile(
                inkKey: const Key('settings_advanced'),
                icon: Icons.tune,
                title: l10n.advancedSettingsTitle,
                subtitle: l10n.advancedSettingsSubtitle,
                onTap: () => context.push('/settings/advanced'),
              ),

              const SizedBox(height: 32),
              const SettingsAccountActions(),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TourFloatingBanner(),
          ),
        ],
      ),
    );
  }
}
