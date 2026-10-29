import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/theme_style_provider.dart';
import '../../../../l10n/app_localizations.dart';
import 'settings_segmented_option.dart';

/// Settings → Appearance: Light, Dark or System. Each brightness has one theme.
class SettingsAppearanceSection extends ConsumerWidget {
  const SettingsAppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appearance = ref.watch(appearanceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.appearanceSection,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary)),
        const SizedBox(height: 12),
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
                child: SettingsSegmentedOption(
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
                child: SettingsSegmentedOption(
                  label: l10n.brightnessDarkLabel,
                  description: l10n.brightnessDarkDescription,
                  selected: appearance.brightnessMode == AppBrightnessMode.dark,
                  onTap: () => ref
                      .read(appearanceProvider.notifier)
                      .setBrightnessMode(AppBrightnessMode.dark),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SettingsSegmentedOption(
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
      ],
    );
  }
}
