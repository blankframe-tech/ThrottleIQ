import 'package:flutter/material.dart';

/// Per-rider marker colours for the shared group-ride map.
///
/// These are deliberately NOT `AppColors.*`: those are theme-dependent getters
/// that shift with light/dark mode, and a rider's dot changing hue when the
/// theme flips would break the one thing this palette exists to guarantee —
/// "the orange dot is always Sam". Fixed, const, high-contrast against the
/// OpenStreetMap raster tiles, and ordered so adjacent entries never sit next
/// to each other on the colour wheel.
const List<Color> kGroupRideMemberPalette = <Color>[
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFB8C00), // orange
  Color(0xFF8E24AA), // purple
  Color(0xFF00ACC1), // cyan
  Color(0xFFD81B60), // pink
  Color(0xFF6D4C41), // brown
  Color(0xFF3949AB), // indigo
  Color(0xFF7CB342), // lime
  Color(0xFFF4511E), // deep orange
];

/// A stable hash of [userId] in `[0, 2^31)`.
///
/// Hand-rolled (FNV-1a) rather than `userId.hashCode` on purpose: Dart's
/// String.hashCode is only guaranteed stable within a single isolate run, so
/// using it would let a rider's colour change between app launches — which is
/// exactly the "same rider, same colour" property this file promises.
int stableUserIdHash(String userId) {
  var hash = 0x811c9dc5;
  for (final unit in userId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// The marker colour for one group-ride member.
///
/// [index] is the member's position in a *stably ordered* member list (the
/// map screen sorts by userId before calling this), which is what keeps a
/// rider's colour fixed across rebuilds — colours are never drawn at random
/// per frame. Pass a negative [index] when the position isn't known; the
/// colour then falls back to a stable hash of [userId] so the rider still
/// keeps one consistent colour.
///
/// Indices past the palette length wrap safely rather than throwing, and each
/// wrap darkens the base colour a step so an 12th/23rd rider is still visually
/// distinct from the rider sharing their palette slot.
Color colorForMember(String userId, int index) {
  final slot = index >= 0 ? index : stableUserIdHash(userId);
  final base = kGroupRideMemberPalette[slot % kGroupRideMemberPalette.length];
  final wraps = slot ~/ kGroupRideMemberPalette.length;
  if (wraps == 0) return base;

  final hsl = HSLColor.fromColor(base);
  final lightness = (hsl.lightness - 0.13 * wraps).clamp(0.18, 0.92);
  return hsl.withLightness(lightness).toColor();
}

/// Black or white, whichever stays legible on top of [background]. Used for
/// the initial drawn inside a member's marker dot.
Color onMemberColor(Color background) {
  return background.computeLuminance() > 0.55 ? Colors.black : Colors.white;
}
