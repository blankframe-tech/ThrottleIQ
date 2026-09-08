import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/presentation/screens/social_screen.dart';

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

  Widget buildTestWidget(List<String> urls, {double height = 200}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 180,
            height: height,
            child: PhotoCollage(urls: urls, height: height),
          ),
        ),
      ),
    );
  }

  testWidgets('PhotoCollage renders empty box when urls is empty', (tester) async {
    await tester.pumpWidget(buildTestWidget([]));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('PhotoCollage renders 1 photo filling container without PageView', (tester) async {
    await tester.pumpWidget(buildTestWidget(['https://example.com/pic1.jpg']));
    await tester.pump();

    // Exactly 1 image rendered
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    // Crucially: no PageView in the collage (not scrollable)
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('PhotoCollage renders 2 photos in vertical split without PageView', (tester) async {
    await tester.pumpWidget(buildTestWidget([
      'https://example.com/pic1.jpg',
      'https://example.com/pic2.jpg',
    ]));
    await tester.pump();

    // Both images visible simultaneously
    expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    // No swipeable PageView
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('PhotoCollage renders 3 photos simultaneously in collage without PageView', (tester) async {
    await tester.pumpWidget(buildTestWidget([
      'https://example.com/pic1.jpg',
      'https://example.com/pic2.jpg',
      'https://example.com/pic3.jpg',
    ]));
    await tester.pump();

    // All 3 images visible at once
    expect(find.byType(CachedNetworkImage), findsNWidgets(3));
    // No swipeable PageView
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('Tapping a photo in PhotoCollage opens FullScreenGalleryDialog with PageView', (tester) async {
    await tester.pumpWidget(buildTestWidget([
      'https://example.com/pic1.jpg',
      'https://example.com/pic2.jpg',
      'https://example.com/pic3.jpg',
    ]));
    await tester.pump();

    // Initially no fullscreen dialog or PageView
    expect(find.byType(FullScreenGalleryDialog), findsNothing);
    expect(find.byType(PageView), findsNothing);

    // Tap first image
    await tester.tap(find.byType(CachedNetworkImage).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dialog is open with fullscreen PageView and counter
    expect(find.byType(FullScreenGalleryDialog), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);

    // Tap close button to dismiss dialog
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FullScreenGalleryDialog), findsNothing);
  });
}
