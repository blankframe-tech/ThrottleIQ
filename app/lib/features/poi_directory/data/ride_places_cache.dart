import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:throttleiq/core/utils/geohash_util.dart';
import 'package:throttleiq/features/poi_directory/data/models/place_model.dart';
import 'package:throttleiq/features/poi_directory/data/repositories/place_repository.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';

/// On-device copy of the places around where the rider rides (issues
/// §104.1). The live ride used to read every place within 25 km from
/// Firestore at the start and after each 5 km. Now each geohash cell is read
/// whole once, and later refreshes pull only the places written since the
/// last pull (`updatedAt > lastPull`, like the ride sync's `syncedAt`).
///
/// One instance (`placesCacheProvider`) serves both the live ride (10 km
/// around the rider, every 5 km of riding, so a regular route stays cached
/// well past 5 km either side) and the Places tab. Settings clears it.
///
/// shortcut: a rating change doesn't touch `updatedAt`, so a cached list
/// card can show a rating up to [cellMaxAge] old (the detail screen streams
/// it live); bump `updatedAt` in the review write if that matters.
class RidePlacesCache {
  RidePlacesCache({
    required this.fetchCell,
    required this.fetchSince,
    Future<File>? file,
    DateTime Function()? clock,
  })  : _file = file ?? _defaultFile(),
        _clock = clock ?? DateTime.now;

  /// Every place in one geohash cell, from the server.
  final Future<List<PlaceEntity>> Function(String cell) fetchCell;

  /// Places with a server `updatedAt` after the given time, and the newest
  /// such `updatedAt`.
  final Future<(List<PlaceEntity>, DateTime?)> Function(DateTime since)
      fetchSince;

  final Future<File> _file;
  final DateTime Function() _clock;

  /// shortcut: deletions and admin-script writes (no `updatedAt`) reach the
  /// cache only when a cell is re-read after this; add a tombstone field if
  /// they must show sooner.
  static const cellMaxAge = Duration(days: 3);

  DateTime? _lastPull;
  // Refreshes and clears run one at a time: they share the file and maps.
  Future<void> _queue = Future.value();
  final Map<String, DateTime> _cellReadAt = {};
  final Map<String, PlaceEntity> _places = {};
  bool _loaded = false;

  static Future<File> _defaultFile() async => File(
      '${(await getApplicationSupportDirectory()).path}/ride_places_cache.json');

  /// Cached places within [radiusKm] of ([lat], [lng]), nearest first.
  /// No network.
  Future<List<PlaceEntity>> nearby(
      double lat, double lng, double radiusKm) async {
    await _load();
    return PlaceRepository.nearbyViaGeohashRanges(
      latitude: lat,
      longitude: lng,
      radiusKm: radiusKm,
      now: _clock(),
      fetchRange: (prefix, _) async => [
        for (final p in _places.values)
          if (p.geohash.startsWith(prefix)) p,
      ],
    );
  }

  /// Pulls what changed since the last pull, then reads whole any cell
  /// around ([lat], [lng]) that is new or older than [cellMaxAge]. Throws
  /// when offline; what was pulled before the failure is kept.
  Future<void> refresh(double lat, double lng, double radiusKm) =>
      _serial(() => _refresh(lat, lng, radiusKm));

  /// Forgets every cached place, on the device and on disk.
  Future<void> clear() => _serial(() async {
        _loaded = true;
        _lastPull = null;
        _cellReadAt.clear();
        _places.clear();
        final file = await _file;
        if (await file.exists()) await file.delete();
      });

  Future<void> _serial(Future<void> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.catchError((_) {});
    return next;
  }

  /// When [cell] or any coarser cell containing it was last read whole.
  DateTime? _readAt(String cell) {
    DateTime? newest;
    for (var i = 1; i <= cell.length; i++) {
      final t = _cellReadAt[cell.substring(0, i)];
      if (t != null && (newest == null || t.isAfter(newest))) newest = t;
    }
    return newest;
  }

  Future<void> _refresh(double lat, double lng, double radiusKm) async {
    await _load();
    final now = _clock();
    try {
      // The first watermark is the device clock a day back, so a fast clock
      // skips nothing. Every later one is a server `updatedAt`.
      final since = _lastPull ?? now.subtract(const Duration(days: 1));
      final (changed, newest) = await fetchSince(since);
      for (final p in changed) {
        _places[p.id] = p;
      }
      _lastPull = newest ?? since;

      for (final cell in GeohashUtil.coverCircle(lat, lng, radiusKm)) {
        // The Places tab reads coarser cells than the ride; either counts.
        final readAt = _readAt(cell);
        if (readAt != null && now.difference(readAt) < cellMaxAge) continue;
        final places = await fetchCell(cell);
        // Whole-cell read: drops places deleted on the server.
        _places.removeWhere((_, p) => p.geohash.startsWith(cell));
        for (final p in places) {
          _places[p.id] = p;
        }
        _cellReadAt[cell] = now;
      }
    } finally {
      _places.removeWhere((_, p) => p.isExpiredAt(now));
      await _save();
    }
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _file;
      if (!await file.exists()) return;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final lastPull = json['lastPull'] as int?;
      _lastPull = lastPull == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastPull);
      (json['cells'] as Map<String, dynamic>).forEach((cell, ms) =>
          _cellReadAt[cell] = DateTime.fromMillisecondsSinceEpoch(ms as int));
      (json['places'] as Map<String, dynamic>).forEach((id, data) =>
          _places[id] =
              PlaceModel.fromMap(id, data as Map<String, dynamic>).toEntity());
    } catch (e) {
      // A bad file costs one full pull, never the ride.
      debugPrint('[RidePlacesCache] dropping unreadable cache: $e');
      _lastPull = null;
      _cellReadAt.clear();
      _places.clear();
    }
  }

  Future<void> _save() async {
    final file = await _file;
    await file.parent.create(recursive: true);
    // Write then rename, so a kill mid-write leaves the old file whole.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'lastPull': _lastPull?.millisecondsSinceEpoch,
      'cells': {
        for (final e in _cellReadAt.entries)
          e.key: e.value.millisecondsSinceEpoch,
      },
      'places': {
        for (final p in _places.values)
          p.id: PlaceModel.fromEntity(p).toCacheJson(),
      },
    }));
    await tmp.rename(file.path);
  }
}
