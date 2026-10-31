import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/data/year_video_encoder.dart';
import 'package:throttleiq/features/stats/domain/year_in_review.dart';
import 'package:throttleiq/features/stats/domain/year_video_plan.dart';
import 'package:throttleiq/features/stats/presentation/widgets/year_story_video_page.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

import '../../key_screens.dart';

class _FakeEncoder implements YearVideoEncoder {
  Map<String, Object>? started;
  final frames = <(int, Duration)>[];
  bool finished = false;
  bool cancelled = false;
  bool failOnFrame = false;

  @override
  Future<void> start(
      {required String path,
      required int width,
      required int height,
      required List<Map<String, Object>> audio}) async {
    started = {'path': path, 'width': width, 'height': height, 'audio': audio};
  }

  @override
  Future<void> addFrame(Uint8List rgba, Duration duration) async {
    if (failOnFrame) {
      throw PlatformException(code: 'video', message: 'encoder gone');
    }
    frames.add((rgba.length, duration));
  }

  @override
  Future<void> finish() async => finished = true;

  @override
  Future<void> cancel() async => cancelled = true;
}

void main() {
  late Directory tmp;
  setUpAll(() async {
    await loadKeyScreenFonts();
    tmp = Directory.systemTemp.createTempSync('year_video_test');
    // After loadKeyScreenFonts, which points path_provider at test/fonts.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => tmp.path);
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  final review = computeYearInReview([
    RideEntity(
        id: 'a',
        userId: 'u',
        bikeId: 'b1',
        startTime: DateTime(2026, 3, 1),
        distanceM: 42000),
  ], 2026, now: DateTime(2027));
  const pages = [StorySlide.cover, StorySlide.distance, StorySlide.summary];

  Future<void> pumpPage(WidgetTester tester, _FakeEncoder encoder,
      {List<bool>? busy}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        // As in the story: scaled to fit, laid out at its full 360x640.
        body: FittedBox(
          child: YearStoryVideoPage(
            review: review,
            pages: pages,
            encoder: encoder,
            onBusy: (b) => busy?.add(b),
          ),
        ),
      ),
    ));
  }

  /// Image capture and file writes finish outside fake time.
  Future<void> runUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 20000 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  testWidgets('films every page at 1080x1920 over the planned timeline',
      (tester) async {
    final encoder = _FakeEncoder();
    final busy = <bool>[];
    await pumpPage(tester, encoder, busy: busy);
    final plan = yearVideoPlan(pages.length);
    expect(
        find.text('${plan.totalMs ~/ 1000} seconds with music, '
            'sized for Reels, Shorts and Status.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('year_video_create')));
    await runUntil(tester, () => encoder.finished);

    expect(encoder.started!['width'], 1080);
    expect(encoder.started!['height'], 1920);
    final audio = encoder.started!['audio']! as List<Map<String, Object>>;
    expect(audio.length, plan.audio.length);
    expect(File(audio.first['path']! as String).existsSync(), isTrue);
    // Two animated pages (25 frames each) and the still summary card.
    expect(encoder.frames.length, 51);
    expect(encoder.frames.map((f) => f.$1).toSet(), {1080 * 1920 * 4});
    final total =
        encoder.frames.fold<int>(0, (a, f) => a + f.$2.inMilliseconds);
    expect(total, plan.totalMs);
    expect(busy, [true, false]);
    await tester.pump();
    expect(find.text('Share video'), findsOneWidget);
    expect(find.text('Save to Photos'), findsOneWidget);
  });

  testWidgets('an encoder failure says so and offers another go',
      (tester) async {
    final encoder = _FakeEncoder()..failOnFrame = true;
    final busy = <bool>[];
    await pumpPage(tester, encoder, busy: busy);
    await tester.tap(find.byKey(const Key('year_video_create')));
    await runUntil(tester, () => busy.length == 2);
    await tester.pump();
    expect(find.text("Couldn't make the video. Try again."), findsOneWidget);
    expect(find.byKey(const Key('year_video_create')), findsOneWidget);
    expect(encoder.cancelled, isTrue);
  });
}
