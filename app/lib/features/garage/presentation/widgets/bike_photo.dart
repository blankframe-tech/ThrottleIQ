import 'dart:io';

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// The rider's own photo of a bike, with a guaranteed fallback.
///
/// `BikeEntity.imagePath` is a **local device file path**, so it is unreliable
/// in two distinct ways and both have to be handled at render time:
///
///  * it can be null — the rider never attached a photo, or the bike arrived
///    from another device (`CloudRepository.downloadBikes` deliberately nulls
///    `image_path` on pulled bikes, since a path from someone else's phone
///    means nothing here);
///  * it can be non-null but *stale* — the file was moved or cleaned up by the
///    OS after the path was saved. `Image.file` only discovers this while
///    decoding, i.e. asynchronously, and without an `errorBuilder` that
///    surfaces as a red error box in the widget tree.
///
/// So: null/empty path short-circuits to the icon, and a decode failure falls
/// back to the same icon via [Image.errorBuilder]. The bike tile never renders
/// broken and never throws.
class BikePhoto extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;

  /// Corner rounding. Defaults to [AppDimensions.radiusMd]; pass a
  /// `BorderRadius.vertical(...)` for a card's top photo strip.
  final BorderRadius? borderRadius;

  /// Fallback icon size — scale it with the tile (24 for a 44px thumbnail,
  /// 72 for a detail hero).
  final double iconSize;

  /// Fill behind the fallback icon. Pass [Colors.transparent] when the parent
  /// already paints its own surface.
  final Color? backgroundColor;
  final Color? iconColor;
  final BoxFit fit;

  const BikePhoto({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.borderRadius,
    this.iconSize = 24,
    this.backgroundColor,
    this.iconColor,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final radius =
        borderRadius ?? BorderRadius.circular(AppDimensions.radiusMd);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: path == null || path.isEmpty
            ? _fallback()
            : Image.file(
                File(path),
                width: width,
                height: height,
                fit: fit,
                // File deleted / unreadable / not an image any more.
                errorBuilder: (_, __, ___) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: backgroundColor ?? AppColors.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(
          Icons.two_wheeler,
          size: iconSize,
          color: iconColor ?? AppColors.textTertiary,
        ),
      );
}
