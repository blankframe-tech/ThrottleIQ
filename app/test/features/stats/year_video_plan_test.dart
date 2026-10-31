import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/stats/domain/year_video_plan.dart';

void main() {
  test('pages last 5 s; the last stretches to the music ending on a bar', () {
    for (var n = 1; n <= 14; n++) {
      final p = yearVideoPlan(n);
      expect(p.pageMs.length, n);
      expect(p.pageMs.take(n - 1), everyElement(5000));
      expect(p.pageMs.last, inInclusiveRange(6200, 8600), reason: '$n pages');
      final music = p.audio.fold<int>(0, (a, s) => a + s.durationMs);
      expect(music, p.totalMs, reason: 'music covers the video exactly');
      final loop = music - 3600;
      expect(loop % 2400, 0, reason: 'cut on a bar line');
      expect(p.audio.last, const AudioSegment(yearVideoOutroAsset, 0, 3600));
    }
  });

  test('a long video loops the music whole, then cuts the last loop', () {
    final p = yearVideoPlan(13); // 65 s of pages
    expect(p.audio, const [
      AudioSegment(yearVideoLoopAsset, 0, 19200),
      AudioSegment(yearVideoLoopAsset, 0, 19200),
      AudioSegment(yearVideoLoopAsset, 0, 19200),
      AudioSegment(yearVideoLoopAsset, 0, 7200),
      AudioSegment(yearVideoOutroAsset, 0, 3600),
    ]);
    expect(p.totalMs, 68400);
  });
}
