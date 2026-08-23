import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_shape_profile.dart';
import '../../../../core/theme/app_theme_style.dart';
import '../../../../core/theme/theme_style_provider.dart';
import '../../../../l10n/app_localizations.dart';

/// The display name for a color mode, in the current language. Color modes
/// are product names, so Bangla transliterates rather than translates them —
/// see the `theme*Label` keys in `app_en.arb` / `app_bn.arb`.
///
/// A `switch` with no `default`, so adding a mode without naming it is a
/// compile error rather than a blank row in the picker.
String colorModeLabel(AppLocalizations l10n, AppColorMode mode) => switch (mode) {
      AppColorMode.carbonMono => l10n.themeCarbonLabel,
      AppColorMode.editorial => l10n.themeEditorialLabel,
      AppColorMode.nocturne => l10n.themeNocturneLabel,
      AppColorMode.trailSocial => l10n.themeTrailSocialLabel,
      AppColorMode.calming => l10n.themeCalmingLabel,
      AppColorMode.retro => l10n.themeRetroLabel,
      AppColorMode.analystBlue => l10n.themeAnalystBlueLabel,
    };

/// The one-line "what this color mode looks like" blurb shown under each
/// name. Deliberately brightness/shape-agnostic — a color mode no longer
/// implies either, so its blurb only ever names its hues.
String colorModeDescription(AppLocalizations l10n, AppColorMode mode) =>
    switch (mode) {
      AppColorMode.carbonMono => l10n.themeCarbonDescription,
      AppColorMode.editorial => l10n.themeEditorialDescription,
      AppColorMode.nocturne => l10n.themeNocturneDescription,
      AppColorMode.trailSocial => l10n.themeTrailSocialDescription,
      AppColorMode.calming => l10n.themeCalmingDescription,
      AppColorMode.retro => l10n.themeRetroDescription,
      AppColorMode.analystBlue => l10n.themeAnalystBlueDescription,
    };

/// The color-mode picker for Settings › Appearance: every [AppColorMode] as
/// one row of a dropdown, each with its name, its blurb, and a swatch.
///
/// Unlike the old flat skin list, a row's swatch previews its palette
/// resolved against the rider's CURRENTLY chosen [AppShapeVibe] and
/// [Brightness] — color is now the third, independent axis, so "what would
/// picking this row actually look like" depends on the other two choices,
/// not on a brightness/shape baked into the mode itself.
class ColorModeDropdown extends ConsumerWidget {
  const ColorModeDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appearance = ref.watch(appearanceProvider);

    return DropdownButtonFormField<AppColorMode>(
      initialValue: appearance.colorMode,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.colorFieldLabel,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      icon: Icon(Icons.expand_more, color: AppColors.textSecondary),
      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      // The closed field gets one compact line; the two-line rows below
      // would overflow it.
      selectedItemBuilder: (context) => [
        for (final mode in AppColorMode.values)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorModeSwatch(
                  mode: mode,
                  shapeVibe: appearance.shapeVibe,
                  brightness: appearance.brightness,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    colorModeLabel(l10n, mode),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      items: [
        for (final mode in AppColorMode.values)
          DropdownMenuItem(
            value: mode,
            child: Row(
              children: [
                ColorModeSwatch(
                  mode: mode,
                  shapeVibe: appearance.shapeVibe,
                  brightness: appearance.brightness,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        colorModeLabel(l10n, mode),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        colorModeDescription(l10n, mode),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (mode == appearance.colorMode) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 18, color: AppColors.primary),
                ],
              ],
            ),
          ),
      ],
      onChanged: (mode) {
        if (mode == null) return;
        ref.read(appearanceProvider.notifier).setColorMode(mode);
      },
    );
  }
}

/// A miniature of one color mode, resolved against a given shape/brightness:
/// its background and corner shape, with its primary and secondary accents
/// stacked on top. Small enough to sit inline in a dropdown row and still
/// tell seven color families apart at a glance.
class ColorModeSwatch extends StatelessWidget {
  const ColorModeSwatch({
    super.key,
    required this.mode,
    required this.shapeVibe,
    required this.brightness,
  });

  final AppColorMode mode;
  final AppShapeVibe shapeVibe;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final palette = AppColorPalette.forMode(mode, brightness);
    final shape = AppShapeProfile.forVibe(shapeVibe);
    return Container(
      width: 34,
      height: 24,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(shape.radiusLg / 2),
        // Deliberately the *current* appearance's border, not this row's:
        // several palettes' own borders are invisible against their own
        // background (Retro's rule is ink-strength, Editorial's a warm
        // hairline), and the job here is to keep the swatch legible on the
        // surface it is drawn on.
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dot(palette.primary),
          const SizedBox(width: 3),
          _dot(palette.secondary),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
