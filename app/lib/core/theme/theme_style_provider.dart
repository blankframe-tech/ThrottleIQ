import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_shape_profile.dart';
import 'app_theme_style.dart';

const _colorModeKey = 'color_mode';
const _shapeVibeKey = 'shape_vibe';
const _brightnessKey = 'brightness';

/// The legacy single-key value written before Vibe/Brightness/Color were
/// three separate choices. Kept around only to migrate a rider's existing
/// pick the first time this build loads — see [_legacyTriple].
const _legacyThemeStyleKey = 'theme_style';

/// How the app decides between the light and dark palette.
///
/// [system] follows the OS setting and re-resolves whenever the platform
/// flips — the option every other app on the phone has and this one didn't
/// (issues §83.9). It is separate from the resolved [Brightness] because
/// "the rider chose dark" and "the rider chose system, and the system is
/// currently dark" have to be told apart when the OS changes underneath us.
enum AppBrightnessMode { light, dark, system }

/// One fully-resolved appearance: a color family, a shape vibe, and a
/// brightness, chosen independently. This is the whole point of the
/// Vibe/Brightness/Color split — any of the seven [AppColorMode]s can pair
/// with either [AppShapeVibe] and either [Brightness].
@immutable
class AppAppearance {
  final AppColorMode colorMode;
  final AppShapeVibe shapeVibe;

  /// The brightness actually in force — already resolved, so every consumer
  /// (palette lookup, `ThemeData`, status-bar icons) reads one value and
  /// never has to know whether the rider picked it or the OS did.
  final Brightness brightness;

  /// What the rider chose. [AppBrightnessMode.system] means [brightness] was
  /// resolved from the platform and will change with it.
  ///
  /// Optional at construction: omitting it means the caller picked a concrete
  /// [brightness], so the mode is that same concrete choice. Only
  /// [AppBrightnessMode.system] has to be stated, because it's the one case
  /// the resolved brightness can't imply.
  AppBrightnessMode get brightnessMode =>
      _brightnessMode ??
      (brightness == Brightness.dark
          ? AppBrightnessMode.dark
          : AppBrightnessMode.light);

  final AppBrightnessMode? _brightnessMode;

  const AppAppearance({
    required this.colorMode,
    required this.shapeVibe,
    required this.brightness,
    AppBrightnessMode? brightnessMode,
  }) : _brightnessMode = brightnessMode;

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
    AppBrightnessMode? brightnessMode,
  }) =>
      AppAppearance(
        colorMode: colorMode ?? this.colorMode,
        shapeVibe: shapeVibe ?? this.shapeVibe,
        brightness: brightness ?? this.brightness,
        brightnessMode: brightnessMode ?? this.brightnessMode,
      );

  @override
  bool operator ==(Object other) =>
      other is AppAppearance &&
      other.colorMode == colorMode &&
      other.shapeVibe == shapeVibe &&
      other.brightness == brightness &&
      other.brightnessMode == brightnessMode;

  @override
  int get hashCode =>
      Object.hash(colorMode, shapeVibe, brightness, brightnessMode);
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

AppBrightnessMode? _decodeBrightnessMode(String? saved) {
  if (saved == 'dark') return AppBrightnessMode.dark;
  if (saved == 'light') return AppBrightnessMode.light;
  if (saved == 'system') return AppBrightnessMode.system;
  return null;
}

/// The OS setting, read fresh. Only consulted for [AppBrightnessMode.system].
Brightness _platformBrightness() =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness;

Brightness _resolveBrightness(AppBrightnessMode mode) => switch (mode) {
      AppBrightnessMode.light => Brightness.light,
      AppBrightnessMode.dark => Brightness.dark,
      AppBrightnessMode.system => _platformBrightness(),
    };

/// Persisted appearance preference: three independent choices — color
/// family, shape vibe, brightness — rather than one flat skin name.
///
/// Defaults to [AppAppearance.defaultAppearance] (Calming / Curvy / Light)
/// until a saved choice loads from
/// [SharedPreferences]. A rider who already had a skin picked under the old
/// single-key scheme has it decoded via [_legacyTriple] on first load under
/// this build, then persisted forward under the three new keys.
class AppearanceNotifier extends StateNotifier<AppAppearance>
    with WidgetsBindingObserver {
  AppearanceNotifier() : super(AppAppearance.defaultAppearance) {
    WidgetsBinding.instance.addObserver(this);
    _loadPersisted();
  }

  /// The OS flipped between light and dark. Only acted on while the rider has
  /// chosen [AppBrightnessMode.system].
  @override
  void didChangePlatformBrightness() {
    if (state.brightnessMode != AppBrightnessMode.system) return;
    final resolved = _platformBrightness();
    if (resolved == state.brightness) return;
    final next = state.copyWith(brightness: resolved);
    state = next;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      final mode = _decodeBrightnessMode(rawBrightness) ??
          AppAppearance.defaultAppearance.brightnessMode;
      resolved = AppAppearance(
        colorMode: _decodeColorMode(rawColorMode) ?? AppAppearance.defaultAppearance.colorMode,
        shapeVibe: _decodeShapeVibe(rawShapeVibe) ?? AppAppearance.defaultAppearance.shapeVibe,
        brightnessMode: mode,
        brightness: _resolveBrightness(mode),
      );
    }

    if (resolved == state) return;
    state = resolved;
  }

  Future<void> setColorMode(AppColorMode colorMode) async {
    if (colorMode == state.colorMode) return;
    final next = state.copyWith(colorMode: colorMode);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorModeKey, colorMode.name);
  }

  Future<void> setShapeVibe(AppShapeVibe shapeVibe) async {
    if (shapeVibe == state.shapeVibe) return;
    final next = state.copyWith(shapeVibe: shapeVibe);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shapeVibeKey, shapeVibe.name);
  }

  /// Sets how brightness is chosen. [AppBrightnessMode.system] resolves
  /// against the OS now and keeps tracking it via
  /// [didChangePlatformBrightness].
  Future<void> setBrightnessMode(AppBrightnessMode mode) async {
    if (mode == state.brightnessMode) return;
    final next = state.copyWith(
      brightnessMode: mode,
      brightness: _resolveBrightness(mode),
    );
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brightnessKey, mode.name);
  }
}

final appearanceProvider =
    StateNotifierProvider<AppearanceNotifier, AppAppearance>(
        (ref) => AppearanceNotifier());
