import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/presentation/widgets/ride_media_collage.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

final Uint8List _kTransparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {}
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {}
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}
  @override
  void close({bool force = false}) {}
  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> putUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> patchUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> headUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> get(String host, int port, String path) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> post(String host, int port, String path) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> put(String host, int port, String path) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> head(String host, int port, String path) async => _FakeHttpClientRequest();
  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) {}
  @override
  set keyLog(Function(String line)? callback) {}
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool bufferOutput = false;
  @override
  int contentLength = -1;
  @override
  Encoding encoding = utf8;
  @override
  bool followRedirects = false;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = false;

  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {} // ignore: strict_raw_type // TODO(audit-101): fix strict mode typing
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];
  @override
  Future<HttpClientResponse> get done async => _FakeHttpClientResponse();
  @override
  Future flush() async {} // ignore: strict_raw_type // TODO(audit-101): fix strict mode typing
  @override
  String get method => 'GET';
  @override
  Uri get uri => Uri.parse('http://localhost');
  @override
  void write(Object? obj) {}
  @override
  void writeAll(Iterable objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? obj = '']) {}
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];
  @override
  X509Certificate? get certificate => null;
  @override
  Future<Socket> detachSocket() async => throw UnimplementedError();
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  List<RedirectInfo> get redirects => [];

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.value(_kTransparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) async => this;
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  List<String>? operator [](String name) => null;
  @override
  void add(String name, Object value, {bool? preserveHeaderCase}) {}
  @override
  void clear() {}
  @override
  void forEach(void Function(String name, List<String> values) action) {}
  @override
  void noFolding(String name) {}
  @override
  void remove(String name, Object value) {}
  @override
  void removeAll(String name) {}
  @override
  void set(String name, Object value, {bool? preserveHeaderCase}) {}
  @override
  String? value(String name) => null;
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = 0;
  @override
  ContentType? contentType;
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host;
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = false;
  @override
  int? port;
}

const _size = Size(360, 220);
const _gap = kCollageGap;

/// Every rect sits inside the canvas, and no two overlap.
void _expectTiled(List<Rect> rects, Size size) {
  final canvas = Offset.zero & size;
  for (final r in rects) {
    expect(r.width, greaterThan(0));
    expect(r.height, greaterThan(0));
    expect(canvas.inflate(0.001).contains(r.topLeft), isTrue, reason: '$r');
    expect(canvas.inflate(0.001).contains(r.bottomRight), isTrue, reason: '$r');
  }
  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      final o = rects[i].intersect(rects[j]);
      expect(o.width <= 0.001 || o.height <= 0.001, isTrue,
          reason: 'tile $i ${rects[i]} overlaps tile $j ${rects[j]}');
    }
  }
}

double _area(Rect r) => r.width * r.height;

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  group('rideMediaCollageLayout', () {
    test('nothing to lay out yields no tiles', () {
      expect(rideMediaCollageLayout(0, _size), isEmpty);
      expect(rideMediaCollageLayout(3, Size.zero), isEmpty);
    });

    test('1 tile is full-bleed', () {
      expect(rideMediaCollageLayout(1, _size), [Offset.zero & _size]);
    });

    test('2 tiles sit side by side, lead wider, full height', () {
      final r = rideMediaCollageLayout(2, _size);
      expect(r, hasLength(2));
      _expectTiled(r, _size);
      expect(r[0].left, 0);
      expect(r[1].right, closeTo(_size.width, 0.001));
      expect(r[1].left - r[0].right, closeTo(_gap, 0.001));
      expect(r[0].width, greaterThan(r[1].width));
      expect(r.every((t) => t.height == _size.height), isTrue);
    });

    test('3 tiles: lead left, two stacked right', () {
      final r = rideMediaCollageLayout(3, _size);
      expect(r, hasLength(3));
      _expectTiled(r, _size);
      expect(r[0].height, _size.height);
      expect(r[1].left, r[2].left);
      expect(r[2].top - r[1].bottom, closeTo(_gap, 0.001));
      expect(r[2].bottom, closeTo(_size.height, 0.001));
      expect(_area(r[0]), greaterThan(_area(r[1]) + _area(r[2])));
    });

    test('4 tiles: lead across the top, three in a row below', () {
      final r = rideMediaCollageLayout(4, _size);
      expect(r, hasLength(4));
      _expectTiled(r, _size);
      expect(r[0].width, _size.width);
      final row = r.sublist(1);
      expect(row.map((t) => t.top).toSet(), hasLength(1));
      expect(row.first.top - r[0].bottom, closeTo(_gap, 0.001));
      expect(row.last.right, closeTo(_size.width, 0.001));
      for (final t in row) {
        expect(t.width, closeTo(row.first.width, 0.001));
        expect(t.bottom, closeTo(_size.height, 0.001));
      }
      expect(_area(r[0]), greaterThan(_area(r[1])));
    });

    test('5+ tiles: lead left, 2x2 grid right, capped at the visible max', () {
      for (final n in [5, 6, 9]) {
        final r = rideMediaCollageLayout(n, _size);
        expect(r, hasLength(kCollageMaxVisibleTiles), reason: 'n=$n');
        _expectTiled(r, _size);
        expect(r[0].height, _size.height);
        final grid = r.sublist(1);
        for (final t in grid) {
          expect(t.width, closeTo(grid.first.width, 0.001));
          expect(t.height, closeTo(grid.first.height, 0.001));
        }
        expect(grid.last.right, closeTo(_size.width, 0.001));
        expect(grid.last.bottom, closeTo(_size.height, 0.001));
      }
    });

    test('overflow badge counts only hidden tiles', () {
      expect(rideMediaCollageOverflow(1), 0);
      expect(rideMediaCollageOverflow(kCollageMaxVisibleTiles), 0);
      expect(rideMediaCollageOverflow(kCollageMaxVisibleTiles + 2), 2);
    });

    test('lone map keeps the compact strip; photos get more room', () {
      expect(rideMediaCollageHeight(1), lessThan(rideMediaCollageHeight(2)));
    });
  });

  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
      );

  const mapKey = ValueKey('fake_map');
  Widget fakeMap() => Container(key: mapKey, color: Colors.green);

  List<String> urls(int n) =>
      [for (var i = 1; i <= n; i++) 'https://example.com/pic$i.jpg'];

  group('RideMediaCollage', () {
    testWidgets('renders nothing with no map and no photos', (tester) async {
      await tester.pumpWidget(host(RideMediaCollage.network(urls: const [])));
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(Positioned), findsNothing);
    });

    testWidgets('map alone fills the collage', (tester) async {
      await tester.pumpWidget(
          host(RideMediaCollage.network(urls: const [], map: fakeMap())));
      expect(find.byKey(mapKey), findsOneWidget);
      expect(tester.getSize(find.byKey(mapKey)),
          Size(360, rideMediaCollageHeight(1)));
    });

    for (final n in [1, 2, 3]) {
      testWidgets('map + $n photo(s) render as ${n + 1} tiles, no PageView',
          (tester) async {
        await tester.pumpWidget(
            host(RideMediaCollage.network(urls: urls(n), map: fakeMap())));
        await tester.pump();
        expect(find.byKey(mapKey), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsNWidgets(n));
        expect(find.byType(PageView), findsNothing);
        // The map is the lead, i.e. the biggest tile.
        final mapArea = tester.getSize(find.byKey(mapKey));
        for (var i = 0; i < n; i++) {
          final p = tester.getSize(find.byKey(ValueKey('collage_photo_tile_$i')));
          expect(mapArea.width * mapArea.height,
              greaterThanOrEqualTo(p.width * p.height));
        }
      });
    }

    testWidgets('more tiles than fit show a +N badge', (tester) async {
      await tester.pumpWidget(
          host(RideMediaCollage.network(urls: urls(6), map: fakeMap())));
      await tester.pump();
      // 7 tiles, 5 visible: map + photos 0..3; the last carries +2.
      expect(find.byType(CachedNetworkImage), findsNWidgets(4));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('tapping the map tile calls onMapTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(RideMediaCollage.network(
          urls: urls(2), map: fakeMap(), onMapTap: () => taps++)));
      await tester.tap(find.byKey(mapKey));
      expect(taps, 1);
      expect(find.byType(FullScreenGalleryDialog), findsNothing);
    });

    testWidgets('tapping a photo opens the gallery at that photo',
        (tester) async {
      await tester.pumpWidget(
          host(RideMediaCollage.network(urls: urls(3), map: fakeMap())));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('collage_photo_tile_1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FullScreenGalleryDialog), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FullScreenGalleryDialog), findsNothing);
    });

    testWidgets('photos-only collage (detail screen) starts at photo 0',
        (tester) async {
      await tester.pumpWidget(host(RideMediaCollage.network(urls: urls(2))));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('collage_photo_tile_0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1/2'), findsOneWidget);
    });
  });
}
