import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Blob;
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/impact_event_payload.dart';
import 'package:throttleiq/features/ride/data/models/impact_event_row.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_detector.dart';
import 'package:throttleiq/features/ride/domain/entities/impact_event_types.dart';

void main() {
  final candidate = ImpactCandidate(
    spikeAt: DateTime.utc(2026, 10, 14, 15, 28, 58, 900),
    tier: 1,
    reason: ImpactReason.tipOver,
    peakAccelMs2: 26.4321,
    peakRawMs2: 30.4,
    freefallMs: 180,
    rotationDeg: 140.27,
    orientationChangeDeg: 81.04,
    speedBeforeMs: 0,
    speedAfterMs: 0,
    wentStill: true,
    resumed: false,
    saturated: false,
    lastFixAgeS: 11.93,
    vibrationRmsMs2: 0.612,
  );

  Map<String, Object?> row({Map<String, Object?> extra = const {}}) => {
        ...impactEventRowFromCandidate(
          candidate: candidate,
          id: 'ev-1',
          rideId: 'ride-1',
          userId: 'u1',
          lat: 23.7808,
          lng: 90.4071,
          placement: PhonePlacement.pocket,
          appForeground: false,
          charging: false,
          sampleRateHz: 49.83,
          imu: Uint8List.fromList([1, 2, 3]),
          now: DateTime.utc(2026, 10, 14, 15, 29, 30),
        ),
        'bike_cc': 125,
        'bike_brand': 'Honda',
        'bike_model': 'CG 125',
        'bike_is_ebike': 0,
        ...extra,
      };

  group('impactEventRowFromCandidate', () {
    test('maps and rounds every measurement', () {
      final r = row();
      expect(r['at'], '2026-10-14T15:28:58.900Z');
      expect(r['tier'], 1);
      expect(r['reason'], 'tipOver');
      expect(r['peak_user_g'], 2.694);
      expect(r['peak_raw_g'], 3.099);
      expect(r['gps_gap_s'], 11.9);
      expect(r['placement_declared'], 'pocket');
      expect(r['app_foreground'], 0);
      expect(r['sample_rate_hz'], 49.8);
      expect(r['consent_research'], 0);
      final features = jsonDecode(r['features']! as String) as Map;
      expect(features['rulesVersion'], kImpactRulesVersion);
      expect(features['freefallMs'], 180);
    });
  });

  group('impactEventCloudPayload (private copy)', () {
    test('camelCase, the window as a Blob, no owner, no nulls', () {
      final p = impactEventCloudPayload(row());
      expect(p['rideId'], 'ride-1');
      expect(p['imu'], isA<Blob>());
      expect(p['stillAfter'], isTrue);
      expect(p['consent'], isFalse);
      expect(p['features'], isA<Map>());
      expect(p.containsKey('user_id'), isFalse);
      expect(p.containsKey('userId'), isFalse);
      expect(p.containsKey('label'), isFalse, reason: 'unanswered: dropped');
      expect(p.values.contains(null), isFalse);
    });
  });

  group('crashEventCloudPayload (research copy)', () {
    test('null until answered, and null without consent', () {
      expect(
        crashEventCloudPayload(
          row(),
          ownerUid: 'u1',
          platform: 'ios',
          consentVersion: 1,
        ),
        isNull,
      );
      expect(
        crashEventCloudPayload(
          row(extra: {'label': 'crash'}),
          ownerUid: 'u1',
          platform: 'ios',
          consentVersion: 1,
        ),
        isNull,
      );
    });

    test('de-identified: a 6-char geohash, no position, no free text', () {
      final p = crashEventCloudPayload(
        row(
          extra: {
            'label': 'crash',
            'consent_research': 1,
            'label_detail': jsonEncode({
              'severity': 'minor',
              'surface': 'rail_crossing',
              'note': 'should never travel',
            }),
          },
        ),
        ownerUid: 'u1',
        platform: 'ios',
        consentVersion: 1,
      )!;
      expect(p['geohash6'], hasLength(6));
      expect(p.keys, isNot(contains('lat')));
      expect(p.keys, isNot(contains('lng')));
      expect(p.keys, isNot(contains('note')));
      expect(p.keys, isNot(contains('rideId')));
      expect(p['surface'], 'rail_crossing');
      expect(p['severity'], 'minor');
      expect(p['detectedTier'], 1);
      expect(p['peakG'], 3.099);
      expect(p['bikeClass'], 'commuter');
      expect(p['rulesVersion'], kImpactRulesVersion);
      expect(p['speedBeforeKmh'], 0);
    });

    test('a reported miss has no detected tier and no peak', () {
      final p = crashEventCloudPayload(
        row(extra: {'tier': -1, 'label': 'missed', 'consent_research': 1}),
        ownerUid: 'u1',
        platform: 'android',
        consentVersion: 1,
      )!;
      expect(p.containsKey('detectedTier'), isFalse);
      expect(p.containsKey('peakG'), isFalse);
      expect(p['label'], 'missed');
    });

    test('an unknown surface or severity is dropped, not passed through', () {
      final p = crashEventCloudPayload(
        row(
          extra: {
            'label': 'fall',
            'consent_research': 1,
            'label_detail': jsonEncode({'surface': 'ice', 'severity': 'bad'}),
          },
        ),
        ownerUid: 'u1',
        platform: 'ios',
        consentVersion: 1,
      )!;
      expect(p.containsKey('surface'), isFalse);
      expect(p.containsKey('severity'), isFalse);
    });

    Object? createdAt(Object? local) => crashEventCloudPayload(
          row(
            extra: {
              'label': 'crash',
              'consent_research': 1,
              'created_at': local
            },
          ),
          ownerUid: 'u1',
          platform: 'ios',
          consentVersion: 1,
        )!['createdAt'];

    test('createdAt is floored to the UTC hour; the private copy is exact', () {
      expect(row()['created_at'], '2026-10-14T15:29:30.000Z');
      expect(createdAt('2026-10-14T15:29:30.000Z'), '2026-10-14T15:00:00.000Z');
      expect(
        impactEventCloudPayload(row())['createdAt'],
        '2026-10-14T15:29:30.000Z',
      );
    });

    test('createdAt edges: on the hour, 59:59.999, offset, unparseable', () {
      expect(createdAt('2026-10-14T15:00:00.000Z'), '2026-10-14T15:00:00.000Z');
      expect(createdAt('2026-10-14T15:59:59.999Z'), '2026-10-14T15:00:00.000Z');
      expect(createdAt('2026-12-31T23:59:59.999Z'), '2026-12-31T23:00:00.000Z');
      // +06:00 (Dhaka) is converted to UTC before flooring.
      expect(
        createdAt('2026-10-15T00:30:00.000+06:00'),
        '2026-10-14T18:00:00.000Z',
      );
      expect(createdAt('not a date'), isNull);
      expect(createdAt(null), isNull);
    });
  });

  group('bikeClassFor', () {
    test('catalogue examples', () {
      expect(
        bikeClassFor(brand: 'Honda', model: 'CG 125', cc: 125),
        'commuter',
      );
      expect(bikeClassFor(brand: 'Yamaha', model: 'R15', cc: 155), 'sport');
      expect(
        bikeClassFor(brand: 'Yamaha', model: 'Ray ZR', cc: 125),
        'scooter',
      );
      expect(
        bikeClassFor(brand: 'Hero', model: 'Xpulse 200 4v Pro'),
        'adventure',
      );
      expect(bikeClassFor(brand: 'KTM', model: 'RC 390'), 'sport');
      expect(bikeClassFor(model: 'Anything', isEbike: true), 'ebike');
      expect(bikeClassFor(model: 'Unknown big twin', cc: 650), 'sport');
      expect(bikeClassFor(), 'commuter');
    });
  });
}
