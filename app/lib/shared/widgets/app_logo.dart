import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The ThrottleIQ mark. Always the dark version, regardless of the current
/// appearance — the mark is a fixed brand identity, not a themed asset.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/throttleiq-icon-dark.svg',
      width: size,
      height: size,
    );
  }
}
