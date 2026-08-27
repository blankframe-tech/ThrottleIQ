import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'app_shape_profile.dart';
import 'app_theme_style.dart';
import 'app_typography.dart';

const _colorModeKey = 'color_mode';
const _shapeVibeKey = 'shape_vibe';
const _brightnessKey = 'brightness';

/// The legacy single-key value written before Vibe/Brightness/Color were
/// three separate choices. Kept around only to migrate a rider's existing
/// pick the first time this build loads — see [_legacyTriple].
const _legacyThemeStyleKey = 'theme_style';

/// One fully-resolved appearance: a color family, a shape vibe, and a
/// brightness, chosen independently. This is the whole point of the
/// Vibe/Brightness/Color split — any of the seven [AppColorMode]s can pair
/// with either [AppShapeVibe] and either [Brightness].
@immutable
class AppAppearance {
  final AppColorMode colorMode;
  final AppShapeVibe shapeVibe;
  final Brightness brightness;

  const AppAppearance({
    required this.colorMode,
    required this.shapeVibe,
    required this.brightness,
  });

  /// Calming, Curvy, Light — the default for every new install and every
  /// newly-created account (changed 2026-08-27, from the original Carbon
  /// Mono / Boxy / Dark). Also what any single un-set axis falls back to for
  /// a returning rider who only ever changed the other two — see
  /// [AppearanceNotifier._loadPersisted].
  static const defaultAppearance = AppAppearance(
    colorMode: AppColorMode.calming,
    shapeVibe: AppShapeVibe.curvy,
    brightness: Brightness.light,
  );

  AppAppearance copyWith({
    AppColorMode? colorMode,
    AppShapeVibe? shapeVibe,
    Brightness? brightness,
  }) =>
      AppAppearance(
        colorMode: colorMode ?? this.colorMode,
        shapeVibe: shapeVibe ?? this.shapeVibe,
        brightness: brightness ?? this.brightness,
      );

  @override
  bool operator ==(Object other) =>
      other is AppAppearance &&
      other.colorMode == colorMode &&
      other.shapeVibe == shapeVibe &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(colorMode, shapeVibe, brightness);
}

/// The full (colorMode, shapeVibe, brightness) triple a pre-migration rider's
/// single skin choice decodes to. The three modes dropped in the
/// Vibe/Brightness/Color split (`positiveVibes`, `genesis`, `cuteAnalyst`)
/// map to their closest surviving equivalent rather than to the default, so
/// switching builds doesn't silently reset an existing rider's look more
/// than necessary:
///   - `positiveVibes` (light, rounded, green) → Calming (closest rounded
///     light green-family mode).
///   - `cuteAnalyst` (Analyst Blue's colors, rounded) → Analyst Blue, Curvy,
///     Dark — an EXACT match, since that skin was always just Analyst Blue's
///     palette with a different shape.
///   - `genesis` (dark, boxy, gold/violet) → no surviving hue is close, so it
///     falls back to whatever [AppAppearance.defaultAppearance] currently is
///     rather than guessing a resemblance that isn't really there.
const Map<String, AppAppearance> _legacyTriple = {
  'carbon': AppAppearance(
    colorMode: AppColorMode.carbonMono,
    shapeVibe: AppShapeVibe.boxy,
    brightness: Brightness.dark,
  ),
  'editorial': AppAppearance(
    colorMode: AppColorMode.editorial,
    shapeVibe: AppShapeVibe.boxy,
    brightness: Brightness.light,
  ),
  'nocturne': AppAppearance(
    colorMode: AppColorMode.nocturne,
    shapeVibe: AppShapeVibe.boxy,
    brightness: Brightness.dark,
  ),
  'trailSocial': AppAppearance(
    colorMode: AppColorMode.trailSocial,
    shapeVibe: AppShapeVibe.curvy,
    brightness: Brightness.dark,
  ),
  'calming': AppAppearance(
    colorMode: AppColorMode.calming,
    shapeVibe: AppShapeVibe.curvy,
    brightness: Brightness.light,
  ),
  'positiveVibes': AppAppearance(
    colorMode: AppColorMode.calming,
    shapeVibe: AppShapeVibe.curvy,
    brightness: Brightness.light,
  ),
  'retro': AppAppearance(
    colorMode: AppColorMode.retro,
    shapeVibe: AppShapeVibe.boxy,
    brightness: Brightness.light,
  ),
  'analystBlue': AppAppearance(
    colorMode: AppColorMode.analystBlue,
    shapeVibe: AppShapeVibe.boxy,
    brightness: Brightness.dark,
  ),
  'genesis': AppAppearance.defaultAppearance,
  'cuteAnalyst': AppAppearance(
    colorMode: AppColorMode.analystBlue,
    shapeVibe: AppShapeVibe.curvy,
    brightness: Brightness.dark,
  ),
};

AppColorMode? _decodeColorMode(String? saved) {
  if (saved == null) return null;
  for (final mode in AppColorMode.values) {
    if (mode.name == saved) return mode;
  }
  return null; // a mode removed since this was written
}

AppShapeVibe? _decodeShapeVibe(String? saved) {
  if (saved == null) return null;
  for (final vibe in AppShapeVibe.values) {
    if (vibe.name == saved) return vibe;
  }
  // 'rounded'/'terminal' are what the pre-split AppShapeProfile persisted
  // under, on the rare chance anything ever wrote a shape key directly.
  if (saved == 'rounded') return AppShapeVibe.curvy;
  if (saved == 'terminal') return AppShapeVibe.boxy;
  return null;
}

Brightness? _decodeBrightness(String? saved) {
  if (saved == 'dark') return Brightness.dark;
  if (saved == 'light') return Brightness.light;
  return null;
}

/// Persisted appearance preference: three independent choices — color
/// family, shape vibe, brightness — rather than one flat skin name.
///
/// Defaults to [AppAppearance.defaultAppearance] (Calming / Curvy / Light)
/// until a saved choice loads from
/// [SharedPreferences]. A rider who already had a skin picked under the old
/// single-key scheme has it decoded via [_legacyTriple] on first load under
/// this build, then persisted forward under the three new keys.
class AppearanceNotifier extends StateNotifier<AppAppearance> {
  AppearanceNotifier() : super(AppAppearance.defaultAppearance) {
    _applyTokens(AppAppearance.defaultAppearance);
    _loadPersisted();
  }

  /// Pushes [appearance] into every static token facade at once.
  ///
  /// [AppColors] is not the only one: an appearance also carries a shape
  /// profile (see [AppShapeProfile]) and, for Retro, a different display
  /// typeface (see [AppTypography]). Applying all three together in one
  /// place is what stops an appearance from ending up half-applied — the
  /// failure mode being mono type or another mode's corner radius left
  /// behind on the next combination the rider picks.
  void _applyTokens(AppAppearance appearance) {
    AppColors.apply(AppColorPalette.forMode(appearance.colorMode, appearance.brightness));
    AppDimensions.apply(AppShapeProfile.forVibe(appearance.shapeVibe));
    AppTypography.applyStyle(appearance.colorMode);
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // disposed while the read was in flight

    final rawColorMode = prefs.getString(_colorModeKey);
    final rawShapeVibe = prefs.getString(_shapeVibeKey);
    final rawBrightness = prefs.getString(_brightnessKey);

    AppAppearance resolved;
    if (rawColorMode == null && rawShapeVibe == null && rawBrightness == null) {
      // Nothing under the new three-key scheme at all — this is either a
      // fresh install or a rider migrating from the old single-key scheme.
      final legacy = _legacyTriple[prefs.getString(_legacyThemeStyleKey)];
      if (legacy == null) return; // nothing saved under either scheme
      resolved = legacy;
    } else {
      // At least one axis has been changed under the new scheme — trust it
      // for that axis, and default any axis the rider never touched, rather
      // than falling back to the legacy value (which may be stale, or may
      // not exist at all for a rider who started on this build). Each axis
      // is independently settable, so this is the common case, not an edge
      // case: a rider who only ever changed Brightness has no `color_mode`
      // key on disk at all.
      resolved = AppAppearance(
        colorMode: _decodeColorMode(rawColorMode) ?? AppAppearance.defaultAppearance.colorMode,
        shapeVibe: _decodeShapeVibe(rawShapeVibe) ?? AppAppearance.defaultAppearance.shapeVibe,
        brightness:
            _decodeBrightness(rawBrightness) ?? AppAppearance.defaultAppearance.brightness,
      );
    }

    if (resolved == state) return;
    _applyTokens(resolved);
    state = resolved;
  }

  Future<void> setColorMode(AppColorMode colorMode) async {
    if (colorMode == state.colorMode) return;
    final next = state.copyWith(colorMode: colorMode);
    _applyTokens(next);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorModeKey, colorMode.name);
  }

  Future<void> setShapeVibe(AppShapeVibe shapeVibe) async {
    if (shapeVibe == state.shapeVibe) return;
    final next = state.copyWith(shapeVibe: shapeVibe);
    _applyTokens(next);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shapeVibeKey, shapeVibe.name);
  }

  Future<void> setBrightness(Brightness brightness) async {
    if (brightness == state.brightness) return;
    final next = state.copyWith(brightness: brightness);
    _applyTokens(next);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brightnessKey, brightness == Brightness.dark ? 'dark' : 'light');
  }
}

final appearanceProvider =
    StateNotifierProvider<AppearanceNotifier, AppAppearance>(
        (ref) => AppearanceNotifier());
