import 'dart:io';

import 'package:test/test.dart';

/// lib/src/vendor must stay byte-identical to the ThrottleIQ app's files.
/// Skipped outside the ThrottleIQ repo (e.g. in Maya's copy of this folder).
void main() {
  final app = Directory('../app/lib');
  final vendor = Directory('lib/src/vendor');
  final files = vendor
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('vendored files match app/lib', () {
    expect(files, isNotEmpty);
    for (final f in files) {
      final rel = f.path.substring(vendor.path.length + 1);
      final original = File('${app.path}/$rel');
      expect(original.existsSync(), isTrue,
          reason: '$rel no longer exists in app/lib');
      expect(f.readAsStringSync(), original.readAsStringSync(),
          reason: '$rel differs from app/lib; copy it again');
    }
  }, skip: app.existsSync() ? false : 'not inside the ThrottleIQ repo');
}
