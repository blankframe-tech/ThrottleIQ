import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/badge_rarity.dart';
import 'package:throttleiq/core/utils/badges.dart';
import 'package:throttleiq/features/stats/presentation/providers/badge_rarity_provider.dart';
import 'package:throttleiq/features/stats/presentation/widgets/badge_detail_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Renders the sheet against fixed providers: no Firestore, no rides DB.
void main() {
  final distance = computeBadgeProgressFrom(
          const BadgeStats(totalRides: 3, totalDistanceKm: 420))
      .firstWhere((f) => f.family.id == 'distance');
  final earned = distance.badges.firstWhere((b) => b.def.id == 'km_100');
  final locked = distance.badges.firstWhere((b) => b.def.id == 'km_500');

  Future<void> pump(
    WidgetTester tester,
    EarnedBadge badge,
    BadgeOwnershipStats? stats,
  ) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        badgeOwnershipStatsProvider.overrideWith((ref) async => stats),
        badgeEarnedDatesProvider
            .overrideWithValue({'km_100': DateTime(2026, 10, 8)}),
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
    ));
    // Not pumpAndSettle: Epic/Legendary rings turn indefinitely by design.
    // Two seconds covers the provider future and the one-shot celebration.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('earned badge: date, rarity tier and percent, share',
      (tester) async {
    await pump(
      tester,
      earned,
      const BadgeOwnershipStats(totalRiders: 200, owners: {'km_100': 6}),
    );
    expect(find.text('Earned 8 Oct 2026'), findsOneWidget);
    expect(find.text('3% of riders own this badge'), findsOneWidget);
    expect(find.text('EPIC'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('locked badge: progress toward it, no share', (tester) async {
    await pump(tester, locked,
        const BadgeOwnershipStats(totalRiders: 200, owners: {'km_500': 90}));
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('420 / 500 km'), findsOneWidget);
    expect(find.text('80 km to go'), findsOneWidget);
    expect(find.text('45% of riders own this badge'), findsOneWidget);
    expect(find.text('COMMON'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('no stats: dash, never a number', (tester) async {
    await pump(tester, earned, null);
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('of riders own'), findsNothing);
  });
}
