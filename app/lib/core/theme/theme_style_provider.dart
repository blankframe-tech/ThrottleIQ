import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _brightnessKey = 'brightness';

/// Keys older builds wrote. Only read, to migrate a rider's pick to the
/// nearest of the two remaining themes — see [AppearanceNotifier._loadPersisted].
/// `color_mode`/`shape_vibe` held one of 7 color families x 2 shapes (cut
/// 2026-10-14); `theme_style` is the single-key skin from before that.
const _colorModeKey = 'color_mode';
const _shapeVibeKey = 'shape_vibe';
const _legacyThemeStyleKey = 'theme_style';

/// The pre-split single-key skins that were dark. Every other value was a
/// light skin (or `genesis`, which already fell back to the light default).
const _legacyDarkSkins = {
  'carbon',
  'nocturne',
  'trailSocial',
  'analystBlue',
  'cuteAnalyst',
};

/// How the app decides between the light and dark palette.
///
/// [system] follows the OS setting and re-resolves whenever the platform
/// flips — the option every other app on the phone has and this one didn't
/// (issues §83.9). It is separate from the resolved [Brightness] because
/// "the rider chose dark" and "the rider chose system, and the system is
/// currently dark" have to be told apart when the OS changes underneath us.
enum AppBrightnessMode { light, dark, system }

/// The rider's appearance: light or dark, chosen directly or by the OS.
/// Each brightness has exactly one theme (`AppColorPalette.forBrightness`).
@immutable
class AppAppearance {
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
    required this.brightness,
    AppBrightnessMode? brightnessMode,
  }) : _brightnessMode = brightnessMode;

  /// Light — the default for every new install.
  static const defaultAppearance = AppAppearance(brightness: Brightness.light);

  @override
  bool operator ==(Object other) =>
      other is AppAppearance &&
      other.brightness == brightness &&
      other.brightnessMode == brightnessMode;

  @override
  int get hashCode => Object.hash(brightness, brightnessMode);
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

/// Persisted appearance preference: Light, Dark or System.
///
/// Defaults to [AppAppearance.defaultAppearance] (Light) until a saved
/// choice loads from [SharedPreferences].
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
    state = AppAppearance(
        brightness: resolved, brightnessMode: AppBrightnessMode.system);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A rider on a removed color family or shape keeps their brightness
  /// choice, which picks the nearest remaining theme: any light family →
  /// the light theme, any dark one → the dark theme. A rider who only ever
  /// changed color or shape was on light, so stays light.
  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // disposed while the read was in flight

    var mode = _decodeBrightnessMode(prefs.getString(_brightnessKey));
    final usedSplitScheme =
        prefs.containsKey(_colorModeKey) || prefs.containsKey(_shapeVibeKey);
    final legacy = prefs.getString(_legacyThemeStyleKey);
    if (mode == null && !usedSplitScheme && legacy != null) {
      mode = _legacyDarkSkins.contains(legacy)
          ? AppBrightnessMode.dark
          : AppBrightnessMode.light;
    }
    if (mode == null) return; // nothing saved: keep the default

    final resolved = AppAppearance(
        brightness: _resolveBrightness(mode), brightnessMode: mode);
    if (resolved == state) return;
    state = resolved;
  }

  /// Sets how brightness is chosen. [AppBrightnessMode.system] resolves
  /// against the OS now and keeps tracking it via
  /// [didChangePlatformBrightness].
  Future<void> setBrightnessMode(AppBrightnessMode mode) async {
    if (mode == state.brightnessMode) return;
    state = AppAppearance(
        brightness: _resolveBrightness(mode), brightnessMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brightnessKey, mode.name);
  }
}

final appearanceProvider =
    StateNotifierProvider<AppearanceNotifier, AppAppearance>(
        (ref) => AppearanceNotifier());
