import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:throttleiq/core/utils/bike_image_resolver.dart';

void main() {
  group('BikeImageResolver', () {
    late Directory tempDir;
    late Directory oldSandboxDir;
    late Directory newSandboxDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bike_resolver_test');
      oldSandboxDir = Directory(p.join(tempDir.path, 'old_sandbox', 'Documents'));
      newSandboxDir = Directory(p.join(tempDir.path, 'new_sandbox', 'Documents'));
      await oldSandboxDir.create(recursive: true);
      await newSandboxDir.create(recursive: true);
    });

    tearDown(() async {
      BikeImageResolver.cachedDocumentsDirectoryPath = null;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('isRemoteUrl correctly identifies remote URLs', () {
      expect(BikeImageResolver.isRemoteUrl('https://res.cloudinary.com/demo/image/upload/sample.jpg'), isTrue);
      expect(BikeImageResolver.isRemoteUrl('http://example.com/bike.jpg'), isTrue);
      expect(BikeImageResolver.isRemoteUrl('/var/mobile/Containers/Data/Application/123/Documents/bike.jpg'), isFalse);
      expect(BikeImageResolver.isRemoteUrl('bike_12345.jpg'), isFalse);
      expect(BikeImageResolver.isRemoteUrl(''), isFalse);
      expect(BikeImageResolver.isRemoteUrl(null), isFalse);
    });

    test('resolvePathSync returns null for null or empty path', () {
      expect(BikeImageResolver.resolvePathSync(null), isNull);
      expect(BikeImageResolver.resolvePathSync(''), isNull);
    });

    test('resolvePathSync returns remote URL untouched', () {
      const url = 'https://res.cloudinary.com/demo/image/upload/sample.jpg';
      expect(BikeImageResolver.resolvePathSync(url), equals(url));
    });

    test('resolvePathSync returns existing local file path directly', () {
      final file = File(p.join(newSandboxDir.path, 'bike_existing.jpg'))..writeAsStringSync('dummy');
      expect(BikeImageResolver.resolvePathSync(file.path), equals(file.path));
    });

    test('resolvePathSync heals stale sandbox container UUID across app rebuilds', () {
      // Simulating an iOS app rebuild:
      // The file was originally recorded at oldSandboxDir, but after rebuild
      // it now lives in newSandboxDir with the exact same filename.
      const filename = 'bike_1725800000.jpg';
      final staleOldPath = p.join(oldSandboxDir.path, filename);
      final currentFile = File(p.join(newSandboxDir.path, filename))..writeAsStringSync('image_data');

      // The old path does NOT exist:
      expect(File(staleOldPath).existsSync(), isFalse);

      // Resolving with newSandboxDir as documents directory resolves to the live file!
      final resolved = BikeImageResolver.resolvePathSync(
        staleOldPath,
        documentsDirectory: newSandboxDir,
      );

      expect(resolved, equals(currentFile.path));
      expect(File(resolved!).existsSync(), isTrue);
    });

    test('resolvePathSync heals stale path using cachedDocumentsDirectoryPath', () {
      const filename = 'bike_cached.jpg';
      final staleOldPath = p.join(oldSandboxDir.path, filename);
      final currentFile = File(p.join(newSandboxDir.path, filename))..writeAsStringSync('image_data');

      BikeImageResolver.cachedDocumentsDirectoryPath = newSandboxDir.path;

      final resolved = BikeImageResolver.resolvePathSync(staleOldPath);
      expect(resolved, equals(currentFile.path));
    });

    test('resolvePathSync returns null when file does not exist anywhere', () {
      final missingPath = p.join(oldSandboxDir.path, 'does_not_exist.jpg');
      final resolved = BikeImageResolver.resolvePathSync(
        missingPath,
        documentsDirectory: newSandboxDir,
      );
      expect(resolved, isNull);
    });

    test('resolvePath async resolves properly', () async {
      const filename = 'bike_async.jpg';
      final staleOldPath = p.join(oldSandboxDir.path, filename);
      final currentFile = File(p.join(newSandboxDir.path, filename))..writeAsStringSync('image_data');

      final resolved = await BikeImageResolver.resolvePath(
        staleOldPath,
        documentsDirectory: newSandboxDir,
      );

      expect(resolved, equals(currentFile.path));
    });
  });
}
