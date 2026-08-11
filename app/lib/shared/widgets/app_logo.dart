import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme_style.dart';
import '../../core/theme/theme_style_provider.dart';

/// The ThrottleIQ mark, swapping between the light and dark SVG per the
/// current appearance preference (see `theme_style_provider.dart`).
///
/// Which of the two marks a skin gets follows the skin's base brightness,
/// not its identity — every dark skin wants the dark mark.
class AppLogo extends ConsumerWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(themeStyleProvider);
    final asset = AppColorPalette.forStyle(style).isDark
        ? 'assets/icons/throttleiq-icon-dark.svg'
        : 'assets/icons/throttleiq-icon-light.svg';
    return SvgPicture.asset(asset, width: size, height: size);
  }
}
