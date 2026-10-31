import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../data/year_video_encoder.dart';
import '../../domain/year_in_review.dart';
import '../../domain/year_video_plan.dart';
import 'year_review_card.dart';
import 'year_story_slides.dart';

enum _Phase { idle, making, done, failed }

/// The story's last page: turns the other pages into one 1080x1920 MP4 with
/// the music, for Reels, Shorts and Status, then shares or saves it.
///
/// Frames are drawn by the real page widgets into a boundary hidden under
/// this page, captured one at a time and handed to [encoder]. Each page's
/// entrance is filmed at 15 fps, then its finished frame is held.
class YearStoryVideoPage extends StatefulWidget {
  const YearStoryVideoPage({
    super.key,
    required this.review,
    required this.pages,
    required this.onBusy,
    this.bikeName,
    this.encoder = const YearVideoEncoder(),
  });

  final YearInReview review;
  final String? bikeName;

  /// The pages to film, in order (not including this one).
  final List<StorySlide> pages;

  /// True while the video is being made: the story must stay on this page.
  final ValueChanged<bool> onBusy;

  final YearVideoEncoder encoder;

  @override
  State<YearStoryVideoPage> createState() => _YearStoryVideoPageState();
}

class _YearStoryVideoPageState extends State<YearStoryVideoPage> {
  final _frameKey = GlobalKey();
  final _shareKey = GlobalKey();
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _file;
  bool _alive = true;

  // The frame being filmed.
  StorySlide? _filming;
  double _filmT = 1;

  static const _fps = 15;
  static const _entranceFrames = 24; // 1.6 s: the entrance has settled by then
  static const _pixelRatio = 3.0; // 360x640 canvas -> 1080x1920

  @override
  void dispose() {
    _alive = false;
    if (_phase == _Phase.making) {
      unawaited(widget.encoder.cancel().catchError((Object _) {}));
      widget.onBusy(false);
    }
    super.dispose();
  }

  Future<String> _assetFile(String asset, Directory dir) async {
    final file = File('${dir.path}/${asset.split('/').last}');
    final data = await rootBundle.load(asset);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  /// [t] values to film for [page] and how long each one shows.
  List<(double, int)> _frames(StorySlide page, int pageMs) {
    // The summary card has no entrance.
    if (page == StorySlide.summary) return [(1, pageMs)];
    final frames = <(double, int)>[];
    var used = 0;
    for (var k = 0; k < _entranceFrames; k++) {
      final end = ((k + 1) * 1000 / _fps).round();
      // Story time k/fps at 5 s a page: the screen's t is clock / 0.4.
      frames.add(((k / _fps) / 2, end - used));
      used = end;
    }
    frames.add((1, pageMs - used));
    return frames;
  }

  Future<void> _make() async {
    final year = widget.review.year;
    setState(() {
      _phase = _Phase.making;
      _progress = 0;
    });
    widget.onBusy(true);
    try {
      final plan = yearVideoPlan(widget.pages.length);
      final dir = await getTemporaryDirectory();
      final out = '${dir.path}/throttleiq_${year}_year.mp4';
      final audio = <Map<String, Object>>[
        for (final s in plan.audio)
          {
            'path': await _assetFile(s.asset, dir),
            'startMs': s.startMs,
            'durationMs': s.durationMs,
          },
      ];
      final schedule = [
        for (var i = 0; i < widget.pages.length; i++)
          for (final f in _frames(widget.pages[i], plan.pageMs[i]))
            (widget.pages[i], f.$1, f.$2),
      ];
      await widget.encoder.start(
        path: out,
        width: (YearCard.size.width * _pixelRatio).round(),
        height: (YearCard.size.height * _pixelRatio).round(),
        audio: audio,
      );
      for (var i = 0; i < schedule.length; i++) {
        if (!_alive) return; // dispose cancelled it
        final (page, t, ms) = schedule[i];
        setState(() {
          _filming = page;
          _filmT = t;
          _progress = i / schedule.length;
        });
        await WidgetsBinding.instance.endOfFrame;
        final boundary = _frameKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) throw StateError('frame not laid out');
        final image = await boundary.toImage(pixelRatio: _pixelRatio);
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        if (bytes == null) throw StateError('frame capture failed');
        if (!_alive) return;
        await widget.encoder
            .addFrame(bytes.buffer.asUint8List(), Duration(milliseconds: ms));
      }
      await widget.encoder.finish();
      if (!_alive) return;
      setState(() {
        _file = out;
        _phase = _Phase.done;
        _filming = null;
      });
      widget.onBusy(false);
      // The share sheet anchors on the Share button: let it lay out first.
      await WidgetsBinding.instance.endOfFrame;
      if (_alive) await _share();
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'year in review video');
      if (!_alive) return;
      unawaited(widget.encoder.cancel().catchError((Object _) {}));
      setState(() {
        _phase = _Phase.failed;
        _filming = null;
      });
      widget.onBusy(false);
    }
  }

  Future<void> _share() async {
    final file = _file;
    if (file == null) return;
    Rect? origin;
    final box =
        (_shareKey.currentContext ?? context).findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
    try {
      final result = await Share.shareXFiles(
        [XFile(file, mimeType: 'video/mp4')],
        sharePositionOrigin: origin,
      );
      if (result.status != ShareResultStatus.dismissed) {
        unawaited(AnalyticsService.instance.log(
            AnalyticsEvent.yearInReviewShared,
            param: AnalyticsParam.slide,
            value: StorySlide.video.name));
      }
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'year in review video share');
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    void snack(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        snack(l10n.myQrSaveNoAccess);
        return;
      }
      await Gal.putVideo(file);
      snack(l10n.yearStoryVideoSaved);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'year in review video save');
      snack(l10n.yearStoryVideoFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const lime = Color(0xFFC8FF3D);
    const fg = Color(0xFFF4F4F4);
    const muted = Color(0xFFB4B4B4);
    final seconds = (yearVideoPlan(widget.pages.length).totalMs / 1000).round();
    final filming = _filming;

    final ButtonStyle filled = FilledButton.styleFrom(
      backgroundColor: lime,
      foregroundColor: Colors.black,
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );

    final Widget actions = switch (_phase) {
      _Phase.making => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                color: lime,
                backgroundColor: fg.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 10),
            Text(l10n.yearStoryVideoMaking('${(_progress * 100).round()}'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
            const SizedBox(height: 2),
            Text(l10n.yearStoryVideoKeepOpen,
                style: const TextStyle(fontSize: 13, color: muted)),
          ],
        ),
      _Phase.done => Column(
          children: [
            FilledButton.icon(
              key: _shareKey,
              style: filled,
              onPressed: _share,
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.yearStoryVideoShare),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('year_video_save'),
              style: OutlinedButton.styleFrom(
                foregroundColor: fg,
                side: BorderSide(color: fg.withValues(alpha: 0.4)),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _save,
              icon: const Icon(Icons.download_rounded),
              label: Text(l10n.yearStoryVideoSave),
            ),
          ],
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_phase == _Phase.failed) ...[
              Text(l10n.yearStoryVideoFailed,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              key: const Key('year_video_create'),
              style: filled,
              onPressed: _make,
              icon: const Icon(Icons.movie_creation_outlined),
              label: Text(l10n.yearStoryVideoCreate),
            ),
          ],
        ),
    };

    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: YearCard.size,
        child: Stack(
          children: [
            // The camera: real pages, drawn under this one, never seen.
            if (filming != null)
              RepaintBoundary(
                key: _frameKey,
                child: YearStorySlide(
                  slide: filming,
                  review: widget.review,
                  bikeName: widget.bikeName,
                  t: _filmT,
                ),
              ),
            Positioned.fill(
              child: Container(
                key: const Key('year_story_video'),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF000000), Color(0xFF14180A)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.yearStoryVideoKicker.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 13,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                            color: fg)),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Center(
                          child: SizedBox.square(
                            dimension: 180,
                            child: CustomPaint(
                              painter: _ReelPainter(
                                  _phase == _Phase.done ? 1 : _progress,
                                  lime,
                                  fg.withValues(alpha: 0.12)),
                              child: Center(
                                child: Icon(
                                    _phase == _Phase.done
                                        ? Icons.check_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 84,
                                    color: lime),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(l10n.yearStoryVideoTitle,
                        style: display(context, 36,
                            height: 1.05, letterSpacing: -1, color: fg)),
                    const SizedBox(height: 10),
                    Text(l10n.yearStoryVideoBody('$seconds'),
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: muted)),
                    const SizedBox(height: 20),
                    actions,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A film reel ring: sprocket dots, filled clockwise with [progress].
class _ReelPainter extends CustomPainter {
  _ReelPainter(this.progress, this.color, this.track);
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, ring..color = track);
    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
          2 * math.pi * progress, false, ring..color = color);
    }
    final dot = Paint()..color = track;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * (r - 22), 4, dot);
    }
  }

  @override
  bool shouldRepaint(_ReelPainter old) => old.progress != progress;
}
