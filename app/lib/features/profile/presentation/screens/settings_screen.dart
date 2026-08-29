import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/locale_provider.dart';
import '../../../../core/theme/app_shape_profile.dart';
import '../../../../core/theme/theme_style_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride/presentation/widgets/auto_tracking_tile.dart';
import '../providers/emergency_contacts_provider.dart';
import '../widgets/appearance_picker.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    (user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0]
                            : '?')
                        .toUpperCase(),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
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
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
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
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Text(l10n.vibeFieldLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.border),
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
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.brightnessDarkLabel,
                    description: l10n.brightnessDarkDescription,
                    selected: appearance.brightness == Brightness.dark,
                    onTap: () => ref
                        .read(appearanceProvider.notifier)
                        .setBrightness(Brightness.dark),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SegmentedOption(
                    label: l10n.brightnessLightLabel,
                    description: l10n.brightnessLightDescription,
                    selected: appearance.brightness == Brightness.light,
                    onTap: () => ref
                        .read(appearanceProvider.notifier)
                        .setBrightness(Brightness.light),
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
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.border),
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

          const SizedBox(height: 24),

          // ── Emergency contacts ─────────────────────────────────────────
          Row(
            children: [
              Text(l10n.emergencyContactsSection,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showContactDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addAction),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.emergencyContactsDescription,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 12),

          contacts.when(
            loading: () => Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            ),
            error: (e, _) => Text(l10n.emergencyContactsLoadError('$e'),
                style: TextStyle(color: AppColors.danger, fontSize: 13)),
            data: (list) => list.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(l10n.emergencyContactsEmpty,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
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
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.contact_emergency_outlined,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary)),
                                    Text(
                                        c.email == null
                                            ? c.phone
                                            : '${c.phone} · ${c.email}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => ref
                                    .read(emergencyContactsNotifierProvider
                                        .notifier)
                                    .deleteContact(c.id),
                                icon: Icon(Icons.delete_outline,
                                    color: AppColors.textTertiary, size: 20),
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.push('/safe-qr'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2_outlined,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.safeQrTitle,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(l10n.safeQrSettingsSubtitle,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: AppColors.textTertiary, size: 20),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Privacy & Safety ───────────────────────────────────────────
          Row(
            children: [
              Text('Privacy & Safety',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.push('/blocked-users'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Blocked Users',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Manage accounts you have blocked',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: AppColors.textTertiary, size: 20),
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
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _AddContactDialog(),
    );
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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.addEmergencyContactTitle,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: l10n.contactNameField),
          ),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: l10n.contactPhoneField),
          ),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: AppColors.textPrimary),
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
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.surface : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(description,
                style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? AppColors.surface.withValues(alpha: 0.8)
                        : AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}
