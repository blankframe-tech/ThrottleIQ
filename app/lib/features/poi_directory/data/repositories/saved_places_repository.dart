import '../../../../core/database/daos/saved_place_dao.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/place_tags.dart';

/// Local (SQLite) bookmarks behind the Places hub's Saved tab.
///
/// Deliberately device-local rather than a Firestore collection: a bookmark
/// is a personal shortcut, it has to work with no signal, and keeping it off
/// the network costs zero reads per tab open.
class SavedPlacesRepository {
  final SavedPlaceDao _dao;

  SavedPlacesRepository({SavedPlaceDao? dao}) : _dao = dao ?? SavedPlaceDao();

  Future<List<PlaceEntity>> savedPlaces(String userId) async {
    final rows = await _dao.allForUser(userId);
    return [for (final row in rows) fromRow(row)];
  }

  Future<void> save(String userId, PlaceEntity place, {DateTime? now}) =>
      _dao.upsert(toRow(userId, place, savedAt: now ?? DateTime.now()));

  Future<void> remove(String userId, String placeId) => _dao.remove(userId, placeId);

  static Map<String, dynamic> toRow(
    String userId,
    PlaceEntity place, {
    required DateTime savedAt,
  }) {
    return {
      'user_id': userId,
      'place_id': place.id,
      'name': place.name,
      'category': place.category.name,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'address': place.address,
      'phone': place.phone,
      'hours': place.hours,
      'tags': [for (final t in PlaceTag.values) if (place.tags.contains(t)) t.name].join(','),
      'verified': place.verified ? 1 : 0,
      'saved_at': savedAt.toUtc().toIso8601String(),
    };
  }

  /// Rebuilds a [PlaceEntity] from a snapshot. Ratings and photos aren't
  /// kept (they go stale, and the detail screen streams the live doc anyway),
  /// so a saved place reads as unrated until opened.
  static PlaceEntity fromRow(Map<String, dynamic> row) {
    final savedAt = DateTime.tryParse(row['saved_at'] as String? ?? '');
    final tags = (row['tags'] as String?) ?? '';
    return PlaceEntity(
      id: row['place_id'] as String,
      name: row['name'] as String,
      category: PlaceCategory.fromString(row['category'] as String),
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      geohash: '',
      address: (row['address'] as String?) ?? '',
      phone: row['phone'] as String?,
      hours: row['hours'] as String?,
      verified: (row['verified'] as int? ?? 0) == 1,
      createdBy: '',
      createdAt: savedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      tags: PlaceTag.parseAll(tags.isEmpty ? const [] : tags.split(',')),
    );
  }
}
