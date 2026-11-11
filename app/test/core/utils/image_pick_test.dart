import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/image_pick.dart';

void main() {
  test('a second tap while the picker is open picks nothing', () async {
    expect(
      await ignoreActivePicker<String?>(
          Future.error(PlatformException(code: 'already_active'))),
      isNull,
    );
  });

  test('passes results and other picker errors through', () async {
    expect(await ignoreActivePicker(Future.value('a.jpg')), 'a.jpg');
    await expectLater(
      ignoreActivePicker<String?>(
          Future.error(PlatformException(code: 'camera_access_denied'))),
      throwsA(isA<PlatformException>()),
    );
  });
}
