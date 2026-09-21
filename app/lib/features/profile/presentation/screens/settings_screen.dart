import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/i18n/locale_provider.dart';
import '../../../../core/theme/app_shape_profile.dart';
import '../../../../core/theme/theme_style_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride/presentation/widgets/auto_tracking_tile.dart';
import '../../../../core/constants/sensor_constants.dart';
import '../providers/emergency_contacts_provider.dart';
import '../providers/speed_alert_provider.dart';
import '../widgets/appearance_picker.dart';
import 'sync_issues_screen.dart';
import '../../../auth/presentation/screens/onboarding_tour_provider.dart';
import '../../../auth/presentation/widgets/tour_floating_banner.dart';
import '../../../../shared/widgets/bug_report_sheet.dart';

/// Settings & profile: account info, language, emergency contacts, sign out.
///
/// This is the pilot screen for localization — the first (and, for now, only)
/// screen reading its copy from [AppLocalizations] instead of string literals.
/// Every string it shows has a key in `lib/l10n/app_en.arb` and a real Bangla
/// translation in `app_bn.arb`; `test/core/i18n/arb_parity_test.dart` fails the
/// build if those two ever drift apart.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final contacts = ref.watch(emergencyContactsNotifierProvider);
    final appearance = ref.watch(appearanceProvider);
    final appLocale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
        children: [
          // ── Profile ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: context.palette.primary.withValues(alpha: 0.15),
                  child: Text(
                    (user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0]
                            : '?')
                        .toUpperCase(),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.palette.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? l10n.riderFallbackName,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: context.palette.textPrimary)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '',
                          style: TextStyle(
                              fontSize: 13, color: context.palette.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Appearance ─────────────────────────────────────────────────
          // Three independent choices, not one flat skin list: Vibe (shape),
          // Brightness, and Color each pick their own axis, so any of the
          // seven color modes can be sharp or curvy, dark or light. A rider
          // who wants "sharp, like Nothing" or "rounded, like iOS" sets Vibe
          // once and every color mode they try afterward respects it.
          Text(l10n.appearanceSection,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary)),
          const SizedBox(height: 12),
          Text(l10n.vibeFieldLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(context.shape.radiusMd),
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.vibeBoxyLabel,
                    description: l10n.vibeBoxyDescription,
                    selected: appearance.shapeVibe == AppShapeVibe.boxy,
                    onTap: () => ref
                        .read(appearanceProvider.notifier)
                        .setShapeVibe(AppShapeVibe.boxy),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.vibeCurvyLabel,
                    description: l10n.vibeCurvyDescription,
                    selected: appearance.shapeVibe == AppShapeVibe.curvy,
                    onTap: () => ref
                        .read(appearanceProvider.notifier)
                        .setShapeVibe(AppShapeVibe.curvy),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.brightnessFieldLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(context.shape.radiusMd),
              border: Border.all(color: context.palette.border),
            ),
            // Three options, matching the Language row below: "System" is
            // not the same as "Light" — it tracks the OS and flips with it
            // (issues §83.9). Selection compares brightnessMode, not the
            // resolved brightness, so System stays highlighted whichever way
            // the OS currently leans.
            child: Row(
              children: [
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.brightnessSystemLabel,
                    description: l10n.brightnessSystemDescription,
                    selected:
                        appearance.brightnessMode == AppBrightnessMode.system,
                    onTap: () => ref
                        .read(appearanceProvider.notifier)
                        .setBrightnessMode(AppBrightnessMode.system),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.brightnessDarkLabel,
                    description: l10n.brightnessDarkDescription,
                    selected:
                        appearance.brightnessMode == AppBrightnessMode.dark,
                    onTap: () => ref
                        .read(appearanceProvider.notifier)
                        .setBrightnessMode(AppBrightnessMode.dark),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.brightnessLightLabel,
                    description: l10n.brightnessLightDescription,
                    selected:
                        appearance.brightnessMode == AppBrightnessMode.light,
                    onTap: () => ref
                        .read(appearanceProvider.notifier)
                        .setBrightnessMode(AppBrightnessMode.light),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ColorModeDropdown(),
          const SizedBox(height: 24),

          // ── Language ───────────────────────────────────────────────────
          // Deliberately three options rather than a two-way English/Bangla
          // toggle: "System default" is not the same as "English". A rider
          // whose phone is already in Bangla should get Bangla without
          // touching this screen, and should keep getting whatever their
          // phone says later — pinning them to a language is an explicit act.
          Text(l10n.languageSection,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(context.shape.radiusMd),
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.languageSystemLabel,
                    description: l10n.languageSystemDescription,
                    selected: appLocale == AppLocale.system,
                    onTap: () => ref
                        .read(localeProvider.notifier)
                        .setLocale(AppLocale.system),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.languageEnglishLabel,
                    description: l10n.languageEnglishDescription,
                    selected: appLocale == AppLocale.english,
                    onTap: () => ref
                        .read(localeProvider.notifier)
                        .setLocale(AppLocale.english),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.languageBanglaLabel,
                    description: l10n.languageBanglaDescription,
                    selected: appLocale == AppLocale.bangla,
                    onTap: () => ref
                        .read(localeProvider.notifier)
                        .setLocale(AppLocale.bangla),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Ride tracking ──────────────────────────────────────────────
          const AutoTrackingTile(),
          const AutoTrackingScheduleTile(),
          const SizedBox(height: 12),
          const _OverspeedLimitTile(),

          const SizedBox(height: 24),

          // ── Emergency contacts ─────────────────────────────────────────
          Row(
            children: [
              Text(l10n.emergencyContactsSection,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showContactDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addAction),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // A warning-colored banner, not fine print: until crash alerts
          // actually send, having contacts here must not read as being
          // protected (grill §3.6.3).
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(context.shape.radiusMd),
              border: Border.all(color: context.palette.warning),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: context.palette.warning, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.emergencyContactsNotAlertedBanner,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emergencyContactsDescription,
            style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
          ),
          const SizedBox(height: 12),

          contacts.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(color: context.palette.primary)),
            ),
            error: (e, _) => Text(l10n.emergencyContactsLoadError('$e'),
                style: TextStyle(color: context.palette.danger, fontSize: 13)),
            data: (list) => list.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Center(
                      child: Text(l10n.emergencyContactsEmpty,
                          style: TextStyle(
                              fontSize: 13, color: context.palette.textSecondary)),
                    ),
                  )
                : Column(
                    children: [
                      for (final c in list)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.palette.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.palette.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.contact_emergency_outlined,
                                  color: context.palette.primary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: context.palette.textPrimary)),
                                    Text(
                                        c.email == null
                                            ? c.phone
                                            : '${c.phone} · ${c.email}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: context.palette.textSecondary)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => ref
                                    .read(emergencyContactsNotifierProvider
                                        .notifier)
                                    .deleteContact(c.id),
                                icon: Icon(Icons.delete_outline,
                                    color: context.palette.textTertiary, size: 20),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // ── SafeQR ─────────────────────────────────────────────────────
          // A separate screen, not inlined here: it owns its own editable
          // fields plus a live QR preview, which doesn't fit this screen's
          // "one row per setting" shape. This tile is just the doorway.
          Material(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.push('/safe-qr'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2_outlined,
                        color: context.palette.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.safeQrTitle,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.textPrimary)),
                          const SizedBox(height: 2),
                          Text(l10n.safeQrSettingsSubtitle,
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
          ),

          const SizedBox(height: 24),

          // ── Sync issues (§69.O4) ───────────────────────────────────────
          // Only shown while the outbox has given up on something, so the
          // rider isn't handed a permanent "0 issues" row to wonder about.
          const _SyncIssuesTile(),

          // ── Privacy & Safety ───────────────────────────────────────────
          Row(
            children: [
              Text('Privacy & Safety',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.push('/blocked-users'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: context.palette.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Blocked Users',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Manage accounts you have blocked',
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
          ),
          const SizedBox(height: 10),
          Material(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () async {
                await resetOnboardingTour();
                if (context.mounted) {
                  context.push('/auth/onboarding?demo=1');
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline, color: context.palette.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('See Demo & Feature Tour',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Replay interactive feature guides and safety walkthrough',
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
          ),

          const SizedBox(height: 10),
          // ── Bug Report ─────────────────────────────────────────────────
          Material(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => BugReportSheet.show(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bug_report_outlined,
                        color: context.palette.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send Bug Report',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Something broken? Let the team know',
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
          ),

          const SizedBox(height: 32),

          // ── Sign out ───────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/auth/login');
            },
            icon: const Icon(Icons.logout, size: 18),
            label: Text(l10n.signOutAction),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: context.palette.textSecondary,
              side: BorderSide(color: context.palette.border),
            ),
          ),
          const SizedBox(height: 12),

          // ── Delete account (Apple Guideline 5.1.1(v)) ──────────────────
          TextButton.icon(
            onPressed: () => _confirmDeleteAccount(context, ref),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete Account'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: context.palette.danger,
            ),
          ),
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

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: dialogCtx.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dialogCtx.palette.border),
        ),
        title: Text(
          'Delete Account?',
          style: TextStyle(
            color: dialogCtx.palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This action is irreversible. All your recorded rides, bike profiles, stats, and personal data will be permanently deleted.',
          style: TextStyle(
            color: dialogCtx.palette.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: dialogCtx.palette.danger,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleting account...')),
      );
      try {
        await ref.read(authNotifierProvider.notifier).deleteAccount();
        if (context.mounted) {
          context.go('/auth/login');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting account: $e'),
              backgroundColor: context.palette.danger,
            ),
          );
        }
      }
    }
  }

  /// SharedPreferences flag: the "contacts aren't alerted yet" dialog has
  /// been acknowledged once and never needs showing again.
  static const _contactsAckKey = 'emergency_contacts_not_alerted_ack';

  Future<void> _showContactDialog(BuildContext context, WidgetRef ref) async {
    final wasEmpty =
        ref.read(emergencyContactsNotifierProvider).valueOrNull?.isEmpty ?? true;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddContactDialog(),
    );
    if (added != true || !wasEmpty || !context.mounted) return;

    // One-time acknowledgement on the rider's first contact — the moment
    // they're most likely to assume that contact will now be told about a
    // crash. See emergencyContactsNotAlertedBanner.
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(_contactsAckKey) ?? false) || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        icon: Icon(Icons.warning_amber_rounded, color: dialogContext.palette.warning, size: 32),
        title: Text(l10n.emergencyContactsAckTitle,
            style: TextStyle(color: dialogContext.palette.textPrimary, fontSize: 18)),
        content: Text(l10n.emergencyContactsAckBody,
            style: TextStyle(color: dialogContext.palette.textSecondary)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.emergencyContactsAckAction),
          ),
        ],
      ),
    );
    await prefs.setBool(_contactsAckKey, true);
  }
}

/// The "Add Emergency Contact" dialog's content, as its own
/// [ConsumerStatefulWidget] rather than `TextEditingController`s created
/// inline in `_showContactDialog` — those were never disposed at all (a
/// small per-open leak, not a crash: unlike forum_thread_screen.dart's
/// "New post" sheet, this dialog never called `.dispose()` in the first
/// place, so it never hit the "used after disposed" race). Fixed with the
/// same State-owned-controllers pattern used there, since it's the
/// structurally correct way to own a TextEditingController's lifecycle
/// regardless of which specific failure mode a given ad hoc version hits.
class _AddContactDialog extends ConsumerStatefulWidget {
  const _AddContactDialog();

  @override
  ConsumerState<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends ConsumerState<_AddContactDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    final email = _emailCtrl.text.trim();
    ref.read(emergencyContactsNotifierProvider.notifier).addContact(
          name: name,
          phone: phone,
          email: email.isEmpty ? null : email,
        );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: context.palette.surface,
      title: Text(l10n.addEmergencyContactTitle,
          style: TextStyle(color: context.palette.textPrimary, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: context.palette.textPrimary),
            decoration: InputDecoration(labelText: l10n.contactNameField),
          ),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.palette.textPrimary),
            decoration: InputDecoration(labelText: l10n.contactPhoneField),
          ),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: context.palette.textPrimary),
            decoration:
                InputDecoration(labelText: l10n.contactEmailFieldOptional),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(l10n.addAction),
        ),
      ],
    );
  }
}

/// One tappable segment of a label-plus-description segmented control. Used
/// by the Language control (three segments) and by Appearance's Vibe and
/// Brightness controls (two segments each) — Color has too many options for
/// this shape and uses [ColorModeDropdown] instead.
class _SyncIssuesTile extends ConsumerWidget {
  const _SyncIssuesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(syncIssuesProvider).valueOrNull?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.push('/sync-issues'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.warning),
            ),
            child: Row(
              children: [
                Icon(Icons.sync_problem, color: context.palette.warning, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sync issues',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.palette.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                          count == 1
                              ? "1 update couldn't be sent"
                              : "$count updates couldn't be sent",
                          style: TextStyle(
                              fontSize: 12, color: context.palette.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: context.palette.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedOption extends StatelessWidget {
  const _SegmentedOption({
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
                    color: selected ? context.palette.surface : context.palette.textPrimary)),
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

class _OverspeedLimitTile extends ConsumerWidget {
  const _OverspeedLimitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final limit = ref.watch(overspeedLimitProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: context.palette.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.overspeedSettingTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.overspeedSettingSubtitle,
                      style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                '${limit.round()} km/h',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: context.palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: context.palette.primary,
              inactiveTrackColor: context.palette.primary.withValues(alpha: 0.2),
              thumbColor: context.palette.primary,
            ),
            child: Slider(
              value: limit,
              min: SensorConstants.minOverspeedKmh,
              max: SensorConstants.maxOverspeedKmh,
              divisions: 16,
              label: '${limit.round()} km/h',
              onChanged: (val) {
                ref.read(overspeedLimitProvider.notifier).setLimit(val);
              },
            ),
          ),
        ],
      ),
    );
  }
}
