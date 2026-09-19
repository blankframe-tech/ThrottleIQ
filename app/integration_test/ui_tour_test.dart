// Automated UI screenshot tour.
//
// Walks the whole app — auth, onboarding tour, every tab, detail screens,
// sheets and dialogs — once per appearance combination (7 color modes x
// Curvy/Boxy x Light/Dark = 28), asking the host to screenshot each step.
//
// The screenshots themselves are taken on the HOST with
// `xcrun simctl io <udid> screenshot`, not with integration_test's
// takeScreenshot (which buffers every PNG in memory until the test ends —
// unworkable for ~2000 shots). Handshake, through the app's Documents dir
// (which on the simulator is a plain host directory):
//   test  -> writes  tour/req_<seq>.txt   (contents: relative output path)
//   host  -> writes  tour/ack_<seq>       once the PNG is on disk
//
// Run with app/scripts/ui_tour/run_tour.sh, which starts the host watcher
// and `flutter test`. `--dart-define=TOUR_COMBOS=a,b` limits
// the run to some combos (ids like `calming_curvy_light`).
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:throttleiq/app.dart';
import 'package:throttleiq/core/router/app_router.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/features/chat/presentation/providers/chat_providers.dart';
import 'package:throttleiq/features/forums/presentation/providers/forum_providers.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/poi_directory/presentation/providers/places_provider.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/routes/presentation/providers/route_providers.dart';
import 'package:throttleiq/features/social/presentation/providers/ride_feed_provider.dart';
import 'package:throttleiq/firebase_options.dart';

const _email = 'rider@example.com';
const _password = 'Test@123';
const _onlyCombos = String.fromEnvironment('TOUR_COMBOS');
const _dumpTexts = bool.fromEnvironment('TOUR_DUMP_TEXTS');

/// Development aid: skip the first N tour parts (0 = auth ... 6 = profile).
const _fromPart = int.fromEnvironment('TOUR_FROM');

late WidgetTester t;
late ProviderContainer c;
late Directory tourDir;
IOSink? textLog;
int seq = 0;
String comboDir = '';
int shot = 0;
String section = '';

GoRouter get router => c.read(routerProvider);
String get location => router.routerDelegate.currentConfiguration.uri.toString();

void log(String m) => debugPrint('[tour] $m');

/// Lets real time pass while frames keep rendering (network images, maps,
/// Firestore streams, entrance animations).
Future<void> wait([int ms = 900]) async {
  await t.pump();
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await t.pump();
  }
}

String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

/// Asks the host for a screenshot and blocks until it has been written.
Future<void> snap(String name, {int settleMs = 1100}) async {
  await wait(settleMs);
  await settleLoading();
  shot++;
  seq++;
  final rel = '$comboDir/${shot.toString().padLeft(3, '0')}__${_slug(section)}__${_slug(name)}.png';
  final ack = File('${tourDir.path}/ack_$seq');
  await File('${tourDir.path}/req_$seq.tmp').writeAsString(rel);
  await File('${tourDir.path}/req_$seq.tmp').rename('${tourDir.path}/req_$seq.txt');
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ack.existsSync()) {
    if (DateTime.now().isAfter(deadline)) {
      log('!! no ack for $rel');
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }
  log('snap $rel ($location)');
  if (_dumpTexts) _dump(rel);
}

void _dump(String rel) {
  final texts = <String>[];
  for (final e in ev(find.byType(Text))) {
    final w = e.widget as Text;
    final s = w.data ?? w.textSpan?.toPlainText();
    if (s != null && s.trim().isNotEmpty) texts.add(s.replaceAll('\n', ' '));
  }
  final icons = ev(find.byType(Icon)).map((e) => (e.widget as Icon).icon?.codePoint.toRadixString(16)).toList();
  textLog?.writeln('=== $rel  @ $location\n  ${texts.join(' | ')}\n  icons: ${icons.length}');
}

Finder _hittable(Finder f) => f.hitTestable();

/// Finder evaluation that tolerates the element tree being mid-rebuild
/// (viewport children without a laid-out render object throw during the walk).
List<Element> ev(Finder f) {
  for (var i = 0; i < 3; i++) {
    try {
      return f.evaluate().toList();
    } catch (_) {}
  }
  return const [];
}

bool has(Finder f) => ev(f).isNotEmpty;

/// Waits (up to [maxMs]) for loading spinners to disappear.
Future<void> settleLoading({int maxMs = 9000}) async {
  final end = DateTime.now().add(Duration(milliseconds: maxMs));
  while (DateTime.now().isBefore(end)) {
    final spinners = ev(find.byType(CircularProgressIndicator).hitTestable()).length +
        ev(find.byType(LinearProgressIndicator).hitTestable())
            .where((e) => (e.widget as LinearProgressIndicator).value == null)
            .length;
    if (spinners == 0) return;
    await wait(250);
  }
}

/// Taps the first on-screen widget showing exactly [text]. Returns false
/// (and logs) instead of failing when it is not there — a missing optional
/// control must never abort a 28-combo run.
Future<bool> tapText(String text, {bool contains = false, int index = 0, int after = 900}) async {
  final f = _hittable(contains ? find.textContaining(text) : find.text(text));
  final n = ev(f).length;
  if (n <= index) {
    log('?? text not found: "$text"');
    return false;
  }
  await t.tap(f.at(index), warnIfMissed: false);
  await wait(after);
  return true;
}

/// Scrolls [text] into view first (lazy lists only build what is on
/// screen, so it may not exist until scrolled to), then taps it.
Future<bool> tapTextVisible(String text, {int after = 900}) async {
  final f = find.text(text);
  for (var i = 0; i < 12 && !has(f); i++) {
    final s = _mainScrollable();
    if (s == null || s.position.pixels >= s.position.maxScrollExtent - 4) break;
    s.position.jumpTo((s.position.pixels + s.position.viewportDimension * 0.6).clamp(0.0, s.position.maxScrollExtent));
    await wait(300);
  }
  if (!has(f)) {
    log('?? text not found: "$text"');
    return false;
  }
  await safe('ensureVisible', () => t.ensureVisible(f.first));
  await wait(500);
  return tapText(text, after: after);
}

/// Snapshots a bottom sheet / dialog opened by [open], then closes it.
Future<void> snapOverlay(String name, Future<bool> Function() open, {int settleMs = 1100}) async {
  if (!await open()) return;
  if (has(find.byType(BottomSheet)) || has(find.byType(Dialog)) || has(find.byType(AlertDialog))) {
    await snap(name, settleMs: settleMs);
    await back();
  }
}

Future<bool> tapIcon(IconData icon, {int index = 0, int after = 900}) async {
  final f = _hittable(find.byIcon(icon));
  if (ev(f).length <= index) {
    log('?? icon not found: ${icon.codePoint.toRadixString(16)}');
    return false;
  }
  await t.tap(f.at(index), warnIfMissed: false);
  await wait(after);
  return true;
}

Future<bool> tapTooltip(String tip, {int after = 900}) async {
  final f = _hittable(find.byTooltip(tip));
  if (!has(f)) {
    log('?? tooltip not found: $tip');
    return false;
  }
  await t.tap(f.first, warnIfMissed: false);
  await wait(after);
  return true;
}

/// Pops whatever sheet/dialog/page is on top of the nearest navigator.
Future<void> back({int after = 700}) async {
  for (final type in [BottomSheet, Dialog, AlertDialog]) {
    final f = find.byType(type);
    final els = ev(f);
    if (els.isNotEmpty) {
      Navigator.of(els.last).pop();
      await wait(after);
      return;
    }
  }
  if (router.canPop()) {
    router.pop();
  } else {
    log('?? nothing to pop at $location');
  }
  await wait(after);
}

Future<void> go(String path, {int after = 1400}) async {
  router.go(path);
  await wait(after);
}

Future<void> push(String path, {Object? extra, int after = 1400}) async {
  unawaited(router.push(path, extra: extra));
  await wait(after);
}

/// The tallest vertical scrollable on screen — the page body, not a chip row.
ScrollableState? _mainScrollable() {
  ScrollableState? best;
  double bestExtent = -1;
  for (final e in ev(find.byType(Scrollable).hitTestable())) {
    final s = (e as StatefulElement).state as ScrollableState;
    if (s.axisDirection != AxisDirection.down) continue;
    if (!s.position.hasContentDimensions) continue;
    final box = e.renderObject as RenderBox?;
    final h = box?.size.height ?? 0;
    if (s.position.maxScrollExtent <= 0) continue;
    if (h > bestExtent) {
      bestExtent = h;
      best = s;
    }
  }
  return best;
}

/// Snapshots the screen, then keeps scrolling the page body and snapshotting
/// until the bottom (at most [maxPages] shots in total).
Future<void> snapScroll(String name, {int maxPages = 4}) async {
  await snap(name);
  for (var i = 2; i <= maxPages; i++) {
    final s = _mainScrollable();
    if (s == null) return;
    final p = s.position;
    if (p.pixels >= p.maxScrollExtent - 4) return;
    final target = (p.pixels + p.viewportDimension * 0.8).clamp(0.0, p.maxScrollExtent);
    await p.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    await snap('$name (cont. $i)', settleMs: 700);
  }
}

Future<T?> safe<T>(String what, Future<T> Function() body) async {
  try {
    return await body();
  } catch (e) {
    log('!! $what failed: $e');
    return null;
  }
}

/// Runs one step of the tour; a failure is logged and the tour moves on to
/// the next step from a known location.
Future<void> step(String name, Future<void> Function() body) async {
  section = name;
  try {
    await body();
  } catch (e, st) {
    log('!! step "$name" failed: $e\n$st');
    // Close anything left open.
    for (var i = 0; i < 3; i++) {
      if (!has(find.byType(BottomSheet)) && !has(find.byType(Dialog)) && !has(find.byType(AlertDialog))) {
        break;
      }
      await back();
    }
  }
}

class Combo {
  final AppColorMode color;
  final AppShapeVibe vibe;
  final Brightness brightness;
  const Combo(this.color, this.vibe, this.brightness);
  String get id => '${color.name}_${vibe.name}_${brightness.name}';
}

List<Combo> allCombos() => [
      for (final color in AppColorMode.values)
        for (final vibe in [AppShapeVibe.curvy, AppShapeVibe.boxy])
          for (final b in [Brightness.light, Brightness.dark]) Combo(color, vibe, b),
    ];

Future<void> applyCombo(Combo combo) async {
  final n = c.read(appearanceProvider.notifier);
  await n.setColorMode(combo.color);
  await n.setShapeVibe(combo.vibe);
  await n.setBrightness(combo.brightness);
  await wait(800);
}

// ───────────────────────────── Data lookups ─────────────────────────────

class TourData {
  String uid = '';
  String? bikeId;
  String? rideId;
  String? sharedRideId;
  Object? sharedRideExtra;
  String? otherUid;
  String? forumId;
  String? forumPostId;
  String? routeId;
  String? routeOwner;
  String? placeId;
  String? myPlaceId;
  String? chatId;
}

final data = TourData();

Future<void> loadData() async {
  data.uid = FirebaseAuth.instance.currentUser!.uid;
  final bikes = await safe('bikes', () => c.read(garageProvider.future).timeout(const Duration(seconds: 20)));
  if (bikes != null && bikes.isNotEmpty) {
    data.bikeId = bikes.first.id;
    for (final b in bikes) {
      final rides = await safe('rides', () => c.read(rideHistoryProvider(b.id).future));
      if (rides != null && rides.isNotEmpty) {
        data.bikeId = b.id;
        data.rideId = rides.first.id;
        break;
      }
    }
  }
  final feed = await safe('feed', () => c.read(rideFeedProvider.future).timeout(const Duration(seconds: 20)));
  if (feed != null && feed.isNotEmpty) {
    final other = feed.firstWhere((r) => r.userId != data.uid, orElse: () => feed.first);
    data.sharedRideId = other.id;
    data.sharedRideExtra = other;
    if (other.userId != data.uid) data.otherUid = other.userId;
  }
  final forums = await safe('forums', () => c.read(customForumsProvider.future).timeout(const Duration(seconds: 20)));
  if (forums != null) {
    for (final f in forums) {
      final posts = await safe('posts', () => c.read(forumPostsProvider(f.id).future));
      if (posts != null && posts.isNotEmpty) {
        data.forumId = f.id;
        data.forumPostId = posts.first.id;
        data.otherUid ??= posts.first.userId == data.uid ? null : posts.first.userId;
        break;
      }
      data.forumId ??= f.id;
    }
  }
  final mine = await safe('routes', () => c.read(myRoutesProvider.future).timeout(const Duration(seconds: 20)));
  if (mine != null && mine.isNotEmpty) {
    data.routeId = mine.first.id;
  } else {
    final pub =
        await safe('publicRoutes', () => c.read(publicRoutesProvider.future).timeout(const Duration(seconds: 20)));
    if (pub != null && pub.isNotEmpty) {
      data.routeId = pub.first.id;
      data.routeOwner = pub.first.userId;
    }
  }
  final places =
      await safe('places', () => c.read(nearbyPlacesProvider(null).future).timeout(const Duration(seconds: 25)));
  if (places != null && places.isNotEmpty) data.placeId = places.first.id;
  final myPlaces = await safe('myPlaces', () => c.read(myPlacesProvider.future).timeout(const Duration(seconds: 20)));
  if (myPlaces != null && myPlaces.isNotEmpty) data.myPlaceId = myPlaces.first.id;
  final chats = await safe('chats',
      () => c.read(chatRepositoryProvider).watchUserChats(data.uid).first.timeout(const Duration(seconds: 20)));
  if (chats != null && chats.isNotEmpty) data.chatId = chats.first.id;
  log('data: uid=${data.uid} bike=${data.bikeId} ride=${data.rideId} shared=${data.sharedRideId} other=${data.otherUid} '
      'forum=${data.forumId}/${data.forumPostId} route=${data.routeId} place=${data.placeId} myPlace=${data.myPlaceId} chat=${data.chatId}');
}

// ───────────────────────────── The tour ─────────────────────────────

Future<void> signOutIfNeeded() async {
  if (FirebaseAuth.instance.currentUser != null) {
    await FirebaseAuth.instance.signOut();
    await wait(1500);
  }
  if (!location.startsWith('/auth/login')) await go('/auth/login');
}

Future<void> tourAuth() async {
  await step('Welcome', () async {
    await signOutIfNeeded();
    await snap('Sign in');
    await go('/auth/register');
    await snap('Create account');
    final fields = find.byType(TextFormField);
    if (ev(fields).length >= 3) {
      await t.enterText(fields.at(0), 'Rafi Ahmed');
      await t.enterText(fields.at(1), 'rafi@example.com');
      await t.enterText(fields.at(2), 'Test@123');
      FocusManager.instance.primaryFocus?.unfocus();
      await snap('Create account - filled');
    }
    await go('/auth/login');
    final login = find.byType(TextFormField);
    await t.enterText(login.at(0), _email);
    await t.enterText(login.at(1), _password);
    FocusManager.instance.primaryFocus?.unfocus();
    await snap('Sign in - filled');
    await tapText('Sign In', after: 300);
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!location.startsWith('/home') && DateTime.now().isBefore(deadline)) {
      await wait(300);
    }
    if (!location.startsWith('/home')) throw StateError('login did not land on /home ($location)');
  });
}

Future<void> tourOnboarding() async {
  await step('Feature tour', () async {
    for (var i = 0; i < 7; i++) {
      await push('/auth/onboarding?demo=1&slide=$i', after: 1600);
      await snap('Slide ${i + 1}');
      await back();
    }
  });
}

Future<void> tourRecord() async {
  await step('Record', () async {
    await go('/home/record', after: 1800);
    await snapScroll('Record dashboard', maxPages: 3);
    final s = _mainScrollable();
    if (s != null) s.position.jumpTo(0);
    await wait(300);
  });
  await step('Record', () async {
    // Bike picker sheet (tap the active-bike card's switch affordance).
    if (await tapIcon(Icons.swap_horiz) || await tapIcon(Icons.unfold_more) || await tapIcon(Icons.expand_more)) {
      if (has(find.byType(BottomSheet))) {
        await snap('Choose bike sheet');
        await back();
      }
    }
  });
  await step('Record', () async {
    if (await tapText('Group', after: 1500)) {
      await snap('Group ride mode');
      await tapText('Solo');
    }
  });
  await step('Live ride', () async {
    await c.read(rideRecordingProvider.notifier).startRide();
    await wait(600);
    await go('/ride/active', after: 5000);
    await snapScroll('Active ride', maxPages: 2);
    await safe('pause', () => c.read(rideRecordingProvider.notifier).pauseRide());
    await wait(800);
    await snap('Ride paused');
    await safe('resume', () => c.read(rideRecordingProvider.notifier).resumeRide());
    await wait(600);
    if (await tapText('Discard', contains: true) || await tapTooltip('Discard ride')) {
      if (has(find.byType(AlertDialog))) await snap('Discard ride dialog');
      if (!await tapText('Discard')) await back();
    }
    // Always leave with no ride in progress.
    if (c.read(rideRecordingProvider).status != RecordingStatus.idle) {
      await safe('cancel', () => c.read(rideRecordingProvider.notifier).cancelRide());
    }
    await go('/home/record');
  });
}

Future<void> tourSocial() async {
  await step('Social', () async {
    await go('/home/social', after: 2500);
    await snapScroll('Social feed', maxPages: 3);
    final s0 = _mainScrollable();
    if (s0 != null) s0.position.jumpTo(0);
    if (await tapText('HOT', after: 2000)) {
      await snap('Social feed - hot');
      await tapText('RECENT');
    }
    final tabs = find.byType(Tab);
    final n = ev(tabs).length;
    for (var i = 1; i < n; i++) {
      await t.tap(find.byType(Tab).at(i), warnIfMissed: false);
      await wait(1800);
      final tab = t.widget<Tab>(find.byType(Tab).at(i));
      await snapScroll('Social tab ${tab.text ?? i}', maxPages: 2);
    }
    if (n > 0) {
      await t.tap(find.byType(Tab).at(0), warnIfMissed: false);
      await wait(600);
    }
  });
  await step('Shared ride', () async {
    if (data.sharedRideId == null) return;
    await push('/rides/shared/${data.sharedRideId}', extra: data.sharedRideExtra, after: 3000);
    await snapScroll('Shared ride detail', maxPages: 4);
    await back();
  });
  await step('Rider profile', () async {
    if (data.otherUid == null) return;
    await push('/profile/${data.otherUid}', after: 2500);
    await snapScroll('Another rider', maxPages: 2);
    await back();
  });
  await step('Chats', () async {
    await push('/chats', after: 2000);
    await snap('Chats');
    if (await tapIcon(Icons.edit_outlined) || await tapIcon(Icons.add) || await tapIcon(Icons.add_comment_outlined)) {
      if (has(find.byType(BottomSheet))) {
        await snap('New chat sheet');
        await back();
      }
    }
    if (data.chatId != null) {
      await push('/chats/${data.chatId}', after: 2200);
      await snap('Chat conversation');
      await back();
    }
    await back();
  });
  await step('Forums', () async {
    if (data.forumId == null) return;
    await push('/forums/${data.forumId}', after: 2500);
    await snapScroll('Forum', maxPages: 2);
    await snapOverlay('New post sheet', () => tapText('New post', after: 1200));
    if (data.forumPostId != null) {
      await push('/forums/${data.forumId}/post/${data.forumPostId}', after: 2200);
      await snap('Forum post');
      await back();
    }
    await back();
    await push('/forums/create', after: 1200);
    await snap('Create forum');
    await back();
  });
  await step('Notifications', () async {
    await push('/notifications', after: 2000);
    await snap('Notifications');
    await back();
  });
}

Future<void> tourPlaces() async {
  await step('Places', () async {
    await go('/home/places', after: 3500);
    await snapScroll('Places near you', maxPages: 3);
    final chips = find.byType(ChoiceChip).hitTestable();
    if (ev(chips).length > 1) {
      await t.tap(chips.at(1), warnIfMissed: false);
      await wait(2200);
      await snap('Places filtered');
      await t.tap(find.byType(ChoiceChip).hitTestable().at(0), warnIfMissed: false);
      await wait(600);
    }
  });
  await step('Place detail', () async {
    if (data.placeId == null) {
      // The list on screen has loaded by now even if the up-front lookup timed out.
      final loaded = c.read(nearbyPlacesProvider(null)).valueOrNull;
      if (loaded != null && loaded.isNotEmpty) data.placeId = loaded.first.id;
    }
    if (data.placeId == null) return;
    await push('/home/places/${data.placeId}', after: 3000);
    await snapScroll('Place detail', maxPages: 3);
    await back();
  });
  await step('Add place', () async {
    await push('/home/places/add', after: 2500);
    await snapScroll('Add a place', maxPages: 2);
    await back();
  });
  await step('Routes', () async {
    await push('/routes', after: 2500);
    await snap('Saved routes');
    final tabs = find.byType(Tab);
    for (var i = 1; i < ev(tabs).length; i++) {
      await t.tap(find.byType(Tab).at(i), warnIfMissed: false);
      await wait(2000);
      await snap('Routes tab ${t.widget<Tab>(find.byType(Tab).at(i)).text ?? i}');
    }
    if (data.routeId != null) {
      final q = data.routeOwner == null ? '' : '?owner=${data.routeOwner}';
      await push('/routes/${data.routeId}$q', after: 3000);
      await snapScroll('Route detail', maxPages: 2);
      await push('/routes/${data.routeId}/navigate$q', after: 3000);
      await snap('Route navigation');
      await back();
      await back();
    }
    await back();
  });
}

Future<void> tourStats() async {
  await step('Rides & stats', () async {
    await go('/home/stats', after: 2500);
    await snapScroll('Stats', maxPages: 4);
    final st = _mainScrollable();
    if (st != null) st.position.jumpTo(0);
    await wait(400);
    await snapOverlay('Badge details sheet', () => tapTextVisible('First ride', after: 1200));
  });
  await step('Rides & stats', () async {
    await push('/rides/all', after: 2000);
    await snapScroll('All rides', maxPages: 2);
    if (await tapText('TOP SPEED', after: 1500)) await snap('All rides - by top speed');
    await back();
  });
  await step('Ride summary', () async {
    if (data.rideId == null) return;
    await push('/ride/summary/${data.rideId}', after: 3500);
    await snapScroll('Ride summary', maxPages: 4);
    await back();
    await push('/ride/share/${data.rideId}', after: 3000);
    await snapScroll('Share ride', maxPages: 2);
    await back();
    await push('/routes/save/${data.rideId}', after: 2500);
    await snap('Save as route');
    await back();
  });
}

Future<void> tourProfile() async {
  await step('Profile & garage', () async {
    await go('/home/profile', after: 2500);
    await snapScroll('Profile & garage', maxPages: 3);
    final pg = _mainScrollable();
    if (pg != null) pg.position.jumpTo(0);
    await wait(400);
    await snapOverlay('Profile menu', () => tapText('View profile', after: 1200));
  });
  await step('Bike', () async {
    if (data.bikeId == null) return;
    await go('/home/profile/${data.bikeId}', after: 2500);
    await snapScroll('Bike detail', maxPages: 3);
    await go('/home/profile/${data.bikeId}/edit', after: 2000);
    await snapScroll('Edit bike', maxPages: 3);
    await go('/home/profile/add', after: 1800);
    await snapScroll('Add bike', maxPages: 2);
  });
  await step('Maintenance', () async {
    if (data.bikeId == null) return;
    await go('/home/maintenance?bikeId=${data.bikeId}', after: 2500);
    await snapScroll('Maintenance', maxPages: 4);
    final ms = _mainScrollable();
    if (ms != null) ms.position.jumpTo(0);
    await wait(400);
    await snapOverlay('Odometer sync sheet', () => tapText('Sync Odo', after: 1200));
    await go('/home/maintenance/configure?bikeId=${data.bikeId}', after: 2000);
    await snapScroll('Maintenance schedule', maxPages: 3);
    await go('/home/maintenance/add?bikeId=${data.bikeId}', after: 1800);
    await snapScroll('Log a service', maxPages: 2);
  });
  await step('Profile', () async {
    await push('/profile', after: 2500);
    await snapScroll('My profile', maxPages: 3);
    await back();
    await push('/profile/edit', after: 2000);
    await snapScroll('Edit profile', maxPages: 3);
    await back();
    await push('/places/mine', after: 2000);
    await snap('My places');
    await back();
    await push('/rides/mine', after: 2000);
    await snap('My shared rides');
    await back();
  });
  await step('Settings', () async {
    await push('/settings', after: 2000);
    await snapScroll('Settings', maxPages: 6);
    final ss = _mainScrollable();
    if (ss != null) ss.position.jumpTo(0);
    await wait(500);
    final dropdown = find.byWidgetPredicate((w) => w is DropdownButtonFormField<AppColorMode>).hitTestable();
    if (has(dropdown)) {
      await t.tap(dropdown.first, warnIfMissed: false);
      await wait(1000);
      await snap('Color picker');
      // Close by re-picking the current color, so the theme doesn't change.
      final current = c.read(appearanceProvider).colorMode;
      final item =
          find.byWidgetPredicate((w) => w is DropdownMenuItem<AppColorMode> && w.value == current).hitTestable();
      if (has(item)) {
        await t.tap(item.last, warnIfMissed: false);
      } else {
        await back();
      }
      await wait(800);
    }
    await snapOverlay('Add emergency contact', () => tapTextVisible('Add', after: 1000));
    await snapOverlay('Bug report sheet', () => tapTextVisible('Send Bug Report', after: 1200));
    await back();
    await push('/safe-qr', after: 2000);
    await snap('Safe QR');
    await back();
    await push('/blocked-users', after: 1500);
    await snap('Blocked users');
    await back();
  });
}

Future<void> runCombo(Combo combo, int index) async {
  comboDir = '${(index + 1).toString().padLeft(2, '0')}_${combo.id}';
  shot = 0;
  log('==== combo $comboDir');
  final parts = <Future<void> Function()>[
    tourAuth,
    tourOnboarding,
    tourRecord,
    tourSocial,
    tourPlaces,
    tourStats,
    tourProfile
  ];
  if (_fromPart == 0) await signOutIfNeeded();
  await applyCombo(combo);
  for (var i = _fromPart; i < parts.length; i++) {
    await parts[i]();
    if (i == 0) await applyCombo(combo); // no-op unless sign-in reloaded prefs
  }
  File('${tourDir.path}/done_$comboDir').writeAsStringSync('$shot');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('UI tour', (tester) async {
    t = tester;
    final docs = await getApplicationDocumentsDirectory();
    tourDir = Directory('${docs.path}/tour')..createSync(recursive: true);
    for (final f in tourDir.listSync()) {
      f.deleteSync();
    }
    File('${tourDir.path}/ready').writeAsStringSync('1');
    if (_dumpTexts) textLog = File('${tourDir.path}/texts.log').openWrite();

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Rendering glitches (overflow stripes etc.) must not abort the tour;
    // they are logged, and the tour keeps going.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      final frames =
          d.stack.toString().split('\n').where((l) => l.contains('package:throttleiq')).take(6).join('\n    ');
      log('flutter error: ${d.exceptionAsString().split('\n').first}\n    $frames');
    };

    try {
      await tester.pumpWidget(const ProviderScope(child: ThrottleIQApp()));
      await wait(2500);
      c = ProviderScope.containerOf(tester.element(find.byType(ThrottleIQApp)));

      // Make sure we know who we are signed in as before looking up data.
      if (FirebaseAuth.instance.currentUser?.email != _email) {
        await FirebaseAuth.instance.signOut();
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email, password: _password);
        await wait(3000);
      }
      await go('/home/record', after: 4000);
      await loadData();

      var combos = allCombos();
      final only = _onlyCombos.split(',').where((s) => s.isNotEmpty).toSet();
      for (var i = 0; i < combos.length; i++) {
        if (only.isNotEmpty && !only.contains(combos[i].id)) continue;
        await runCombo(combos[i], i);
      }

      // Leave the simulator signed in on the default look.
      await applyCombo(const Combo(AppColorMode.calming, AppShapeVibe.curvy, Brightness.light));
      await textLog?.flush();
      await textLog?.close();
    } catch (e, st) {
      log('!! tour aborted: $e\n$st');
    } finally {
      File('${tourDir.path}/finished').writeAsStringSync('1');
      FlutterError.onError = originalOnError;
    }
  }, timeout: Timeout.none);
}
