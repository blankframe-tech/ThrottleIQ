import 'dart:io';

import 'package:flutter/material.dart';
import '../../features/garage/domain/entities/bike_entity.dart';

/// Preset paint colors offered in the bike color picker — the common liveries
/// riders actually see on showroom floors, not an arbitrary wheel.
const List<Color> bikeColorPalette = [
  Color(0xFFE53935), // Racing red
  Color(0xFFFB8C00), // Inferno orange
  Color(0xFFFDD835), // Sunburst yellow
  Color(0xFF43A047), // Racing green
  Color(0xFF00897B), // Ocean teal
  Color(0xFF1E88E5), // Electric blue
  Color(0xFF3949AB), // Midnight indigo
  Color(0xFF8E24AA), // Purple haze
  Color(0xFFD81B60), // Hot pink
  Color(0xFF6D4C41), // Saddle brown
  Color(0xFF757575), // Gunmetal grey
  Color(0xFF212121), // Graphite black
];

/// The color to tint that bike's screens with: what the rider picked, or —
/// when they never picked one — a stable pick from [bikeColorPalette] keyed
/// off the bike's id, so two bikes without an explicit color still read as
/// visually distinct rather than all falling back to the same neutral accent.
Color bikeAccentColor(BikeEntity bike) {
  final explicit = bike.color;
  if (explicit != null) return explicit;
  return bikeColorPalette[bike.id.hashCode.abs() % bikeColorPalette.length];
}

/// Whether [bike] has an actual photo to show — not just a non-null path,
/// since `imagePath` can point at a file the OS has since cleaned up (see
/// `BikePhoto`'s doc). Tinting a screen to match a photo that isn't there
/// reads as a mismatch (colored wash next to the generic icon tile), so
/// callers should gate on this before using [bikeAccentColor].
bool bikeHasPhoto(BikeEntity bike) {
  final path = bike.imagePath;
  return path != null && path.isNotEmpty && File(path).existsSync();
}
