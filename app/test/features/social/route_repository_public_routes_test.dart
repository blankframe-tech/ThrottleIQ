import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/data/repositories/route_repository.dart';

void main() {
  test('getPublicRoutes: public only, most ridden first, capped at 20',
      () async {
    final fs = FakeFirebaseFirestore();
    Future<void> route(String uid, String id, int ridden, bool public) =>
        fs.doc('users/$uid/routes/$id').set({
          'userId': uid,
          'name': id,
          'timesRidden': ridden,
          'isPublic': public,
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
        });
    // 25 public routes across two riders, plus private ones that out-rank
    // them all and must never show.
    for (var i = 0; i < 25; i++) {
      await route(i.isEven ? 'a' : 'b', 'p$i', i, true);
    }
    await route('a', 'private1', 999, false);
    await route('b', 'private2', 500, false);

    final got = await RouteRepository.withFirestore(fs).getPublicRoutes();

    expect(got, hasLength(20));
    expect(got.every((r) => r.isPublic), isTrue);
    expect(got.map((r) => r.timesRidden), List.generate(20, (i) => 24 - i));
  });
}
