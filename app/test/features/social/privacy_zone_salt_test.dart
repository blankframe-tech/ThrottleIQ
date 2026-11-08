import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/social/domain/utilities/privacy_zone_salt.dart';

void main() {
  const home = LatLng(23.81012, 90.41187);
  const work = LatLng(23.75, 90.39); // ~7 km away

  group('per-place seeds', () {
    test('seedForAnchor matches the reclip script (same test vector)', () {
      // scripts/test/reclip_shared_routes.test.js asserts the same number.
      expect(
          PrivacyZoneSalt.seedForAnchor(123456789, const LatLng(23.81, 90.412)),
          1527016232);
    });

    test('the same place reuses its anchor; a new place gets its own', () {
      final anchors = <LatLng>[];
      final (s1, w1) = PrivacyZoneSalt.seedsWith(7, anchors, home, work);
      expect(
          anchors, [const LatLng(23.81, 90.412), const LatLng(23.75, 90.39)]);
      // 300 m from home: same anchor, same seed, nothing added.
      const nearHome = LatLng(23.8128, 90.4119);
      final (s2, w2) = PrivacyZoneSalt.seedsWith(7, anchors, nearHome, work);
      expect((s2, w2), (s1, w1));
      expect(anchors, hasLength(2));
      expect(s1, isNot(w1));
      // Another salt gives other seeds for the same places.
      final (s3, _) = PrivacyZoneSalt.seedsWith(8, [...anchors], home, work);
      expect(s3, isNot(s1));
    });

    test('the nearest anchor wins when two are within reach', () {
      final anchors = [const LatLng(23.80, 90.40), const LatLng(23.807, 90.40)];
      // ~1.0 km from the first, ~220 m from the second.
      expect(
          PrivacyZoneSalt.nearestAnchor(anchors, const LatLng(23.809, 90.40)),
          anchors[1]);
      expect(PrivacyZoneSalt.nearestAnchor(anchors, const LatLng(23.83, 90.40)),
          isNull);
    });

    test('malformed stored anchors are dropped', () {
      expect(
          PrivacyZoneSalt.readAnchors([
            {'lat': 1, 'lng': 2.5},
            {'lat': 'x', 'lng': 2},
            'junk',
          ]),
          [const LatLng(1, 2.5)]);
      expect(PrivacyZoneSalt.readAnchors(null), isEmpty);
    });
  });

  group('seedsFor', () {
    final ride = [home, const LatLng(23.82, 90.42), work];

    test('creates the salt and anchors once, then reuses them', () async {
      final fs = FakeFirebaseFirestore();
      final svc = PrivacyZoneSalt(firestore: fs);
      final first = await svc.seedsFor('u1', ride);
      final doc = await fs.doc('users/u1/private/privacy').get();
      final salt = doc.get('zoneSalt') as int;
      expect(doc.get('anchors'), hasLength(2));
      expect(first, PrivacyZoneSalt.seedsWith(salt, [], ride.first, ride.last));

      // A fresh instance (another session) reads the same doc back.
      final again = await PrivacyZoneSalt(firestore: fs).seedsFor('u1', ride);
      expect(again, first);
      final after = await fs.doc('users/u1/private/privacy').get();
      expect(after.get('anchors'), hasLength(2));
      expect(after.get('zoneSalt'), salt);
    });

    test('a short polyline touches nothing', () async {
      final fs = FakeFirebaseFirestore();
      expect(await PrivacyZoneSalt(firestore: fs).seedsFor('u1', [home, work]),
          (0, 0));
      expect((await fs.doc('users/u1/private/privacy').get()).exists, isFalse);
    });
  });
}
