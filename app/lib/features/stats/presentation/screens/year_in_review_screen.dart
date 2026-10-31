import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../domain/year_in_review.dart';
import '../providers/rider_stats_provider.dart';
import '../widgets/year_review_card.dart';
import '../widgets/year_story_slides.dart';
import '../widgets/year_story_video_page.dart';

/// A rider's year as a story: full-screen pages that advance every few
/// seconds over a music loop, each one shareable as a 1080x1920 image.
/// Tap right/left to skip, hold to pause, swipe down to close.
class YearInReviewScreen extends ConsumerStatefulWidget {
  const YearInReviewScreen({super.key, this.initialYear, this.music = true});

  /// Year to open on, if the rider has rides in it; else the newest.
  final int? initialYear;

  /// False in widget tests, which have no audio plugin.
  final bool music;

  /// How long each page shows before the next.
  static const slideDuration = Duration(seconds: 5);

  @override
  ConsumerState<YearInReviewScreen> createState() => _YearInReviewScreenState();
}

class _YearInReviewScreenState extends ConsumerState<YearInReviewScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey _slideKey = GlobalKey();
  // Anchors the iOS/iPad share popover — see active_ride_screen.dart.
  final GlobalKey _shareButtonKey = GlobalKey();
  late final AnimationController _clock;
  late int? _year = widget.initialYear;
  int _index = 0;
  int _count = 0;
  bool _started = false;
  bool _holding = false;
  bool _sharing = false;
  bool _muted = false;
  bool _background = false;

  /// The video page is filming: the story stays put until it's done.
  bool _videoBusy = false;
  AudioPlayer? _player;

  /// With a screen reader on, pages wait for the rider instead of moving
  /// on by themselves.
  bool get _manual => MediaQuery.of(context).accessibleNavigation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(
        vsync: this, duration: YearInReviewScreen.slideDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_manual) _next();
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _startMusic() async {
    try {
      // Ambient: obeys the iPhone's silent switch and plays under the
      // rider's own music instead of stopping it.
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      final player = AudioPlayer();
      if (!mounted) return player.dispose();
      _player = player;
      await player.setAsset('assets/audio/year_in_review_loop.m4a');
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(0.7);
      _syncMusic();
    } catch (e, st) {
      reportSilently(e, st, where: 'yearInReview.music');
    }
  }

  /// Plays while the story is on screen and unmuted; never while held,
  /// sharing or in the background.
  void _syncMusic() {
    final p = _player;
    if (p == null) return;
    if (!_muted && !_background) {
      if (!p.playing) unawaited(p.play().catchError((Object _) {}));
    } else {
      unawaited(p.pause().catchError((Object _) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    _background ? _clock.stop() : _resume();
    _syncMusic();
  }

  void _resume() {
    if (!_started || _holding || _sharing || _background || _manual) return;
    if (_clock.value < 1) _clock.forward();
  }

  void _goTo(int i) {
    setState(() => _index = i.clamp(0, _count - 1));
    if (_manual) {
      _clock.stop();
    } else {
      _clock.value = 0;
      _resume();
    }
  }

  void _next() {
    if (_index < _count - 1) {
      _goTo(_index + 1);
    } else {
      _clock.value = 1; // rest on the last page
    }
  }

  void _previous() => _goTo(_index - 1);

  void _hold(bool on) {
    setState(() => _holding = on);
    on ? _clock.stop() : _resume();
  }

  Future<void> _share(int year, StorySlide slide) async {
    if (_sharing) return;
    final l10n = context.l10n;
    setState(() => _sharing = true); // draws the page finished
    _clock.stop();
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _slideKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('slide not laid out');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('PNG encode failed');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/throttleiq_${year}_${slide.name}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!mounted) return;

      Rect? origin;
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: l10n.yearInReviewHeading('$year'),
        sharePositionOrigin: origin,
      );
      if (result.status != ShareResultStatus.dismissed) {
        unawaited(AnalyticsService.instance.log(
            AnalyticsEvent.yearInReviewShared,
            param: AnalyticsParam.slide,
            value: slide.name));
      }
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'year in review share');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.yearInReviewShareFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
        _resume();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statsAsync = ref.watch(riderStatsProvider);
    final stats = statsAsync.valueOrNull;
    // An older cached summary has no allRides; same fallback as BadgeStats.
    final rides = stats == null
        ? const <RideEntity>[]
        : (stats.allRides.isNotEmpty ? stats.allRides : stats.recentRides);
    final years = rideYears(rides);

    if (stats == null || years.isEmpty) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(title: Text(l10n.yearInReviewTitle)),
        body: Center(
          child: stats == null && !statsAsync.hasError
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: stats == null
                      ? [
                          Text(l10n.yearInReviewLoadFailed),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => ref.invalidate(riderStatsProvider),
                            child: Text(l10n.tryAgain),
                          ),
                        ]
                      : [
                          Text(l10n.noRidesYetDot),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              // Pushed on the root navigator, above the tab
                              // shell, which `go` leaves in place: pop first.
                              final router = GoRouter.of(context);
                              Navigator.of(context).pop();
                              router.go('/home/record');
                            },
                            child: Text(l10n.startRide),
                          ),
                        ],
                ),
        ),
      );
    }

    final year = years.contains(_year) ? _year! : years.first;
    final review = computeYearInReview(rides, year);
    final bikes = ref.watch(allBikesProvider).valueOrNull ?? [];
    // A deleted bike has no name; leave it off a public image.
    final bikeName = bikes
        .where((b) => b.id == review.favouriteBikeId)
        .map((b) => b.displayName)
        .firstOrNull;
    final slides = storySlides(review, hasBikeName: bikeName != null);
    _count = slides.length;
    if (_index >= _count) _index = _count - 1;
    final slide = slides[_index];
    final last = _index == _count - 1;
    if (!_started) {
      _started = true;
      // Music only once there's a story: never over a spinner or an error.
      if (widget.music) unawaited(_startMusic());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goTo(_index);
      });
    }
    final still =
        _sharing || _manual || MediaQuery.of(context).disableAnimations;
    const fg = Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Chrome fades while held, so the page can be seen whole.
              AnimatedOpacity(
                opacity: _holding ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                  child: Column(
                    children: [
                      ExcludeSemantics(
                        child: AnimatedBuilder(
                          animation: _clock,
                          builder: (context, _) => Row(
                            children: [
                              for (var i = 0; i < _count; i++)
                                Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: fg.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: i < _index
                                          ? 1
                                          : i == _index
                                              ? (_manual ? 1 : _clock.value)
                                              : 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: fg,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l10n.yearInReviewTitle} · $year',
                              style: const TextStyle(
                                  color: fg, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (years.length > 1)
                            PopupMenuButton<int>(
                              key: const Key('year_in_review_year'),
                              enabled: !_videoBusy,
                              tooltip: l10n.yearStoryChooseYear,
                              icon: const Icon(Icons.calendar_month_outlined,
                                  color: fg),
                              initialValue: year,
                              onOpened: () => _hold(true),
                              onCanceled: () => _hold(false),
                              onSelected: (y) {
                                setState(() {
                                  _year = y;
                                  _holding = false;
                                });
                                _goTo(0);
                              },
                              itemBuilder: (_) => [
                                for (final y in years)
                                  PopupMenuItem(
                                    key: Key('year_in_review_year_$y'),
                                    value: y,
                                    child: Text('$y'),
                                  ),
                              ],
                            ),
                          if (widget.music)
                            IconButton(
                              tooltip: _muted
                                  ? l10n.yearStoryUnmute
                                  : l10n.yearStoryMute,
                              icon: Icon(
                                  _muted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: fg),
                              onPressed: () {
                                setState(() => _muted = !_muted);
                                _syncMusic();
                              },
                            ),
                          IconButton(
                            tooltip: l10n.close,
                            icon: const Icon(Icons.close_rounded, color: fg),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Back is the page's own left third (plus the margin
                    // beside it), however wide the screen is.
                    onTapUp: (d) {
                      if (_videoBusy) return;
                      final w = (box.maxWidth - 16).clamp(0.0,
                          (box.maxHeight - 16) * YearCard.size.aspectRatio);
                      d.localPosition.dx < (box.maxWidth - w) / 2 + w / 3
                          ? _previous()
                          : _next();
                    },
                    onLongPressStart: (_) => _videoBusy ? null : _hold(true),
                    onLongPressEnd: (_) => _videoBusy ? null : _hold(false),
                    onVerticalDragEnd: (d) {
                      if (!_videoBusy && (d.primaryVelocity ?? 0) > 400) {
                        Navigator.of(context).maybePop();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Center(
                        // Preview scaled to fit; the boundary is always
                        // 360x640, so the PNG is 1080x1920 (9:16).
                        child: AspectRatio(
                          aspectRatio: YearCard.size.aspectRatio,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(context.shape.radiusXl),
                            child: FittedBox(
                              child: RepaintBoundary(
                                key: _slideKey,
                                child: AnimatedBuilder(
                                  animation: _clock,
                                  builder: (context, _) => slide ==
                                          StorySlide.video
                                      ? YearStoryVideoPage(
                                          key: ValueKey('$year/video'),
                                          review: review,
                                          bikeName: bikeName,
                                          pages: slides
                                              .where(
                                                  (s) => s != StorySlide.video)
                                              .toList(),
                                          onBusy: (busy) {
                                            if (mounted) {
                                              setState(() => _videoBusy = busy);
                                            }
                                          },
                                        )
                                      : YearStorySlide(
                                          key: ValueKey('$year/${slide.name}'),
                                          slide: slide,
                                          review: review,
                                          bikeName: bikeName,
                                          // The entrance plays in the first 40%.
                                          t: still
                                              ? 1
                                              : (_clock.value / 0.4)
                                                  .clamp(0, 1),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _holding ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.yearStoryPrevious,
                        onPressed: _index == 0 || _videoBusy ? null : _previous,
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: fg,
                        disabledColor: fg.withValues(alpha: 0.3),
                      ),
                      if (last)
                        Flexible(
                            child: TextButton.icon(
                          key: const Key('year_story_replay'),
                          onPressed: _videoBusy ? null : () => _goTo(0),
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(l10n.yearStoryReplay),
                          style: TextButton.styleFrom(foregroundColor: fg),
                        ))
                      else
                        IconButton(
                          tooltip: l10n.yearStoryNext,
                          onPressed: _next,
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: fg,
                        ),
                      const SizedBox(width: 8),
                      // The video page has its own buttons.
                      if (slide != StorySlide.video)
                        Expanded(
                            child: Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            key: _shareButtonKey,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFC8FF3D),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: const Color(0xFFC8FF3D)
                                  .withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            onPressed:
                                _sharing ? null : () => _share(year, slide),
                            icon: _sharing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.ios_share),
                            label: Text(l10n.yearStoryShareSlide,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
