@Timeout(Duration(seconds: 30))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/export_service.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/gpx_ride_importer.dart';

/// A 10-minute ride at ~36 km/h, one fix every 2 s, heading north.
List<Map<String, dynamic>> _points() {
  final start = DateTime.utc(2026, 3, 1, 8);
  return [
    for (var i = 0; i < 300; i++)
      {
        'lat': 23.8 + i * 0.00018, // ~20 m per fix
        'lng': 90.4,
        'timestamp': start.add(Duration(seconds: i * 2)).toIso8601String(),
        'altitude_m': 10.0 + (i % 50),
      },
  ];
}

String _exported() => ExportService().generateGPX(
    {'id': 'r', 'startTime': '2026-03-01T08:00:00Z', 'distanceM': 6000},
    _points());

Matcher _fails(GpxImportError reason) => throwsA(
    isA<GpxImportException>().having((e) => e.reason, 'reason', reason));

void main() {
  group('parseGpx', () {
    test('round-trips the exporter', () {
      final fixes = parseGpx(_exported());
      final pts = _points();
      expect(fixes, hasLength(pts.length));
      for (var i = 0; i < pts.length; i++) {
        expect(fixes[i].lat, closeTo(pts[i]['lat'] as double, 1e-9));
        expect(fixes[i].lng, 90.4);
        expect(fixes[i].timestamp.toUtc(),
            DateTime.parse(pts[i]['timestamp'] as String));
        expect(fixes[i].altitudeM, pts[i]['altitude_m']);
      }
    });

    test('reads other apps\' attribute order, quotes and self-closing tags',
        () {
      const gpx = '''<?xml version="1.0"?><gpx>
<trk><trkseg>
<trkpt lon='90.1' lat='23.1'><time>2026-01-01T00:00:10Z</time></trkpt>
<trkpt lat="23.0" lon="90.0"><ele>5</ele><time>2026-01-01T00:00:00Z</time><extensions><hr>90</hr></extensions></trkpt>
<trkpt lat="23.2" lon="90.2"/>
</trkseg></trk></gpx>''';
      final fixes = parseGpx(gpx);
      expect(fixes, hasLength(2), reason: 'the untimed point is skipped');
      expect(fixes.first.lat, 23.0, reason: 'sorted by time');
      expect(fixes.first.altitudeM, 5);
      expect(fixes.last.lng, 90.1);
    });

    test('empty and non-GPX files are rejected', () {
      expect(() => parseGpx(''), _fails(GpxImportError.notGpx));
      expect(() => parseGpx('{"ride": 1}'), _fails(GpxImportError.notGpx));
      expect(() => parseGpx('<gpx></gpx>'), _fails(GpxImportError.noTrack));
    });

    test('malformed points are skipped, not trusted', () {
      const gpx = '''<gpx><trk><trkseg>
<trkpt lat="91" lon="90"><time>2026-01-01T00:00:00Z</time></trkpt>
<trkpt lat="NaN" lon="90"><time>2026-01-01T00:00:01Z</time></trkpt>
<trkpt lat="23" lon="abc"><time>2026-01-01T00:00:02Z</time></trkpt>
<trkpt lat="23" lon="90"><time>not a time</time></trkpt>
<trkpt lat="23" lon="90"><time>2026-01-01T00:00:03Z</time>
''';
      expect(() => parseGpx(gpx), _fails(GpxImportError.noTrack));
    });

    test('oversized input is rejected before parsing', () {
      final big = '<gpx>${' ' * (kMaxGpxBytes + 1)}</gpx>';
      expect(() => parseGpx(big), _fails(GpxImportError.tooLarge));
    });

    test('too many points is rejected', () {
      const pt = '<trkpt lat="1" lon="1"><time>2026-01-01T00:00:00Z</time>'
          '</trkpt>';
      final gpx = '<gpx>${pt * (kMaxGpxPoints + 1)}</gpx>';
      expect(() => parseGpx(gpx), _fails(GpxImportError.tooLarge));
    });

    test('many unclosed tags finish quickly', () {
      final gpx = '<gpx>${'<trkpt lat="1" lon="1">' * 20000}</gpx>';
      final sw = Stopwatch()..start();
      expect(() => parseGpx(gpx), _fails(GpxImportError.noTrack));
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });

  group('GpxRideImporter', () {
    sqfliteFfiInit();
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
      await db.insert('bikes', {
        'id': 'b1',
        'user_id': 'u1',
        'brand': 'Bajaj',
        'model': 'Pulsar',
        'is_active': 1,
        'total_distance_m': 1000.0,
        'ride_count': 1,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      });
    });

    tearDown(() async {
      DatabaseHelper.overrideDatabaseForTesting(null);
      await db.close();
    });

    test('saves a completed ride with points and credits the bike', () async {
      final saved = await GpxRideImporter()
          .importGpx(userId: 'u1', bikeId: 'b1', gpx: _exported());
      final id = saved.id;

      final ride = (await db.query('rides')).single;
      expect(ride['id'], id);
      expect(ride['bike_id'], 'b1');
      expect(ride['status'], 'completed');
      expect(ride['is_auto'], 0);
      expect(ride['duration_s'], 598);
      // ~20 m x 299 intervals.
      expect(ride['distance_m'] as double, closeTo(6000, 300));
      expect(ride['max_speed_ms'] as double, greaterThan(5));
      expect(
          await db.query('ride_points', where: 'ride_id = ?', whereArgs: [id]),
          isNotEmpty);

      // Credited like a recorded ride, so a later delete (§103.2) takes
      // back exactly what was added.
      final bike = (await db.query('bikes')).single;
      expect(bike['total_distance_m'], 1000.0 + (ride['distance_m'] as double));
      expect(bike['ride_count'], 2);
      expect(saved.distanceM, ride['distance_m']);
    });

    test('deleting an imported ride gives the bike back what it got', () async {
      final saved = await GpxRideImporter()
          .importGpx(userId: 'u1', bikeId: 'b1', gpx: _exported());
      await RideDao().deleteWithTombstone(saved.id, userId: 'u1');
      final bike = (await db.query('bikes')).single;
      expect(bike['total_distance_m'], closeTo(1000.0, 1e-6));
      expect(bike['ride_count'], 1);
    });

    test('importing the same file twice is refused', () async {
      final importer = GpxRideImporter();
      await importer.importGpx(userId: 'u1', bikeId: 'b1', gpx: _exported());
      await expectLater(
          importer.importGpx(userId: 'u1', bikeId: 'b1', gpx: _exported()),
          _fails(GpxImportError.overlapsRide));
      expect(await db.query('rides'), hasLength(1));
    });
  });
}
