import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme_style.dart';
import '../../../../core/theme/theme_style_provider.dart';
import '../../../../l10n/app_localizations.dart';

/// The display name for a skin, in the current language. Skin names are
/// product names, so Bangla transliterates rather than translates them — see
/// the `theme*Label` keys in `app_en.arb` / `app_bn.arb`.
///
/// A `switch` with no `default`, so adding a skin without naming it is a
/// compile error rather than a blank row in the picker.
String skinLabel(AppLocalizations l10n, AppThemeStyle style) => switch (style) {
      AppThemeStyle.carbonMono => l10n.themeCarbonLabel,
      AppThemeStyle.editorial => l10n.themeEditorialLabel,
      AppThemeStyle.nocturne => l10n.themeNocturneLabel,
      AppThemeStyle.trailSocial => l10n.themeTrailSocialLabel,
      AppThemeStyle.calming => l10n.themeCalmingLabel,
      AppThemeStyle.positiveVibes => l10n.themePositiveVibesLabel,
      AppThemeStyle.retro => l10n.themeRetroLabel,
      AppThemeStyle.analystBlue => l10n.themeAnalystBlueLabel,
      AppThemeStyle.genesis => l10n.themeGenesisLabel,
    };

/// The one-line "what this skin looks like" blurb shown under each name.
String skinDescription(AppLocalizations l10n, AppThemeStyle style) =>
    switch (style) {
      AppThemeStyle.carbonMono => l10n.themeCarbonDescription,
      AppThemeStyle.editorial => l10n.themeEditorialDescription,
      AppThemeStyle.nocturne => l10n.themeNocturneDescription,
      AppThemeStyle.trailSocial => l10n.themeTrailSocialDescription,
      AppThemeStyle.calming => l10n.themeCalmingDescription,
      AppThemeStyle.positiveVibes => l10n.themePositiveVibesDescription,
      AppThemeStyle.retro => l10n.themeRetroDescription,
      AppThemeStyle.analystBlue => l10n.themeAnalystBlueDescription,
      AppThemeStyle.genesis => l10n.themeGenesisDescription,
    };

/// The skin picker for Settings › Appearance: every [AppThemeStyle] as one row
/// of a dropdown, each with its name, its blurb, and a swatch of its own
/// palette.
///
/// This replaced a two-up segmented control, which gave each of the original
/// two themes a label *and* a description at full width — exactly the
/// affordance that doesn't survive being divided nine ways.
///
/// The swatches are the point of the control. A skin name means nothing on its
/// own, and a rider shouldn't have to apply all nine to find out what they look
/// like — so each row paints itself in *its* colors rather than the currently
/// applied ones, which is why [SkinSwatch] reads from
/// [AppColorPalette.forStyle] and not from [AppColors].
class SkinDropdown extends ConsumerWidget {
  const SkinDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeStyle = ref.watch(themeStyleProvider);

    return DropdownButtonFormField<AppThemeStyle>(
      initialValue: themeStyle,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.skinFieldLabel,
        // The shared InputDecorationTheme already supplies fill, borders and
        // radius, so the picker matches every other field in the app.
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      icon: Icon(Icons.expand_more, color: AppColors.textSecondary),
      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      // The closed field gets one compact line; the two-line rows below would
      // overflow it.
      selectedItemBuilder: (context) => [
        for (final style in AppThemeStyle.values)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SkinSwatch(style: style),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    skinLabel(l10n, style),
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
        for (final style in AppThemeStyle.values)
          DropdownMenuItem(
            value: style,
            child: Row(
              children: [
                SkinSwatch(style: style),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skinLabel(l10n, style),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        skinDescription(l10n, style),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (style == themeStyle) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 18, color: AppColors.primary),
                ],
              ],
            ),
          ),
      ],
      onChanged: (style) {
        if (style == null) return;
        ref.read(themeStyleProvider.notifier).setStyle(style);
      },
    );
  }
}

/// A miniature of one skin: its background, with its primary and secondary
/// accents stacked on top. Small enough to sit inline in a dropdown row and
/// still tell three palettes apart at a glance.
class SkinSwatch extends StatelessWidget {
  const SkinSwatch({super.key, required this.style});

  final AppThemeStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = AppColorPalette.forStyle(style);
    return Container(
      width: 34,
      height: 24,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        // Deliberately the *current* skin's border, not this row's: several
        // palettes' own borders are invisible against their own background
        // (Retro's rule is ink-black, Editorial's a warm hairline), and the
        // job here is to keep the swatch legible on the surface it is drawn
        // on.
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
