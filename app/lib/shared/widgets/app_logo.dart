import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/theme_style_provider.dart';

/// The ThrottleIQ mark, swapping between the light and dark SVG per the
/// current appearance preference (see `theme_style_provider.dart`).
///
/// Which of the two marks shows follows [AppAppearance.brightness] directly
/// — not the color mode — since every dark appearance wants the dark mark
/// regardless of which of the seven color families it's paired with.
class AppLogo extends ConsumerWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(appearanceProvider).brightness;
    final asset = brightness == Brightness.dark
        ? 'assets/icons/throttleiq-icon-dark.svg'
        : 'assets/icons/throttleiq-icon-light.svg';
    return SvgPicture.asset(asset, width: size, height: size);
  }
}
