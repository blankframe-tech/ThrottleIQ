import '../../../core/utils/slugify.dart';

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
