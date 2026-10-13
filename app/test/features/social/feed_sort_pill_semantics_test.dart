import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/presentation/screens/social_screen.dart';

/// issues §101.A4: the Following/Discover pills had no selected semantics.
void main() {
  testWidgets('feed sort pills announce role and the active sort',
      (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          FeedSortPill(label: 'Following', selected: true, onTap: () {}),
          FeedSortPill(label: 'Discover', selected: false, onTap: () => tapped++),
        ]),
      ),
    ));

    expect(
      tester.getSemantics(find.text('Following')),
      matchesSemantics(
        label: 'Following',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(tester.getSemantics(find.text('Discover')),
        isSemantics(isButton: true, isSelected: false));

    await tester.tap(find.text('Discover'));
    expect(tapped, 1);
    handle.dispose();
  });
}
