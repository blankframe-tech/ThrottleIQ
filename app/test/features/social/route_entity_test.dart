import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/social/domain/entities/route_entity.dart';

void main() {
  group('RouteEntity', () {
    final polyline = [
      LatLng(40.7128, -74.0060),
      LatLng(40.7200, -74.0100),
      LatLng(40.7300, -74.0150),
    ];

    final route = RouteEntity(
      id: 'route1',
      userId: 'user1',
      name: 'Central Park Loop',
      description: 'Scenic ride through Central Park',
      distanceKm: 12.5,
      polyline: polyline,
      timesRidden: 3,
      createdAt: DateTime(2024, 1, 1),
      isPublic: false,
    );

    test('creates route with all fields', () {
      expect(route.id, 'route1');
      expect(route.name, 'Central Park Loop');
      expect(route.distanceKm, 12.5);
      expect(route.timesRidden, 3);
      expect(route.polyline.length, 3);
    });

    test('copyWith updates times ridden', () {
      final updated = route.copyWith(timesRidden: 5);
      expect(updated.timesRidden, 5);
      expect(updated.name, route.name);
    });

    test('copyWith makes route public', () {
      final publicRoute = route.copyWith(isPublic: true);
      expect(publicRoute.isPublic, true);
      expect(publicRoute.timesRidden, route.timesRidden);
    });

    test('copyWith shares route with users', () {
      final sharedRoute = route.copyWith(
        sharedWithUserIds: ['user2', 'user3'],
      );

      expect(sharedRoute.sharedWithUserIds.length, 2);
      expect(sharedRoute.sharedWithUserIds, contains('user2'));
    });

    test('props for equality', () {
      expect(route.props, contains(route.id));
      expect(route.props, contains(route.userId));
      expect(route.props, contains(route.createdAt));
    });

    test('route can be private', () {
      expect(route.isPublic, false);
      expect(route.sharedWithUserIds.isEmpty, true);
    });

    test('route can have optional description', () {
      final noDesc = RouteEntity(
        id: 'route2',
        userId: 'user2',
        name: 'Route without description',
        distanceKm: 5.0,
        polyline: polyline,
        createdAt: DateTime.now(),
      );

      expect(noDesc.description, null);
    });

    test('route can have map snapshot', () {
      final withSnapshot = RouteEntity(
        id: 'route3',
        userId: 'user3',
        name: 'Route with snapshot',
        distanceKm: 8.0,
        polyline: polyline,
        mapSnapshotUrl: 'http://example.com/map.png',
        createdAt: DateTime.now(),
      );

      expect(withSnapshot.mapSnapshotUrl, isNotNull);
    });
  });
}
