/// Timing of the Year in Review video: how long each page shows and which
/// pieces of music play under it.
///
/// The music is the story's 8-bar loop, cut on a bar line, then the outro
/// (one ringing downbeat). Cutting anywhere else would end mid-beat, so the
/// last page stretches to wherever the music ends: 6.2-8.6 s instead of 5.
library;

/// Assets and their musical lengths (see scripts/year_in_review_music.py).
const yearVideoLoopAsset = 'assets/audio/year_in_review_loop.m4a';
const yearVideoOutroAsset = 'assets/audio/year_in_review_outro.m4a';
const _loopMs = 19200; // 8 bars at 100 BPM
const _barMs = 2400;
const _outroMs = 3600;
const _pageMs = 5000;

/// A piece of an audio asset, placed right after the previous one.
class AudioSegment {
  const AudioSegment(this.asset, this.startMs, this.durationMs);
  final String asset;
  final int startMs;
  final int durationMs;

  @override
  bool operator ==(Object other) =>
      other is AudioSegment &&
      other.asset == asset &&
      other.startMs == startMs &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(asset, startMs, durationMs);

  @override
  String toString() => 'AudioSegment($asset, $startMs, $durationMs)';
}

class YearVideoPlan {
  const YearVideoPlan(this.pageMs, this.audio);

  /// Milliseconds on screen per page, in order.
  final List<int> pageMs;
  final List<AudioSegment> audio;

  int get totalMs => pageMs.fold(0, (a, b) => a + b);
}

/// The plan for a video of [pages] pages (at least one).
YearVideoPlan yearVideoPlan(int pages) {
  assert(pages > 0);
  final base = pages * _pageMs;
  // The loop runs to the first bar line at most one bar before the pages
  // would end, so the outro lands on the last page.
  final loopMs = ((base - _barMs) / _barMs).ceil().clamp(0, 1 << 20) * _barMs;
  final total = loopMs + _outroMs;
  return YearVideoPlan(
    [
      for (var i = 0; i < pages - 1; i++) _pageMs,
      total - (pages - 1) * _pageMs
    ],
    [
      for (var at = 0; at < loopMs; at += _loopMs)
        AudioSegment(yearVideoLoopAsset, 0,
            loopMs - at < _loopMs ? loopMs - at : _loopMs),
      const AudioSegment(yearVideoOutroAsset, 0, _outroMs),
    ],
  );
}
