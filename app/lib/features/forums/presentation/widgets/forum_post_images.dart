import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../social/presentation/widgets/ride_media_collage.dart';

/// A post's photos. One photo fills the width; several sit in a row of
/// square tiles. Tapping one opens the shared full-screen gallery.
///
/// [compact] is the feed-card size (shorter single photo, smaller tiles).
class ForumPostImages extends StatelessWidget {
  final List<String> urls;
  final bool compact;

  const ForumPostImages({super.key, required this.urls, this.compact = false});

  void _open(BuildContext context, int index) {
    showDialog<void>(
      context: context,
      builder: (_) => FullScreenGalleryDialog(urls: urls, initialIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final radius = BorderRadius.circular(context.shape.radiusMd);
    if (urls.length == 1) {
      return GestureDetector(
        key: const Key('forum_post_image_0'),
        onTap: () => _open(context, 0),
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            height: compact ? 160 : 220,
            width: double.infinity,
            child: CollageNetworkPhoto(url: urls.first),
          ),
        ),
      );
    }
    final size = compact ? 72.0 : 96.0;
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          key: Key('forum_post_image_$i'),
          onTap: () => _open(context, i),
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              width: size,
              height: size,
              child: CollageNetworkPhoto(url: urls[i]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The composer's picked-but-not-yet-uploaded photos, each with a remove
/// button.
class ForumPickedPhotos extends StatelessWidget {
  final List<String> paths;
  final void Function(int index) onRemove;

  const ForumPickedPhotos({super.key, required this.paths, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.shape.radiusMd);
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Stack(
          children: [
            ClipRRect(
              borderRadius: radius,
              child: Image.file(
                File(paths[i]),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: context.palette.background,
                  child: Icon(Icons.broken_image_outlined, color: context.palette.textTertiary),
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  key: Key('forum_remove_photo_$i'),
                  customBorder: const CircleBorder(),
                  onTap: () => onRemove(i),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
