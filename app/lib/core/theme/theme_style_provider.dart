import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'app_shape_profile.dart';
import 'app_theme_style.dart';
import 'app_typography.dart';

const _prefsKey = 'theme_style';

/// The two values written before skins existed. Everything since persists
/// `AppThemeStyle.name` verbatim, but riders who picked a theme on an older
/// build still have one of these on disk — decoding them keeps their choice.
const _legacyValues = <String, AppThemeStyle>{
  'carbon': AppThemeStyle.carbonMono,
  'editorial': AppThemeStyle.editorial,
};

/// The value written for [style]. Editorial keeps its historical spelling so
/// a rider who switches skins on this build and then rolls back to an older
/// one doesn't lose the setting; Carbon Mono is the default either way.
String _encode(AppThemeStyle style) =>
    style == AppThemeStyle.carbonMono ? 'carbon' : style.name;

AppThemeStyle? _decode(String? saved) {
  if (saved == null) return null;
  final legacy = _legacyValues[saved];
  if (legacy != null) return legacy;
  for (final style in AppThemeStyle.values) {
    if (style.name == saved) return style;
  }
  // An unknown value — a skin removed since it was written, or a downgrade.
  // Falling through to null leaves the default in place.
  return null;
}

/// Persisted appearance preference. Defaults to [AppThemeStyle.carbonMono]
/// (the app's primary design language) until a saved choice loads from
/// [SharedPreferences], matching the pattern used for local prefs elsewhere
/// (see `ride_recording_provider.dart`'s `active_ride_id` usage).
class ThemeStyleNotifier extends StateNotifier<AppThemeStyle> {
  ThemeStyleNotifier() : super(AppThemeStyle.carbonMono) {
    _applyTokens(AppThemeStyle.carbonMono);
    _loadPersisted();
  }

  /// Pushes [style] into every static token facade at once.
  ///
  /// [AppColors] is not the only one any more: a skin also carries a shape
  /// profile (see [AppShapeProfile] — rounded corners on some directions, sharp
  /// instrument-panel edges on others) and, for Retro, a different display
  /// typeface (see [AppTypography]). Applying all three together in one place
  /// is what stops a skin from ending up half-applied — the failure mode being
  /// mono type or another skin's corner radius left behind on the next skin the
  /// rider picks.
  void _applyTokens(AppThemeStyle style) {
    AppColors.apply(AppColorPalette.forStyle(style));
    AppDimensions.apply(AppShapeProfile.forStyle(style));
    AppTypography.applyStyle(style);
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // disposed while the read was in flight
    final saved = _decode(prefs.getString(_prefsKey));
    if (saved == null || saved == state) return;
    _applyTokens(saved);
    state = saved;
  }

  Future<void> setStyle(AppThemeStyle style) async {
    if (style == state) return;
    _applyTokens(style);
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _encode(style));
  }
}

final themeStyleProvider =
    StateNotifierProvider<ThemeStyleNotifier, AppThemeStyle>(
        (ref) => ThemeStyleNotifier());
