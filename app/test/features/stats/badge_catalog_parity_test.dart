import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/badges.dart';
import 'package:throttleiq/features/stats/data/badge_stats_counter.dart';

/// badges.dart is the source of truth for the milestone badge ids. Two other
/// places keep a copy:
///  - firestore.rules `milestoneBadgeIds()`: the only ids a client may count
///    into stats/badges. A rung missing there could never get a rarity
///    figure.
///  - functions/src/badge-catalog.ts: the Blaze-plan Cloud Functions
///    alternative (not deployed on Spark), kept in step so it can be
///    switched on without surprises.
void main() {
  final appIds = {for (final def in badgeDefs) def.id};

  test('the client allow-list is exactly the badge catalog', () {
    expect(countedBadgeIds, appIds);
    expect(appIds.length, badgeDefs.length, reason: 'duplicate badge id');
  });

  test('firestore.rules milestoneBadgeIds() matches badges.dart', () {
    final file = File('../firestore.rules');
    if (!file.existsSync()) {
      markTestSkipped('firestore.rules not checked out next to app/');
      return;
    }
    final source = file.readAsStringSync();
    final body = RegExp(
      r'function milestoneBadgeIds\(\)\s*\{\s*return\s*\[([^\]]*)\]',
    ).firstMatch(source);
    expect(body, isNotNull, reason: 'milestoneBadgeIds() not found');
    final ruleIds = RegExp(
      r"'([a-z0-9_]+)'",
    ).allMatches(body![1]!).map((m) => m[1]!);
    expect(
      ruleIds.length,
      ruleIds.toSet().length,
      reason: 'duplicate id in milestoneBadgeIds()',
    );
    expect(
      ruleIds.toSet(),
      appIds,
      reason: 'Update milestoneBadgeIds() in firestore.rules',
    );
  });

  test('every badge id is in the Cloud Functions catalog', () {
    final file = File('../functions/src/badge-catalog.ts');
    if (!file.existsSync()) {
      markTestSkipped('functions/ not checked out next to app/');
      return;
    }
    final source = file.readAsStringSync();
    final ids = RegExp(r"'([a-z0-9_]+)',").allMatches(source).map((m) => m[1]);
    final serverIds = ids.toSet();
    final missing = [
      for (final def in badgeDefs)
        if (!serverIds.contains(def.id)) def.id,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'Add these to MILESTONE_BADGE_IDS in badge-catalog.ts',
    );
    expect(
      serverIds.length,
      badgeDefs.length,
      reason: 'badge-catalog.ts lists ids that badges.dart does not',
    );
  });
}
