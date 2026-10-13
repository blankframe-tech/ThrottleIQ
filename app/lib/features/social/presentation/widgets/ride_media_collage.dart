import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';

/// Space between collage tiles, in logical pixels.
const double kCollageGap = 3;

/// The most tiles a collage draws. Anything past this is folded into a "+N"
/// badge on the last visible tile.
const int kCollageMaxVisibleTiles = 5;

/// Where each tile of a ride-media collage goes.
///
/// [tileCount] counts every picture, the route map included: a ride with its
/// map and two photos is 3. Tile 0 is always the lead picture (the map when
/// there is one) and gets the largest slot. At most [kCollageMaxVisibleTiles]
/// rects are returned; the caller badges the last one with the overflow.
///
/// - 1: full-bleed.
/// - 2: side by side, the lead a little wider (3:2).
/// - 3: lead on the left, two stacked on the right.
/// - 4: lead across the top, three in a row underneath.
/// - 5+: lead on the left, a 2×2 grid on the right.
///
/// Pure geometry so it can be unit tested without pumping widgets.
List<Rect> rideMediaCollageLayout(
  int tileCount,
  Size size, {
  double gap = kCollageGap,
}) {
  final w = size.width;
  final h = size.height;
  if (tileCount <= 0 || w <= 0 || h <= 0) return const [];

  switch (tileCount) {
    case 1:
      return [Offset.zero & size];
    case 2:
      final leadW = (w - gap) * 0.6;
      return [
        Rect.fromLTWH(0, 0, leadW, h),
        Rect.fromLTWH(leadW + gap, 0, w - leadW - gap, h),
      ];
    case 3:
      final leadW = (w - gap) * 0.6;
      final sideX = leadW + gap;
      final sideW = w - sideX;
      final halfH = (h - gap) / 2;
      return [
        Rect.fromLTWH(0, 0, leadW, h),
        Rect.fromLTWH(sideX, 0, sideW, halfH),
        Rect.fromLTWH(sideX, halfH + gap, sideW, h - halfH - gap),
      ];
    case 4:
      final leadH = (h - gap) * 0.6;
      final rowY = leadH + gap;
      final rowH = h - rowY;
      final cellW = (w - 2 * gap) / 3;
      return [
        Rect.fromLTWH(0, 0, w, leadH),
        for (var i = 0; i < 3; i++)
          Rect.fromLTWH(i * (cellW + gap), rowY, cellW, rowH),
      ];
    default:
      final leadW = (w - gap) / 2;
      final gridX = leadW + gap;
      final cellW = (w - gridX - gap) / 2;
      final cellH = (h - gap) / 2;
      return [
        Rect.fromLTWH(0, 0, leadW, h),
        Rect.fromLTWH(gridX, 0, cellW, cellH),
        Rect.fromLTWH(gridX + cellW + gap, 0, cellW, cellH),
        Rect.fromLTWH(gridX, cellH + gap, cellW, cellH),
        Rect.fromLTWH(gridX + cellW + gap, cellH + gap, cellW, cellH),
      ];
  }
}

/// How many pictures hide behind the "+N" badge for [tileCount] tiles.
int rideMediaCollageOverflow(int tileCount) =>
    tileCount > kCollageMaxVisibleTiles
        ? tileCount - kCollageMaxVisibleTiles
        : 0;

/// A sensible collage height for [tileCount] tiles: a lone map keeps the
/// compact feed strip, anything with photos gets room to breathe.
double rideMediaCollageHeight(int tileCount) => tileCount <= 1 ? 160 : 220;

/// A ride's route map and photos laid out as one picture.
///
/// The map, when given, is just another tile — the lead one. [photoBuilder]
/// draws photo `i` (0-based over the photos only, not the tiles), so the same
/// widget serves network photos on the feed and local files in the share
/// composer. Tapping a photo reports its photo index to [onPhotoTap]; tapping
/// the map calls [onMapTap].
class RideMediaCollage extends StatelessWidget {
  /// The route-map tile, or null to lay out photos only.
  final Widget? map;
  final VoidCallback? onMapTap;

  final int photoCount;
  final Widget Function(BuildContext context, int index)? photoBuilder;
  final void Function(BuildContext context, int index)? onPhotoTap;

  /// Overall height; defaults to [rideMediaCollageHeight].
  final double? height;

  const RideMediaCollage({
    super.key,
    this.map,
    this.onMapTap,
    this.photoCount = 0,
    this.photoBuilder,
    this.onPhotoTap,
    this.height,
  }) : assert(photoCount == 0 || photoBuilder != null);

  /// A collage of network photo [urls] (plus an optional [map]) where tapping
  /// a photo opens the swipeable [FullScreenGalleryDialog] at that photo.
  factory RideMediaCollage.network({
    Key? key,
    Widget? map,
    VoidCallback? onMapTap,
    required List<String> urls,
    double? height,
  }) {
    return RideMediaCollage(
      key: key,
      map: map,
      onMapTap: onMapTap,
      photoCount: urls.length,
      photoBuilder: (_, i) => CollageNetworkPhoto(url: urls[i]),
      onPhotoTap: (context, i) => showDialog<void>(
        context: context,
        builder: (_) => FullScreenGalleryDialog(urls: urls, initialIndex: i),
      ),
      height: height,
    );
  }

  int get tileCount => (map != null ? 1 : 0) + photoCount;

  @override
  Widget build(BuildContext context) {
    final count = tileCount;
    if (count == 0) return const SizedBox.shrink();

    final radius = BorderRadius.circular(context.shape.radiusLg);
    final overflow = rideMediaCollageOverflow(count);
    final hasMap = map != null;

    return SizedBox(
      height: height ?? rideMediaCollageHeight(count),
      child: LayoutBuilder(builder: (context, constraints) {
        final rects = rideMediaCollageLayout(count, constraints.biggest);
        return Container(
          // Foreground, so the outline sits over the pictures rather than
          // behind them; without it a pale photo has no edge on a pale card.
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: context.palette.border,
              width: context.shape.outlineWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                for (var t = 0; t < rects.length; t++)
                  Positioned.fromRect(
                    rect: rects[t],
                    child: _buildTile(
                      context,
                      tile: t,
                      hasMap: hasMap,
                      overflow: t == rects.length - 1 ? overflow : 0,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required int tile,
    required bool hasMap,
    required int overflow,
  }) {
    if (hasMap && tile == 0) {
      return GestureDetector(
        key: const ValueKey('collage_map_tile'),
        behavior: HitTestBehavior.opaque,
        onTap: onMapTap,
        child: map,
      );
    }
    final photo = hasMap ? tile - 1 : tile;
    return GestureDetector(
      key: ValueKey('collage_photo_tile_$photo'),
      behavior: HitTestBehavior.opaque,
      onTap: onPhotoTap == null ? null : () => onPhotoTap!(context, photo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          photoBuilder!(context, photo),
          if (overflow > 0)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Text(
                '+$overflow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A cover-fit network photo for a collage tile, with quiet placeholder and
/// error states.
class CollageNetworkPhoto extends StatelessWidget {
  final String url;
  const CollageNetworkPhoto({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: context.palette.background),
      errorWidget: (_, __, ___) => Container(
        color: context.palette.background,
        child: Icon(Icons.broken_image,
            color: context.palette.textTertiary, size: 24),
      ),
    );
  }
}

/// Fullscreen lightbox allowing pinch-to-zoom and swiping between all photos.
class FullScreenGalleryDialog extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const FullScreenGalleryDialog({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<FullScreenGalleryDialog> createState() =>
      _FullScreenGalleryDialogState();
}

class _FullScreenGalleryDialogState extends State<FullScreenGalleryDialog> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final multiple = urls.length > 1;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              physics: multiple
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: urls[i],
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: context.l10n.close,
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (multiple)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          BorderRadius.circular(context.shape.radiusFull),
                    ),
                    child: Text(
                      '${_page + 1}/${urls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
