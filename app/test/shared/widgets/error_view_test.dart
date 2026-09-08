import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/shared/widgets/error_view.dart';

void main() {
  group('ErrorView', () {
    testWidgets('renders friendly mapped message for network error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              error: Exception('Failed host lookup: firestore.googleapis.com'),
            ),
          ),
        ),
      );

      expect(find.text("You're offline. Check your internet connection and try again."), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Report a Problem'), findsNothing);
    });

    testWidgets('renders retry button when callback provided', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              error: Exception('Some error'),
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });

    testWidgets('renders Report a Problem button when showBugReport is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              error: Exception('Some error'),
              showBugReport: true,
            ),
          ),
        ),
      );

      expect(find.text('Report a Problem'), findsOneWidget);
      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    });
  });
}
