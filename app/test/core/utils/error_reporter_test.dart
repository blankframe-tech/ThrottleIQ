// Why the ratchet exists (§83.14, §90.B6): a bare `catch (_)` swallows an
// error that then never reaches Crashlytics, so it shows up only as "it just
// didn't work". The count in `lib/` may only go down. When you remove some,
// lower [_bareCatchBaseline] to the new count. For a catch that must swallow,
// use `catch (e, st)` with `reportSilently` (core/utils/error_reporter.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/error_reporter.dart';

const _bareCatchBaseline = 54;

void main() {
  test('bare catch (_) count in lib/ does not grow past the baseline', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('catch (_)')) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(
      hits.length,
      lessThanOrEqualTo(_bareCatchBaseline),
      reason: 'New bare catch (_). Use catch (e, st) + reportSilently:\n'
          '${hits.join('\n')}',
    );
  });

  // kDebugMode is true under flutter test, so this only checks the test-time
  // no-op; the release path is reportNonFatal's own try/catch.
  test('reportSilently is a safe no-op in tests', () {
    expect(
      () => reportSilently(StateError('x'), StackTrace.current, where: 'test'),
      returnsNormally,
    );
  });
}
