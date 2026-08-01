import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'app_theme_style.dart';

const _prefsKey = 'theme_style';
const _carbonValue = 'carbon';
const _editorialValue = 'editorial';

/// Persisted appearance preference. Defaults to [AppThemeStyle.carbonMono]
/// (the app's primary design language) until a saved choice loads from
/// [SharedPreferences], matching the pattern used for local prefs elsewhere
/// (see `ride_recording_provider.dart`'s `active_ride_id` usage).
class ThemeStyleNotifier extends StateNotifier<AppThemeStyle> {
  ThemeStyleNotifier() : super(AppThemeStyle.carbonMono) {
    AppColors.apply(AppColorPalette.carbonMono);
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // disposed while the read was in flight
    final saved = prefs.getString(_prefsKey);
    if (saved == _editorialValue && state != AppThemeStyle.editorial) {
      AppColors.apply(AppColorPalette.editorial);
      state = AppThemeStyle.editorial;
    }
  }

  Future<void> setStyle(AppThemeStyle style) async {
    if (style == state) return;
    AppColors.apply(AppColorPalette.forStyle(style));
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      style == AppThemeStyle.carbonMono ? _carbonValue : _editorialValue,
    );
  }
}

final themeStyleProvider =
    StateNotifierProvider<ThemeStyleNotifier, AppThemeStyle>(
        (ref) => ThemeStyleNotifier());
