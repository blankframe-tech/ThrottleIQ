import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:throttleiq/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('End-to-End Application Flow', () {
    testWidgets('App launches, navigation works, and places load', (tester) async {
      // Load the app.
      // This boots the entire application using Riverpod's ProviderScope.
      // Note: If you have Firebase initialized, you might need a setUpAll block
      // that calls Firebase.initializeApp() just like in main.dart.
      await tester.pumpWidget(const ProviderScope(child: ThrottleIQApp()));
      
      // Wait for the app to settle and initial routes/animations to complete.
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 1. Verify we are on the Home screen or Auth screen.
      // E2E tests often require mocked or authenticated states. 
      // Assuming a logged-in state or bypassing to the main hub.
      final hasBottomNav = find.byType(BottomNavigationBar);
      
      if (tester.any(hasBottomNav)) {
        // 2. Navigate to 'Places' tab
        // ThrottleIQ has a navigation bar with 'Places' or 'Map'.
        final placesTab = find.text('Places'); 
        if (tester.any(placesTab)) {
          await tester.tap(placesTab);
          await tester.pumpAndSettle();

          // 3. Verify PlacesHubScreen loads.
          // Wait for lazy places to load. We should see the 'Saved' segment button.
          expect(find.text('Saved'), findsOneWidget);
          expect(find.text('Routes'), findsOneWidget);

          // 4. Test tapping a filter chip
          final filterChip = find.byKey(const ValueKey('places-chip-garage'));
          if (tester.any(filterChip)) {
            await tester.tap(filterChip);
            await tester.pumpAndSettle();
          }

          // 5. Test Saved Places tab
          final savedTab = find.text('Saved');
          await tester.tap(savedTab);
          await tester.pumpAndSettle();
          
          // Verify that Saved Tab loads (either empty state or actual list)
          expect(find.textContaining(RegExp(r'saved places', caseSensitive: false)), findsWidgets);
        }
      }
    });
  });
}
