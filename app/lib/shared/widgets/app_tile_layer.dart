import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// The one base-map layer every [FlutterMap] in the app uses.
///
/// Drop it in as a map child in place of a hand-written `TileLayer`. It
/// centralizes three things that used to be copy-pasted at eight call sites:
///
/// * **Which tile server.** Configured at build time, so switching providers
///   (or adding a key) never touches a screen:
///   ```
///   flutter run \
///     --dart-define=TILE_URL_TEMPLATE='https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key={apiKey}' \
///     --dart-define=TILE_API_KEY=... \
///     --dart-define=TILE_ATTRIBUTION='MapTiler © OpenStreetMap contributors'
///   ```
///   `{apiKey}` in the template is filled from `TILE_API_KEY`. With no
///   defines it falls back to the public OSM servers, exactly as before —
///   fine for development, but OSM's tile usage policy doesn't allow a
///   shipped app to rely on them, so release builds should pass a provider.
/// * **An on-disk tile cache.** Tiles are served from the cache first and
///   kept for [_maxStale], so revisited areas (home, the daily commute) load
///   instantly, keep working with no signal, and don't re-hit the tile
///   server. The cache lives in the OS cache directory, so the OS can reclaim
///   it under storage pressure.
/// * **Attribution.** Required by OSM's licence and by every hosted provider.
class AppTileLayer extends StatelessWidget {
  const AppTileLayer({super.key});

  static const _defaultUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const _urlTemplate = String.fromEnvironment(
    'TILE_URL_TEMPLATE',
    defaultValue: _defaultUrlTemplate,
  );
  static const _apiKey = String.fromEnvironment('TILE_API_KEY');
  static const _attribution = String.fromEnvironment(
    'TILE_ATTRIBUTION',
    defaultValue: 'OpenStreetMap contributors',
  );

  /// Matches the Android applicationId / iOS bundle id. Tile servers (OSM in
  /// particular) use the User-Agent to identify, and if need be block, apps.
  static const _userAgentPackageName = 'com.bft.throttleiq';

  /// OSM's tile usage policy asks for a User-Agent that identifies the app
  /// and gives a contact, which flutter_map's default built from
  /// [_userAgentPackageName] ("flutter_map (com.bft.throttleiq)") lacks.
  /// This one wins because flutter_map only fills the header if it's absent.
  /// A fresh map per provider: flutter_map writes into it, so it can't be
  /// const.
  static Map<String, String> _headers() => {
        'User-Agent':
            'ThrottleIQ ($_userAgentPackageName; contact@blankframe.com)',
      };

  static const _maxStale = Duration(days: 30);

  /// One provider (and so one cache store and one Dio client) shared by
  /// every map. [TileLayer] disposes its provider when it goes away, but
  /// [CachedTileProvider.dispose] holds nothing to release, so sharing is
  /// safe. A single store also matters because [FileCacheStore] sweeps stale
  /// entries each time one is constructed.
  @visibleForTesting
  static final CachedTileProvider cachedTileProvider = CachedTileProvider(
    store: _DeferredTileStore(),
    headers: _headers(),
    maxStale: _maxStale,
    keyBuilder: _cacheKey,
  );

  /// Under `flutter test`, every tile resolves to a single transparent pixel
  /// and **no HTTP request is made at all**.
  ///
  /// Two reasons. The cached provider fetches through Dio, which schedules
  /// zero-length timers per tile, so any screen test ending right after a map
  /// pan or zoom failed on "a Timer is still pending". And the plain
  /// `NetworkTileProvider` this used to fall back to did reach the network —
  /// a `flutter test` run emitted a wall of
  /// `ClientException ... uri=https://tile.openstreetmap.org/...`, which is
  /// flaky, slow, and rude to a volunteer-funded service that asks apps not to
  /// bulk-fetch from it (new_gravity.md §2 / issues_open.md §81).
  static final TileProvider _tileProvider =
      Platform.environment.containsKey('FLUTTER_TEST')
          ? _BlankTileProvider(headers: _headers())
          : cachedTileProvider;

  /// The cache key is the tile URL with the API key removed, so rotating the
  /// key doesn't throw away the cache and the key isn't written to disk.
  static String _cacheKey({
    required Uri url,
    Map<String, String>? headers,
    Object? body,
  }) {
    final stripped = _apiKey.isEmpty
        ? url
        : Uri.parse(url.toString().replaceAll(_apiKey, ''));
    return CacheOptions.defaultCacheKeyBuilder(url: stripped);
  }

  static final Uri _copyrightUrl =
      Uri.parse('https://www.openstreetmap.org/copyright');

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TileLayer(
          urlTemplate: _urlTemplate,
          additionalOptions: const {'apiKey': _apiKey},
          userAgentPackageName: _userAgentPackageName,
          tileProvider: _tileProvider,
        ),
        // Hand-rolled rather than flutter_map's SimpleAttributionWidget,
        // which prefixes "flutter_map |" at full text size and overflows the
        // small feed-card maps. One ellipsized line can't overflow.
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            onTap: () => launchUrl(
              _copyrightUrl,
              mode: LaunchMode.externalApplication,
            ),
            child: const ColoredBox(
              color: Color(0xB3FFFFFF),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  '© $_attribution',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Color(0xFF333333)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A [FileCacheStore] whose directory is resolved on first use.
///
/// [FileCacheStore] needs a path up front, but `path_provider` is async and
/// [AppTileLayer] has to build synchronously. Every call waits for the real
/// store instead. If the directory can't be resolved (no platform channel,
/// as in widget tests) it degrades to an in-memory cache rather than failing
/// tile loads.
class _DeferredTileStore extends CacheStore {
  late final Future<CacheStore> _store = _open();

  static Future<CacheStore> _open() async {
    try {
      final dir = await getApplicationCacheDirectory();
      return FileCacheStore(p.join(dir.path, 'map_tiles'));
    } catch (e) {
      debugPrint('AppTileLayer: disk tile cache unavailable ($e)');
      return MemCacheStore();
    }
  }

  @override
  Future<bool> exists(String key) async => (await _store).exists(key);

  @override
  Future<CacheResponse?> get(String key) async => (await _store).get(key);

  @override
  Future<List<CacheResponse>> getFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async =>
      (await _store).getFromPath(pathPattern, queryParams: queryParams);

  @override
  Future<void> set(CacheResponse response) async =>
      (await _store).set(response);

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async =>
      (await _store).delete(key, staleOnly: staleOnly);

  @override
  Future<void> deleteFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async =>
      (await _store).deleteFromPath(pathPattern, queryParams: queryParams);

  @override
  Future<void> clean({
    CachePriority priorityOrBelow = CachePriority.high,
    bool staleOnly = false,
  }) async =>
      (await _store).clean(
        priorityOrBelow: priorityOrBelow,
        staleOnly: staleOnly,
      );

  @override
  Future<void> close() async => (await _store).close();
}

/// Serves a 1×1 transparent PNG for every tile, without touching the network.
/// Test-only — see [AppTileLayer._tileProvider].
class _BlankTileProvider extends TileProvider {
  /// Still carries the app's User-Agent even though nothing is fetched, so the
  /// header contract stays observable under test — that identifying UA is a
  /// tile-policy requirement and worth keeping a test on.
  _BlankTileProvider({super.headers});

  /// A 1×1 fully transparent PNG.
  static final Uint8List _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}
