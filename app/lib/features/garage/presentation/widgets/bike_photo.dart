import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/bike_image_resolver.dart';

/// The rider's own photo of a bike, with a guaranteed fallback.
///
/// Handles both local file paths and remote URLs (e.g. Cloudinary).
/// For local paths, [BikeImageResolver] resolves stale container UUIDs across
/// app rebuilds/updates. For remote URLs, [CachedNetworkImage] fetches and caches
/// the photo across device reinstalls and multi-device logins.
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

  /// Optional override for the documents directory (useful for unit testing
  /// container UUID shifts).
  final Directory? documentsDirectory;

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
    this.documentsDirectory,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final radius =
        borderRadius ?? BorderRadius.circular(AppDimensions.radiusMd);

    Widget content;
    if (path == null || path.isEmpty) {
      content = _fallback();
    } else if (BikeImageResolver.isRemoteUrl(path)) {
      content = CachedNetworkImage(
        imageUrl: path,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    } else {
      final resolved = BikeImageResolver.resolvePathSync(
        path,
        documentsDirectory: documentsDirectory,
      );
      if (resolved == null) {
        content = _fallback();
      } else {
        content = Image.file(
          File(resolved),
          width: width,
          height: height,
          fit: fit,
          // File deleted / unreadable / not an image any more.
          errorBuilder: (_, __, ___) => _fallback(),
        );
      }
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: content,
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
