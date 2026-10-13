import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:throttleiq/core/constants/bike_colors.dart';
import 'package:throttleiq/core/utils/bike_image_resolver.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';

void main() {
  group('bikeHasPhoto', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bike_colors_test');
      BikeImageResolver.cachedDocumentsDirectoryPath = tempDir.path;
    });

    tearDown(() async {
      BikeImageResolver.cachedDocumentsDirectoryPath = null;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    BikeEntity createBike(String? imagePath) {
      return BikeEntity(
        id: 'test_bike',
        userId: 'test_user',
        brand: 'Yamaha',
        model: 'R15',
        imagePath: imagePath,
        createdAt: DateTime.now(),
      );
    }

    test('returns false when imagePath is null or empty', () {
      expect(bikeHasPhoto(createBike(null)), isFalse);
      expect(bikeHasPhoto(createBike('')), isFalse);
    });

    test('returns true when imagePath is a remote URL', () {
      expect(bikeHasPhoto(createBike('https://res.cloudinary.com/demo/image.jpg')), isTrue);
      expect(bikeHasPhoto(createBike('http://example.com/bike.png')), isTrue);
    });

    test('returns true when imagePath is an existing local file', () {
      final file = File(p.join(tempDir.path, 'bike.jpg'))..writeAsStringSync('dummy');
      expect(bikeHasPhoto(createBike(file.path)), isTrue);
    });

    test('returns true when imagePath had old container UUID but exists in documents dir', () {
      File(p.join(tempDir.path, 'bike_healed.jpg')).writeAsStringSync('dummy');
      const stalePath = '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/bike_healed.jpg';
      expect(bikeHasPhoto(createBike(stalePath)), isTrue);
    });

    test('returns false when local file does not exist', () {
      const missingPath = '/non/existent/path/to/bike.jpg';
      expect(bikeHasPhoto(createBike(missingPath)), isFalse);
    });
  });
}
