import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n_lookup.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/root_messenger.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/utilities/follow_link.dart';
import '../domain/utilities/follow_link_outcome.dart';
import 'providers/follow_link_providers.dart';

/// Turns follow links opened from outside the app — the system camera, a
/// browser, the web fallback page's `throttleiq://u/<uid>` hand-off — into a
/// follow, then lands on the People tab.
///
/// Every link is stashed on disk first ([FollowLinkStore.savePendingFollow])
/// and acted on only once the app is somewhere a follow makes sense: signed
/// in, past onboarding, and off the splash/auth screens. So a link that
/// cold-starts the app, or arrives while signed out, is completed after the
/// splash or after sign-in instead of being lost. Re-checked on every route
/// change, which is exactly when those conditions can start holding.
///
/// Flutter's own deep linking is turned off on both platforms
/// (`flutter_deeplinking_enabled` / `FlutterDeepLinkingEnabled`), so go_router
/// never tries to open `/ThrottleIQ/u/<uid>` as a route itself.
final followLinkListenerProvider = Provider<FollowLinkListener>((ref) {
  final listener = FollowLinkListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});

class FollowLinkListener {
  FollowLinkListener(this._ref);

  final Ref _ref;
  StreamSubscription<Uri>? _linkSub;
  VoidCallback? _routeListener;
  String? _pendingUid;
  bool _draining = false;
  bool _started = false;

  /// Subscribes once. Safe to call more than once.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final router = _ref.read(routerProvider);
    void onRoute() => unawaited(_drain());
    router.routerDelegate.addListener(onRoute);
    _routeListener = () => router.routerDelegate.removeListener(onRoute);
    _ref.listen(authStateProvider, (_, __) => unawaited(_drain()));

    try {
      _pendingUid =
          await _ref.read(followLinkStoreProvider).readPendingFollow();
    } catch (e) {
      debugPrint('[follow-link] pending read failed: $e');
    }

    try {
      // Emits the link that launched the app too, then every later one.
      _linkSub = AppLinks().uriLinkStream.listen(
            _onLink,
            onError: (Object e) => debugPrint('[follow-link] stream error: $e'),
          );
    } catch (e) {
      // No plugin (tests, unsupported platform): links just don't arrive.
      debugPrint('[follow-link] app_links unavailable: $e');
    }
    unawaited(_drain());
  }

  Future<void> _onLink(Uri uri) async {
    final uid = parseFollowUri(uri);
    // Not a follow link (e.g. a home-widget throttleiq://startride, which
    // home_widget handles) — leave it alone.
    if (uid == null) return;
    _pendingUid = uid;
    try {
      await _ref.read(followLinkStoreProvider).savePendingFollow(uid);
    } catch (e) {
      debugPrint('[follow-link] pending save failed: $e');
    }
    if (_ref.read(currentUserProvider) == null) {
      _showMessage(
          resolveL10n(_ref.read(appLocaleProvider)).followLinkSignInFirst);
    }
    await _drain();
  }

  bool get _readyToFollow {
    final user = _ref.read(currentUserProvider);
    if (user == null || user.displayName == null) return false;
    final path =
        _ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
    return path.isNotEmpty && path != '/splash' && !path.startsWith('/auth');
  }

  Future<void> _drain() async {
    final uid = _pendingUid;
    if (uid == null || _draining || !_readyToFollow) return;
    _draining = true;
    _pendingUid = null;
    try {
      await _ref.read(followLinkStoreProvider).clearPendingFollow();
      final l10n = resolveL10n(_ref.read(appLocaleProvider));
      final result = await _ref
          .read(followLinkControllerProvider)
          .followUid(uid, l10n: l10n);
      if (result.outcome == FollowLinkOutcome.followed ||
          result.outcome == FollowLinkOutcome.alreadyFollowing) {
        _ref.read(routerProvider).go(kFollowLinkLandingRoute);
      }
      _showMessage(followLinkResultMessage(l10n, result));
    } catch (e) {
      debugPrint('[follow-link] follow failed: $e');
    } finally {
      _draining = false;
    }
  }

  void _showMessage(String text) {
    rootScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void dispose() {
    _linkSub?.cancel();
    _routeListener?.call();
  }
}
