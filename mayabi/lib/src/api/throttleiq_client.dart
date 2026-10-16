import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../ride/ride_report.dart';

/// The API answered with an error. [statusCode] 400 means the payload was
/// refused (don't retry it), 401 a bad or revoked key, 5xx or a
/// [SocketException]/[TimeoutException] means try again later.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  bool get retryable => statusCode >= 500 || statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// A road cell the rider rode far faster than the Dhaka pool usually does.
class FasterThanUsual {
  final String segmentId;
  final double speedKmh;
  final double typicalKmh;

  /// Which pool the comparison used: `wet`, a time band, or `all`.
  final String basis;

  FasterThanUsual.fromJson(Map<String, Object?> j)
      : segmentId = j['segmentId'] as String,
        speedKmh = (j['speedKmh'] as num).toDouble(),
        typicalKmh = (j['typicalKmh'] as num).toDouble(),
        basis = j['basis'] as String;
}

/// The server's score for one ride.
class RideScore {
  final String rideId;
  final int score;

  /// `smooth` (≥ 80), `steady` (≥ 60) or `aggressive`.
  final String tier;
  final int eventScore;
  final int roadPenalty;
  final int overspeedPenalty;
  final int segmentsCompared;
  final List<FasterThanUsual> fasterThanUsual;
  final int scoringVersion;

  /// True when this ride had been uploaded before (a retry).
  final bool replayed;

  RideScore.fromJson(Map<String, Object?> j)
      : rideId = j['rideId'] as String,
        score = (j['score'] as num).round(),
        tier = j['tier'] as String,
        eventScore = (j['eventScore'] as num).round(),
        roadPenalty = (j['roadPenalty'] as num).round(),
        overspeedPenalty = (j['overspeedPenalty'] as num).round(),
        segmentsCompared = j['segmentsCompared'] as int,
        fasterThanUsual = [
          for (final f
              in (j['fasterThanUsual'] as List).cast<Map<String, Object?>>())
            FasterThanUsual.fromJson(f),
        ],
        scoringVersion = j['scoringVersion'] as int,
        replayed = j['replayed'] as bool;
}

/// A rider's running score with Maya: for vetting, training and rewards.
class RiderScore {
  final String riderRef;
  final int rides;
  final double distanceKm;
  final double averageScore;
  final double recentAverageScore;
  final List<int> recentScores;
  final String tier;
  final int hardBrakes;
  final int rapidAccels;
  final int overspeeds;
  final int fellReports;

  RiderScore.fromJson(Map<String, Object?> j)
      : riderRef = j['riderRef'] as String,
        rides = j['rides'] as int,
        distanceKm = (j['distanceKm'] as num).toDouble(),
        averageScore = (j['averageScore'] as num).toDouble(),
        recentAverageScore = (j['recentAverageScore'] as num).toDouble(),
        recentScores = [
          for (final s in j['recentScores'] as List) (s as num).round()
        ],
        tier = j['tier'] as String,
        hardBrakes = j['hardBrakes'] as int,
        rapidAccels = j['rapidAccels'] as int,
        overspeeds = j['overspeeds'] as int,
        fellReports = j['fellReports'] as int;
}

/// A live-share link: anyone with [url] sees the rider's position in a
/// browser, no app needed, until it ends or [expiresAt] (12 h).
class LiveShare {
  final String token;
  final Uri url;
  final DateTime expiresAt;

  LiveShare.fromJson(Map<String, Object?> j)
      : token = j['token'] as String,
        url = Uri.parse(j['url'] as String),
        expiresAt = DateTime.parse(j['expiresAt'] as String);
}

enum AlertKind { sos, crash, unusualStop }

class AlertResult {
  final String alertId;

  /// `delivered`, `no_webhook`, `failed_network` or `failed_http_<code>`:
  /// whether Maya's ops webhook got it. Anything but `delivered` means the
  /// app must still offer SMS/999 (it should anyway).
  final String delivery;
  final Uri? liveUrl;

  AlertResult.fromJson(Map<String, Object?> j)
      : alertId = j['alertId'] as String,
        delivery = j['delivery'] as String,
        liveUrl =
            j['liveUrl'] == null ? null : Uri.parse(j['liveUrl'] as String);

  bool get delivered => delivery == 'delivered';
}

/// Client for the ThrottleIQ partner API (mayabi/API.md).
///
/// The API key identifies Maya, not a rider. Anyone holding it can write to
/// Maya's account, so prefer calling from Maya's own server; if it ships
/// inside the app, rotate it when a build leaks (see README).
class ThrottleIqClient {
  ThrottleIqClient({
    required String apiKey,
    Uri? baseUrl,
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 15),
  })  : _apiKey = apiKey,
        _base = baseUrl ?? defaultBaseUrl,
        _http = httpClient ?? HttpClient();

  static final defaultBaseUrl =
      Uri.parse('https://throttleiqfb.web.app/api/partner/');

  final String _apiKey;
  final Uri _base;
  final HttpClient _http;
  final Duration timeout;

  /// Uploads a finished ride and returns its score. Safe to retry with the
  /// same report: the server keys it by `rideId` and won't count it twice.
  Future<RideScore> uploadRide(RideReport report) async =>
      RideScore.fromJson(await _send('POST', 'v1/rides', report.toJson()));

  /// Null while the rider has no uploaded rides.
  Future<RiderScore?> riderScore(String riderRef) async {
    try {
      return RiderScore.fromJson(
          await _send('GET', 'v1/riders/${Uri.encodeComponent(riderRef)}'));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Erases the rider's rides, score, alerts and live links at ThrottleIQ
  /// (e.g. when she leaves Maya or asks). Returns how many records went.
  Future<int> deleteRider(String riderRef) async => ((await _send('DELETE',
          'v1/riders/${Uri.encodeComponent(riderRef)}'))['deleted'] as num)
      .toInt();

  Future<LiveShare> startLive({
    required String riderRef,
    required double lat,
    required double lng,
    double speedMs = 0,
    int? batteryPct,
  }) async =>
      LiveShare.fromJson(await _send('POST', 'v1/live', {
        'riderRef': riderRef,
        'lat': lat,
        'lng': lng,
        'speedMs': speedMs,
        'batteryPct': batteryPct,
      }));

  /// Use [LiveShareThrottle] to decide when to call this.
  Future<void> updateLive(
    String token, {
    required double lat,
    required double lng,
    double speedMs = 0,
    int? batteryPct,
    bool paused = false,
  }) =>
      _send('POST', 'v1/live/$token', {
        'lat': lat,
        'lng': lng,
        'speedMs': speedMs,
        'batteryPct': batteryPct,
        'status': paused ? 'paused' : 'riding',
      });

  Future<void> endLive(String token) => _send('DELETE', 'v1/live/$token');

  /// Tells Maya ops (their webhook) and turns the live link red. Pass
  /// [liveToken] so the alert carries the link.
  Future<AlertResult> sendAlert({
    required String riderRef,
    required AlertKind kind,
    double? lat,
    double? lng,
    String? liveToken,
    String? rideId,
  }) async =>
      AlertResult.fromJson(await _send('POST', 'v1/alerts', {
        'riderRef': riderRef,
        'kind': kind.name,
        'lat': lat,
        'lng': lng,
        'liveToken': liveToken,
        'rideId': rideId,
      }));

  void close() => _http.close();

  Future<Map<String, Object?>> _send(String method, String path,
      [Map<String, Object?>? body]) async {
    final req =
        await _http.openUrl(method, _base.resolve(path)).timeout(timeout);
    req.headers.set('x-api-key', _apiKey);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close().timeout(timeout);
    final text = await res.transform(utf8.decoder).join().timeout(timeout);
    Object? json;
    try {
      json = text.isEmpty ? const <String, Object?>{} : jsonDecode(text);
    } on FormatException {
      json = null;
    }
    if (res.statusCode >= 400) {
      final msg = json is Map && json['error'] is String
          ? json['error'] as String
          : text;
      throw ApiException(res.statusCode, msg);
    }
    if (json is! Map<String, Object?>) {
      throw ApiException(res.statusCode, 'unexpected response: $text');
    }
    return json;
  }
}

/// When to send a live-share update: on a new link, a pause/resume, 100 m
/// of movement or 15 s, whichever comes first (ThrottleIQ's live-share
/// gate). Keeps a moving rider fresh and a waiting one cheap.
class LiveShareThrottle {
  LiveShareThrottle(
      {this.minDistanceM = 100,
      this.maxInterval = const Duration(seconds: 15)});

  final double minDistanceM;
  final Duration maxInterval;
  DateTime? _at;
  double? _lat, _lng;
  bool? _paused;

  bool shouldSend(DateTime now, double lat, double lng, {bool paused = false}) {
    final send = _at == null ||
        paused != _paused ||
        now.difference(_at!) >= maxInterval ||
        _distanceM(_lat!, _lng!, lat, lng) >= minDistanceM;
    if (send) {
      _at = now;
      _lat = lat;
      _lng = lng;
      _paused = paused;
    }
    return send;
  }

  static double _distanceM(double lat1, double lng1, double lat2, double lng2) {
    // Equirectangular: exact enough for a 100 m threshold.
    const r = 6371000.0;
    final x = (lng2 - lng1) *
        math.pi /
        180 *
        math.cos((lat1 + lat2) / 2 * math.pi / 180);
    final y = (lat2 - lat1) * math.pi / 180;
    return r * math.sqrt(x * x + y * y);
  }
}
