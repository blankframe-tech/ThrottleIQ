import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/shared/screens/image_crop_screen.dart';

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawPaint(ui.Paint());
  return recorder.endRecording().toImage(4, 4);
}

/// issues §101.C9: an image decoded after the cropper was popped was never
/// freed.
void main() {
  test('a decode that lands after the screen is gone is disposed', () async {
    final image = await _image();
    expect(ImageCropScreen.adoptOrDispose(image, mounted: false), isNull);
    expect(image.debugDisposed, isTrue);
  });

  test('a decode while still mounted is kept', () async {
    final image = await _image();
    expect(ImageCropScreen.adoptOrDispose(image, mounted: true), same(image));
    expect(image.debugDisposed, isFalse);
    image.dispose();
  });
}
