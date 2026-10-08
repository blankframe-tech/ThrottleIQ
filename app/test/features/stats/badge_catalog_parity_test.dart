import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/badges.dart';

/// functions/src/badge-catalog.ts keeps its own copy of the milestone badge
/// ids (the server only counts ids it knows). A rung added here without a
/// matching entry there would never get a rarity figure — this catches it.
void main() {
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
    expect(missing, isEmpty,
        reason: 'Add these to MILESTONE_BADGE_IDS in badge-catalog.ts');
    expect(serverIds.length, badgeDefs.length,
        reason: 'badge-catalog.ts lists ids that badges.dart does not');
  });
}
