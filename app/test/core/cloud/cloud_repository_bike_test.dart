import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';

void main() {
  group('CloudRepository.sanitizeDownloadedBikeData', () {
    test('preserves remote Cloudinary and https URLs', () {
      final input = {
        'id': 'bike-123',
        'name': 'MT-09',
        'image_path': 'https://res.cloudinary.com/test/image/upload/v123/bikes/u1/photo.jpg',
        'syncedAt': '2026-08-01T12:00:00Z',
        'is_active': 0,
      };

      final sanitized = CloudRepository.sanitizeDownloadedBikeData(
        input,
        hasLocalActive: false,
        pulledAnyActive: false,
      );

      expect(sanitized['image_path'], 'https://res.cloudinary.com/test/image/upload/v123/bikes/u1/photo.jpg');
      expect(sanitized['synced'], 1);
      expect(sanitized.containsKey('syncedAt'), isFalse);
    });

    test('nulls out local file paths from another device', () {
      final input = {
        'id': 'bike-456',
        'name': 'R3',
        'image_path': '/var/mobile/Containers/Data/Application/AAA-BBB/Documents/bike.jpg',
        'syncedAt': '2026-08-01T12:00:00Z',
        'is_active': 1,
      };

      final sanitized = CloudRepository.sanitizeDownloadedBikeData(
        input,
        hasLocalActive: false,
        pulledAnyActive: false,
      );

      expect(sanitized['image_path'], isNull);
      expect(sanitized['synced'], 1);
    });

    test('handles null or empty image_path gracefully', () {
      final input = {
        'id': 'bike-789',
        'name': 'CB500',
        'image_path': null,
      };

      final sanitized = CloudRepository.sanitizeDownloadedBikeData(
        input,
        hasLocalActive: false,
        pulledAnyActive: false,
      );

      expect(sanitized['image_path'], isNull);
    });

    test('resolves is_active correctly based on local active status', () {
      final input = {
        'id': 'bike-active',
        'name': 'Active Bike',
        'is_active': 1,
      };

      // 1. No local active and no previously pulled active -> becomes active
      final res1 = CloudRepository.sanitizeDownloadedBikeData(
        input,
        hasLocalActive: false,
        pulledAnyActive: false,
      );
      expect(res1['is_active'], 1);

      // 2. Already has a local active bike -> becomes inactive
      final res2 = CloudRepository.sanitizeDownloadedBikeData(
        input,
        hasLocalActive: true,
        pulledAnyActive: false,
      );
      expect(res2['is_active'], 0);

      // 3. Already pulled another active bike in this cycle -> becomes inactive
      final res3 = CloudRepository.sanitizeDownloadedBikeData(
        input,
        hasLocalActive: false,
        pulledAnyActive: true,
      );
      expect(res3['is_active'], 0);
    });
  });
}
