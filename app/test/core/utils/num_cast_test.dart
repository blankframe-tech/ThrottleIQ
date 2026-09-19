import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/num_cast.dart';
import 'package:throttleiq/features/ride/domain/entities/live_session_entity.dart';
import 'package:throttleiq/features/social/data/models/route_model.dart';

void main() {
  group('asDouble', () {
    test('accepts ints and doubles alike', () {
      expect(asDouble(24), 24.0);
      expect(asDouble(24), isA<double>());
      expect(asDouble(23.81), 23.81);
    });

    test('throws on null or non-numbers, like the raw cast', () {
      expect(() => asDouble(null), throwsA(isA<TypeError>()));
      expect(() => asDouble('23.8'), throwsA(isA<TypeError>()));
    });
  });

  group('asDoubleOrNull', () {
    test('passes null through and widens ints', () {
      expect(asDoubleOrNull(null), isNull);
      expect(asDoubleOrNull(90), 90.0);
      expect(asDoubleOrNull(90.5), 90.5);
    });
  });

  // Whole-number coordinates come back from Firestore as `int` when anything
  // other than this app wrote them (console, JS, Cloud Functions). These
  // used to throw "int is not a subtype of double".
  test('RouteModel.fromFirestore reads integer coordinates', () {
    final model = RouteModel.fromFirestore({
      'userId': 'u1',
      'name': 'Loop',
      'polyline': [
        {'lat': 24, 'lng': 90},
        {'lat': 24.5, 'lng': 91},
      ],
      'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
    }, 'r1');
    expect(model.polyline.first.latitude, 24.0);
    expect(model.polyline.last.longitude, 91.0);
  });

  test('LiveSessionEntity.fromFirestore reads integer last position', () {
    final now = Timestamp.fromDate(DateTime.utc(2026));
    final session = LiveSessionEntity.fromFirestore({
      'token': 't',
      'uid': 'u',
      'rideId': 'r',
      'active': true,
      'lastLat': 24,
      'lastLng': 90,
      'status': 'riding',
      'startedAt': now,
      'updatedAt': now,
      'expiresAt': now,
    });
    expect(session.lastLat, 24.0);
    expect(session.lastLng, 90.0);
  });
}
