import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:throttleiq_mayabi/throttleiq_mayabi.dart';

/// A local stand-in for the partner API: records requests, replies with
/// whatever [reply] returns.
class _Server {
  late HttpServer _s;
  final requests =
      <({String method, String path, String? key, Object? body})>[];
  (int, Object?) Function(String method, String path) reply =
      (_, __) => (200, <String, Object?>{});

  Future<Uri> start() async {
    _s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _s.listen((req) async {
      final text = await utf8.decoder.bind(req).join();
      requests.add((
        method: req.method,
        path: req.uri.path,
        key: req.headers.value('x-api-key'),
        body: text.isEmpty ? null : jsonDecode(text),
      ));
      final (status, body) = reply(req.method, req.uri.path);
      req.response.statusCode = status;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(body));
      await req.response.close();
    });
    return Uri.parse('http://127.0.0.1:${_s.port}/api/partner/');
  }

  Future<void> stop() => _s.close(force: true);
}

const _score = {
  'rideId': 'r1',
  'score': 91,
  'tier': 'smooth',
  'eventScore': 95,
  'roadPenalty': 4,
  'overspeedPenalty': 0,
  'segmentsCompared': 2,
  'fasterThanUsual': [
    {
      'segmentId': 'wh0r3qt',
      'speedKmh': 75,
      'typicalKmh': 30,
      'basis': 'morningPeak'
    },
  ],
  'scoringVersion': 1,
  'replayed': false,
};

RideReport _report() => RideReport(
      rideId: 'r1',
      riderRef: 'mayabi-42',
      startedAt: DateTime.utc(2026, 10, 17, 3),
      endedAt: DateTime.utc(2026, 10, 17, 3, 30),
      pickupKm: 3,
      tripKm: 8,
      homeKm: 6,
      movingSeconds: 1500,
      avgSpeedKmh: 22,
      maxSpeedKmh: 48,
      hardBrakes: 1,
      rapidAccels: 0,
      highJerks: 0,
      overspeeds: 0,
      weatherCode: null,
      segments: const [
        (segmentId: 'wh0r3qs', avgSpeedKmh: 25.0, pointCount: 12)
      ],
      impacts: const [],
    );

void main() {
  late _Server server;
  late ThrottleIqClient client;

  setUp(() async {
    server = _Server();
    client = ThrottleIqClient(
        apiKey: 'tiq_maya_test', baseUrl: await server.start());
  });
  tearDown(() async {
    client.close();
    await server.stop();
  });

  test('uploadRide posts the report with the key and parses the score',
      () async {
    server.reply = (_, __) => (200, _score);
    final s = await client.uploadRide(_report());
    expect(server.requests.single.method, 'POST');
    expect(server.requests.single.path, '/api/partner/v1/rides');
    expect(server.requests.single.key, 'tiq_maya_test');
    expect((server.requests.single.body as Map)['returnKm'], 6);
    expect(s.score, 91);
    expect(s.fasterThanUsual.single.typicalKmh, 30);
    expect(s.replayed, isFalse);
  });

  test('errors carry status and the server message; 4xx is not retryable',
      () async {
    server.reply = (_, __) => (
          400,
          {'error': 'segmentId must be a precision-7 geohash in Bangladesh'}
        );
    await expectLater(
      client.uploadRide(_report()),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 400)
          .having((e) => e.retryable, 'retryable', isFalse)
          .having((e) => e.message, 'message', contains('geohash'))),
    );
    server.reply = (_, __) => (503, 'down');
    await expectLater(
        client.uploadRide(_report()),
        throwsA(isA<ApiException>()
            .having((e) => e.retryable, 'retryable', isTrue)));
  });

  test('riderScore is null on 404 and parsed otherwise', () async {
    server.reply = (_, __) => (404, {'error': 'no rides for this rider yet'});
    expect(await client.riderScore('mayabi-42'), isNull);
    server.reply = (_, __) => (
          200,
          {
            'riderRef': 'mayabi-42',
            'rides': 3,
            'distanceKm': 40.5,
            'averageScore': 88.3,
            'recentAverageScore': 90,
            'recentScores': [85, 90, 90],
            'tier': 'smooth',
            'hardBrakes': 2,
            'rapidAccels': 1,
            'overspeeds': 0,
            'fellReports': 0,
          }
        );
    final r = (await client.riderScore('mayabi-42'))!;
    expect(r.rides, 3);
    expect(r.recentScores, [85, 90, 90]);
    expect(server.requests.last.path, '/api/partner/v1/riders/mayabi-42');
  });

  test('deleteRider sends DELETE and returns the count', () async {
    server.reply = (_, __) => (200, {'riderRef': 'mayabi-42', 'deleted': 5});
    expect(await client.deleteRider('mayabi-42'), 5);
    expect(server.requests.single.method, 'DELETE');
    expect(server.requests.single.path, '/api/partner/v1/riders/mayabi-42');
  });

  test('live share: start, update, end', () async {
    server.reply = (m, p) => p.endsWith('/v1/live')
        ? (
            201,
            {
              'token': 'T' * 32,
              'url': 'https://throttleiqfb.web.app/live/${'T' * 32}',
              'expiresAt': '2026-10-17T15:00:00.000Z'
            }
          )
        : (200, {'ok': true});
    final live = await client.startLive(
        riderRef: 'mayabi-42', lat: 23.79, lng: 90.40, batteryPct: 80);
    expect(live.url.path, '/live/${'T' * 32}');
    await client.updateLive(live.token,
        lat: 23.791, lng: 90.401, speedMs: 6, paused: true);
    await client.endLive(live.token);
    expect(server.requests.map((r) => '${r.method} ${r.path}'), [
      'POST /api/partner/v1/live',
      'POST /api/partner/v1/live/${'T' * 32}',
      'DELETE /api/partner/v1/live/${'T' * 32}',
    ]);
    expect((server.requests[1].body as Map)['status'], 'paused');
  });

  test('sendAlert sends the kind and returns delivery', () async {
    server.reply = (_, __) =>
        (201, {'alertId': 'a1', 'delivery': 'failed_network', 'liveUrl': null});
    final a = await client.sendAlert(
        riderRef: 'mayabi-42',
        kind: AlertKind.unusualStop,
        lat: 23.79,
        lng: 90.4);
    expect((server.requests.single.body as Map)['kind'], 'unusualStop');
    expect(a.delivered, isFalse);
    expect(a.liveUrl, isNull);
  });

  test('LiveShareThrottle: first, 100 m, 15 s, pause change', () {
    final g = LiveShareThrottle();
    final t = DateTime(2026, 10, 17, 9);
    expect(g.shouldSend(t, 23.79, 90.40), isTrue);
    expect(g.shouldSend(t.add(const Duration(seconds: 5)), 23.79, 90.4005),
        isFalse); // ~51 m
    expect(g.shouldSend(t.add(const Duration(seconds: 6)), 23.79, 90.4011),
        isTrue); // ~112 m
    expect(
        g.shouldSend(t.add(const Duration(seconds: 7)), 23.79, 90.4011,
            paused: true),
        isTrue);
    expect(
        g.shouldSend(t.add(const Duration(seconds: 8)), 23.79, 90.4011,
            paused: true),
        isFalse);
    expect(
        g.shouldSend(t.add(const Duration(seconds: 22)), 23.79, 90.4011,
            paused: true),
        isTrue);
  });
}
