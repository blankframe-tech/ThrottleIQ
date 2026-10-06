import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_shape_profile.dart';
import '../../../../core/theme/app_theme_style.dart';
import '../../../../core/theme/theme_style_provider.dart';
import '../../../../l10n/app_localizations.dart';

/// The display name for a color mode, in the current language.
String colorModeLabel(AppLocalizations l10n, AppColorMode mode) => switch (mode) {
      AppColorMode.daily => l10n.themeDailyLabel,
      AppColorMode.sport => l10n.themeSportLabel,
      AppColorMode.adventure => l10n.themeAdventureLabel,
    };

/// The one-line "what this color mode looks like" blurb shown under each name.
String colorModeDescription(AppLocalizations l10n, AppColorMode mode) =>
    switch (mode) {
      AppColorMode.daily => l10n.themeDailyDescription,
      AppColorMode.sport => l10n.themeSportDescription,
      AppColorMode.adventure => l10n.themeAdventureDescription,
    };

/// The 3-mode segmented selector for Settings › Appearance: Daily, Sport, Adventure.
/// Matches the segmented design of the Brightness and Shape Vibe controls.
class ColorModeSegmentedPicker extends ConsumerWidget {
  const ColorModeSegmentedPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appearance = ref.watch(appearanceProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < AppColorMode.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _ColorModeSegmentOption(
                mode: AppColorMode.values[i],
                label: colorModeLabel(l10n, AppColorMode.values[i]),
                description: colorModeDescription(l10n, AppColorMode.values[i]),
                selected: appearance.colorMode == AppColorMode.values[i],
                shapeVibe: appearance.shapeVibe,
                brightness: appearance.brightness,
                onTap: () => ref
                    .read(appearanceProvider.notifier)
                    .setColorMode(AppColorMode.values[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorModeSegmentOption extends StatelessWidget {
  const _ColorModeSegmentOption({
    required this.mode,
    required this.label,
    required this.description,
    required this.selected,
    required this.shapeVibe,
    required this.brightness,
    required this.onTap,
  });

  final AppColorMode mode;
  final String label;
  final String description;
  final bool selected;
  final AppShapeVibe shapeVibe;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.shape.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? context.palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(context.shape.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ColorModeSwatch(
                  mode: mode,
                  shapeVibe: shapeVibe,
                  brightness: brightness,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? context.palette.surface
                          : context.palette.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? context.palette.surface.withValues(alpha: 0.85)
                    : context.palette.textTertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown variant for backward compatibility with existing tests and call sites.
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
      dropdownColor: context.palette.surface,
      borderRadius: BorderRadius.circular(context.shape.radiusMd),
      icon: Icon(Icons.expand_more, color: context.palette.textSecondary),
      style: TextStyle(fontSize: 14, color: context.palette.textPrimary),
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
                      color: context.palette.textPrimary,
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
                          color: context.palette.textPrimary,
                        ),
                      ),
                      Text(
                        colorModeDescription(l10n, mode),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: context.palette.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (mode == appearance.colorMode) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 18, color: context.palette.primary),
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
/// its background and corner shape, with its primary and secondary accents.
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
      width: 26,
      height: 18,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(shape.radiusLg / 2),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dot(palette.primary),
          const SizedBox(width: 2),
          _dot(palette.secondary),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
