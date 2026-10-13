import '../../../l10n/app_localizations.dart';
import '../domain/ride_sort.dart';

/// [RideSortLabel.label] in the rider's language (the domain getter stays
/// English for tests and diagnostics).
extension RideSortL10n on RideSort {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        RideSort.recent => l10n.sortRecent,
        RideSort.topSpeed => l10n.topSpeed,
        RideSort.longestDistance => l10n.distanceLabel,
        RideSort.longestDuration => l10n.duration,
        RideSort.bestScore => l10n.bestScore,
      };
}
