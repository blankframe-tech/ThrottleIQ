import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/profile/presentation/providers/profile_providers.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/social/presentation/providers/ride_feed_provider.dart';
import 'package:throttleiq/features/social/presentation/screens/social_screen.dart';
import 'package:throttleiq/shared/widgets/ride_route_map.dart';

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
  Future addStream(Stream<List<int>> stream) async {}
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];
  @override
  Future<HttpClientResponse> get done async => _FakeHttpClientResponse();
  @override
  Future flush() async {}
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

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  final testRide = SharedRideEntity(
    id: 'ride_shared_42',
    userId: 'rider_99',
    userName: 'DhakaRider',
    userPhotoUrl: '',
    bikeId: 'bike_99',
    bikeName: 'Yamaha MT-15',
    bikeType: 'Naked',
    rideDate: DateTime(2026, 9, 2, 10, 0),
    distanceKm: 42.0,
    durationSeconds: 3600,
    maxSpeedKmh: 110.0,
    polyline: const [
      LatLng(23.8103, 90.4125),
      LatLng(23.8200, 90.4200),
    ],
    caption: 'Morning highway run',
    createdAt: DateTime(2026, 9, 2, 11, 0),
  );

  testWidgets('Clicking map on feed card navigates to shared ride detail page', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SocialScreen(),
        ),
        GoRoute(
          path: '/rides/shared/:rideId',
          builder: (_, state) => Scaffold(
            appBar: AppBar(title: const Text('Detail Page')),
            body: Text('SharedRideDetailView:${state.pathParameters['rideId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          rideFeedProvider.overrideWith((ref) => Future.value([testRide])),
          visibleFeedProvider.overrideWithValue([testRide]),
          followingUidsProvider.overrideWith((ref) => Future.value(const <String>{})),
          blockedUsersProvider.overrideWith((ref) => Future.value(const <String>{})),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify ride is visible in the feed
    expect(find.text('Yamaha MT-15'), findsOneWidget);
    expect(find.text('Morning highway run'), findsOneWidget);
    expect(find.byType(RideRouteMap), findsOneWidget);

    // Tap the map preview directly (hit-tests the surrounding InkWell)
    await tester.tap(find.byType(RideRouteMap), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify it navigated to the shared ride detail page
    expect(find.text('SharedRideDetailView:ride_shared_42'), findsOneWidget);
  });

  testWidgets('Clicking card header/body on feed navigates to shared ride detail page', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SocialScreen(),
        ),
        GoRoute(
          path: '/rides/shared/:rideId',
          builder: (_, state) => Scaffold(
            appBar: AppBar(title: const Text('Detail Page')),
            body: Text('SharedRideDetailView:${state.pathParameters['rideId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          rideFeedProvider.overrideWith((ref) => Future.value([testRide])),
          visibleFeedProvider.overrideWithValue([testRide]),
          followingUidsProvider.overrideWith((ref) => Future.value(const <String>{})),
          blockedUsersProvider.overrideWith((ref) => Future.value(const <String>{})),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the bike name in the card header
    await tester.tap(find.text('Yamaha MT-15'));
    await tester.pumpAndSettle();

    // Verify it navigated to the shared ride detail page
    expect(find.text('SharedRideDetailView:ride_shared_42'), findsOneWidget);
  });
}
