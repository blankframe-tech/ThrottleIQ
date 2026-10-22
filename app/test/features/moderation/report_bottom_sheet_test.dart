import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/moderation/data/repositories/report_repository.dart';
import 'package:throttleiq/features/moderation/presentation/widgets/report_bottom_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _MockUser extends Mock implements User {
  @override
  String get uid => 'reporter-1';
}

class _FakeReportRepository implements ReportRepository {
  final calls = <Map<String, String?>>[];
  bool fail = false;

  @override
  Future<void> submitReport({
    required String reporterId,
    required String reportedId,
    required String contentType,
    required String contentId,
    required String reason,
    String? additionalDetails,
  }) async {
    if (fail) throw Exception('permission-denied');
    calls.add({
      'reporterId': reporterId,
      'reportedId': reportedId,
      'contentType': contentType,
      'contentId': contentId,
      'reason': reason,
      'additionalDetails': additionalDetails,
    });
  }
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(_MockUser())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ReportBottomSheet.show(
                context,
                reportedId: 'bad-rider',
                contentType: 'chat',
                contentId: 'chats/a_b/messages/m1',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.widgetWithText(ElevatedButton, 'Submit Report');
  await tester.pump(); // rebuild after the reason pick enables the button
  await tester.ensureVisible(submit);
  await tester.tap(submit);
}

void main() {
  late _FakeReportRepository repo;

  setUp(() {
    repo = _FakeReportRepository();
    ReportRepository.instanceForTest = repo;
  });

  testWidgets('submit stays disabled until a reason is picked', (tester) async {
    await _openSheet(tester);

    expect(find.text('Community rules'), findsOneWidget);
    expect(find.textContaining('within 24 hours'), findsOneWidget);
    final submit = find.widgetWithText(ElevatedButton, 'Submit Report');
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);

    await tester.tap(find.text('Harassment or bullying'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNotNull);
  });

  testWidgets('sends the English reason, trimmed details and the target', (
    tester,
  ) async {
    await _openSheet(tester);

    await tester.tap(find.text('Harassment or bullying'));
    await tester.enterText(find.byType(TextField), '  kept messaging  ');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.calls, [
      {
        'reporterId': 'reporter-1',
        'reportedId': 'bad-rider',
        'contentType': 'chat',
        'contentId': 'chats/a_b/messages/m1',
        'reason': 'Harassment or bullying',
        'additionalDetails': 'kept messaging',
      },
    ]);
    expect(find.byType(ReportBottomSheet), findsNothing);
  });

  testWidgets('a failed write keeps the sheet open and says so', (
    tester,
  ) async {
    repo.fail = true;
    await _openSheet(tester);

    await tester.tap(find.text('Spam or misleading'));
    await _tapSubmit(tester);
    await tester.pump(); // not pumpAndSettle: that runs the snackbar out

    expect(find.byType(ReportBottomSheet), findsOneWidget);
    expect(
      find.text('Could not send the report. Please try again.'),
      findsOneWidget,
    );
  });
}
