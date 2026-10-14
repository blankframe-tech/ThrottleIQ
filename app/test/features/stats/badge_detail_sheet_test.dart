import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/badges.dart';
import 'package:throttleiq/features/stats/presentation/providers/badge_earned_dates_provider.dart';
import 'package:throttleiq/features/stats/presentation/widgets/badge_detail_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Renders the sheet against fixed providers: no Firestore, no rides DB.
void main() {
  final distance = computeBadgeProgressFrom(
    const BadgeStats(totalRides: 3, totalDistanceKm: 420),
  ).firstWhere((f) => f.family.id == 'distance');
  final earned = distance.badges.firstWhere((b) => b.def.id == 'km_100');
  final locked = distance.badges.firstWhere((b) => b.def.id == 'km_500');

  Future<void> pump(WidgetTester tester, EarnedBadge badge) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          badgeEarnedDatesProvider.overrideWithValue({
            'km_100': DateTime(2026, 10, 8),
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BadgeDetailSheet(progress: distance, badge: badge),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('earned badge: date and share, no rarity figure', (
    tester,
  ) async {
    await pump(tester, earned);
    expect(find.text('Earned 8 Oct 2026'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    // Cut on 2026-10-14 (CrtiQue_Oct14 B7): self-awarded badges make it
    // meaningless.
    expect(find.textContaining('of riders own'), findsNothing);
    expect(find.text('Rarity'), findsNothing);
  });

  testWidgets('locked badge: progress toward it, no share', (tester) async {
    await pump(tester, locked);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('420 / 500 km'), findsOneWidget);
    expect(find.text('80 km to go'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
  });
}
