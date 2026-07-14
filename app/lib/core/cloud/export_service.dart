import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../database/daos/ride_point_dao.dart';

/// Service for exporting ride data to various formats.
///
/// Files are written to the app documents directory (Downloads is not
/// accessible via path_provider on Android); callers surface them with the
/// system share sheet (share_plus) so the user can save or send anywhere.
class ExportService {
  final RidePointDao _ridePointDao = RidePointDao();

  Future<Directory> _exportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/exports');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Export ride data to JSON file
  Future<File?> exportRideToJSON(Map<String, dynamic> ride) async {
    try {
      final directory = await _exportDir();

      final rideId = ride['id'] as String;
      final fileName = 'ride_${rideId}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      // Fetch ride points
      final points = await _ridePointDao.getForRide(rideId);

      final jsonData = {
        'ride': ride,
        'points': points,
        'exportedAt': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(jsonEncode(jsonData), flush: true);
      return file;
    } catch (e) {
      print('Error exporting to JSON: $e');
      return null;
    }
  }

  /// Export ride polyline to GPX file
  Future<File?> exportRideToGPX(Map<String, dynamic> ride) async {
    try {
      final directory = await _exportDir();

      final rideId = ride['id'] as String;
      final fileName = 'ride_${rideId}_${DateTime.now().millisecondsSinceEpoch}.gpx';
      final file = File('${directory.path}/$fileName');

      // Fetch ride points
      final points = await _ridePointDao.getForRide(rideId);

      final gpxContent = _generateGPX(ride, points);
      await file.writeAsString(gpxContent, flush: true);
      return file;
    } catch (e) {
      print('Error exporting to GPX: $e');
      return null;
    }
  }

  /// Generate GPX XML string from ride data
  String _generateGPX(Map<String, dynamic> ride, List<Map<String, dynamic>> ridePoints) {
    final startTime = ride['startTime'] as String;
    final distanceKm = (ride['distanceM'] as num) / 1000;

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<gpx version="1.1" creator="ThrottleIQ" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>Motorcycle Ride</name>');
    buffer.writeln('    <time>$startTime</time>');

    if (ridePoints.isNotEmpty) {
      final lats = ridePoints.map<double>((p) => p['lat'] as double).toList();
      final lngs = ridePoints.map<double>((p) => p['lng'] as double).toList();

      final minLat = lats.reduce((a, b) => a < b ? a : b);
      final maxLat = lats.reduce((a, b) => a > b ? a : b);
      final minLng = lngs.reduce((a, b) => a < b ? a : b);
      final maxLng = lngs.reduce((a, b) => a > b ? a : b);

      buffer.writeln('    <bounds minlat="$minLat" minlon="$minLng" maxlat="$maxLat" maxlon="$maxLng" />');
    }

    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>Motorcycle Ride</name>');
    buffer.writeln('    <desc>Distance: ${distanceKm.toStringAsFixed(2)} km</desc>');
    buffer.writeln('    <trkseg>');

    for (final point in ridePoints) {
      final lat = point['lat'] as num;
      final lng = point['lng'] as num;
      final timestamp = point['timestamp'] as String;
      // DB column is snake_case
      final elevation = point['altitude_m'] as num?;

      buffer.write('      <trkpt lat="$lat" lon="$lng">');
      if (elevation != null && elevation != 0) {
        buffer.write('<ele>${elevation.toStringAsFixed(2)}</ele>');
      }
      buffer.writeln('<time>$timestamp</time></trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// Get the export directory path for display
  Future<String?> getDownloadsPath() async {
    final directory = await _exportDir();
    return directory.path;
  }
}

/// Riverpod provider for export service
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});
