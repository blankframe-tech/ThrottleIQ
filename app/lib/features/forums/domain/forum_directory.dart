import '../../../core/utils/slugify.dart';
import 'entities/forum_entity.dart';

/// The fixed part of the Hubs directory: brand paddocks and topic boards.
///
/// Both are deterministic forums (`bikeForumSlug(brand)` /
/// `generalForumSlug(topic)`) that may not exist yet — opening one creates
/// it. Their stored [topic]/[brand] strings ARE the forum identity, so they
/// must never be renamed here; the board names riders see ("The Wrench
/// Bench") are presentation, mapped in the Hubs view.

/// A brand's paddock card. [accent] is an ARGB int (the brand's livery
/// color) so this file stays free of Flutter imports.
class BrandPaddock {
  final String brand;
  final int accent;
  const BrandPaddock(this.brand, this.accent);

  String get slug => bikeForumSlug(brand);
}

const List<BrandPaddock> kBrandPaddocks = [
  BrandPaddock('Yamaha', 0xFF1F4FD8),
  BrandPaddock('Honda', 0xFFD62828),
  BrandPaddock('Royal Enfield', 0xFFB08D57),
  BrandPaddock('KTM', 0xFFFF6A00),
  BrandPaddock('Bajaj', 0xFF1565C0),
  BrandPaddock('TVS', 0xFF283593),
  BrandPaddock('Suzuki', 0xFF0050A0),
  BrandPaddock('Kawasaki', 0xFF4CAF1A),
  BrandPaddock('Hero', 0xFFE53935),
];

/// Topic boards, in bento order. The first four are the featured
/// "clusters" (rendered larger).
enum TopicBoard {
  wrenchBench('Maintenance', 0xFF2E7D32),
  sparkPlugCorner('Spark Plug Corner', 0xFFF9A825),
  apexLab('Riding Skills', 0xFFD84315),
  twoStrokeSmoke('Two-Strokes', 0xFF6D4C41),
  engineRebuild('Engine Rebuild', 0xFF455A64),
  oilReviews('Engine Oil Review', 0xFF8D6E00),
  dirtTrails('Dirt Bikes', 0xFF795548),
  mileageLab('Mileage Tips', 0xFF00838F);

  /// The general forum's topic — its identity, see the file comment.
  final String topic;
  final int accent;
  const TopicBoard(this.topic, this.accent);

  String get slug => generalForumSlug(topic);

  bool get featured => index < 4;
}

/// Every directory forum id — the ids the Hubs view reads stats for in one
/// bounded `documentId in [...]` query.
List<String> directoryForumIds() => [
      for (final b in kBrandPaddocks) b.slug,
      for (final t in TopicBoard.values) t.slug,
    ];

/// A brand paddock's activity: the brand forum plus every model forum under
/// that brand. Riders post and follow in model forums ("Yamaha MT-15"), and
/// the brand thread merges those posts in, so the brand doc's own counts
/// alone read as zero while the paddock is busy.
class BrandPaddockStats {
  final int riders;
  final int posts;
  const BrandPaddockStats({required this.riders, required this.posts});

  static const empty = BrandPaddockStats(riders: 0, posts: 0);
}

/// Sums follower and post counts per paddock slug over [forums] (brand and
/// model forums, matched on `brand`, case-insensitively). General/custom
/// forums are left out even if they share a brand string. `riders` sums
/// follows across forums, so a rider following two of a brand's forums
/// counts twice.
Map<String, BrandPaddockStats> aggregateBrandPaddockStats(
  List<ForumEntity> forums, {
  List<BrandPaddock> paddocks = kBrandPaddocks,
}) {
  final byBrand = {for (final p in paddocks) p.brand.toLowerCase(): p.slug};
  final riders = <String, int>{};
  final posts = <String, int>{};
  for (final f in forums) {
    if (f.type != ForumType.brand && f.type != ForumType.bikeModel) continue;
    final slug = byBrand[f.brand.trim().toLowerCase()];
    if (slug == null) continue;
    riders[slug] = (riders[slug] ?? 0) + f.followerCount;
    posts[slug] = (posts[slug] ?? 0) + f.postCount;
  }
  return {
    for (final slug in {...riders.keys, ...posts.keys})
      slug: BrandPaddockStats(riders: riders[slug] ?? 0, posts: posts[slug] ?? 0),
  };
}
