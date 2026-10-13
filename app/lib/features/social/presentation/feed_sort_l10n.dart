import '../../../l10n/app_localizations.dart';
import '../domain/feed_sort.dart';

/// [FeedSortLabel.label] in the rider's language (the domain getter stays English).
extension FeedSortL10n on FeedSort {
  String localizedLabel(AppLocalizations l) => switch (this) {
        FeedSort.hot => l.feedSortHot,
        FeedSort.recent => l.sortRecent,
        FeedSort.following => l.following,
      };
}
