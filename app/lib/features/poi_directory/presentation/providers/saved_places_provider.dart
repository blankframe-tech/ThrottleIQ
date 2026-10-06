import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/saved_places_repository.dart';
import '../../domain/entities/place_entity.dart';

final savedPlacesRepositoryProvider =
    Provider<SavedPlacesRepository>((_) => SavedPlacesRepository());

/// The signed-in rider's bookmarked places (Saved tab), newest first. Local
/// SQLite only — see [SavedPlacesRepository].
class SavedPlacesNotifier extends AsyncNotifier<List<PlaceEntity>> {
  @override
  Future<List<PlaceEntity>> build() async {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) return const [];
    return ref.watch(savedPlacesRepositoryProvider).savedPlaces(uid);
  }

  /// Saves [place] if it isn't saved yet, otherwise removes it. Returns the
  /// new saved state, or null when nobody is signed in (nothing to key the
  /// bookmark to).
  ///
  /// The list updates optimistically — the star on the card flips in the
  /// same frame as the tap — and is reloaded from disk if the write fails.
  Future<bool?> toggle(PlaceEntity place) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return null;
    final repo = ref.read(savedPlacesRepositoryProvider);
    final current = state.valueOrNull ?? const <PlaceEntity>[];
    final wasSaved = current.any((p) => p.id == place.id);

    state = AsyncData(wasSaved
        ? [for (final p in current) if (p.id != place.id) p]
        : [place, ...current]);
    try {
      if (wasSaved) {
        await repo.remove(uid, place.id);
      } else {
        await repo.save(uid, place);
      }
      return !wasSaved;
    } on Object {
      ref.invalidateSelf();
      rethrow;
    }
  }
}

final savedPlacesProvider =
    AsyncNotifierProvider<SavedPlacesNotifier, List<PlaceEntity>>(SavedPlacesNotifier.new);

/// Ids of saved places, for the bookmark toggle on every card.
final savedPlaceIdsProvider = Provider<Set<String>>((ref) {
  final saved = ref.watch(savedPlacesProvider).valueOrNull ?? const [];
  return {for (final p in saved) p.id};
});
