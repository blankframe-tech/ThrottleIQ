import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/locale_provider.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../l10n/app_localizations.dart';
import 'settings_segmented_option.dart';

/// Settings → Language.
///
/// Deliberately three options rather than a two-way English/Bangla
/// toggle: "System default" is not the same as "English". A rider
/// whose phone is already in Bangla should get Bangla without
/// touching this screen, and should keep getting whatever their
/// phone says later — pinning them to a language is an explicit act.
class SettingsLanguageSection extends ConsumerWidget {
  const SettingsLanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appLocale = ref.watch(localeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                child: SettingsSegmentedOption(
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
                child: SettingsSegmentedOption(
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
                child: SettingsSegmentedOption(
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
      ],
    );
  }
}
