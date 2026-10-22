import 'package:intl/intl.dart';

import '../../../core/i18n/numeric_locale.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/entities/place_entity.dart';

/// "Reported 2:14 PM · expires in 23 h" for a temporary rider report (a cop
/// checkpoint dropped from the ride menu). Null for every permanent place:
/// their `createdAt` is only when the place entered the directory, which says
/// nothing about whether it's still there.
String? placeReportLabel(PlaceEntity place, AppLocalizations l10n,
    {DateTime? now}) {
  final expiresAt = place.expiresAt;
  if (expiresAt == null) return null;
  final t = now ?? DateTime.now();
  final created = place.createdAt.toLocal();
  final local = t.toLocal();
  final sameDay = created.year == local.year &&
      created.month == local.month &&
      created.day == local.day;
  final time = (sameDay
          ? DateFormat.jm(kNumericLocale)
          : DateFormat('d MMM, h:mm a', kNumericLocale))
      .format(created);
  final minutesLeft = expiresAt.difference(t).inMinutes;
  final tail = place.isExpiredAt(t)
      ? l10n.placeReportExpired
      : l10n.placeExpiresInHours(
          minutesLeft <= 60 ? 1 : (minutesLeft / 60).ceil());
  return '${l10n.placeReportedAt(time)} · $tail';
}
