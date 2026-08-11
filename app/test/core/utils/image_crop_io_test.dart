import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:throttleiq/core/utils/image_crop_io.dart';

/// The cropper's pixel pipeline: decode → bake orientation → rotate → crop →
/// encode → write.
///
/// Tested here rather than through `ImageCropScreen` on purpose. `flutter_test`
/// runs widget code inside a fake-async zone where real file reads and image
/// decodes never complete, so driving this through the screen hangs rather
/// than fails — which is exactly why the I/O lives in its own file with an
/// injectable output directory. `crop_geometry_test.dart` covers the maths
/// that decides *what* to cut; this covers whether the right pixels actually
/// come out.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crop_io_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A source with four distinctly coloured quadrants, so a crop can be
  /// checked by *what it contains*, not merely by its dimensions. A crop that
  /// is the right size but taken from the wrong corner is the bug worth
  /// catching, and size assertions alone sail straight past it.
  Future<String> writeQuadrantSource({int width = 400, int height = 200}) async {
    final image = img.Image(width: width, height: height);
    final colours = [
      img.ColorRgb8(255, 0, 0), // top-left     red
      img.ColorRgb8(0, 255, 0), // top-right    green
      img.ColorRgb8(0, 0, 255), // bottom-left  blue
      img.ColorRgb8(255, 255, 0), // bottom-right yellow
    ];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final q = (y < height / 2 ? 0 : 2) + (x < width / 2 ? 0 : 1);
        image.setPixel(x, y, colours[q]);
      }
    }
    final path = '${tempDir.path}/source.png';
    await File(path).writeAsBytes(img.encodePng(image));
    return path;
  }

  /// Dominant channel of the pixel at the centre of [image].
  String centreColour(img.Image image) {
    final p = image.getPixel(image.width ~/ 2, image.height ~/ 2);
    final r = p.r, g = p.g, b = p.b;
    if (r > 200 && g > 200) return 'yellow';
    if (r > 200) return 'red';
    if (g > 200) return 'green';
    if (b > 200) return 'blue';
    return 'other';
  }

  img.Image read(String path) => img.decodeImage(File(path).readAsBytesSync())!;

  test('writes a new file and never touches the original', () async {
    final source = await writeQuadrantSource();
    final before = File(source).readAsBytesSync();

    final out = await writeCroppedImage(
      sourcePath: source,
      cropInDisplaySpace: const Rect.fromLTWH(0, 0, 200, 100),
      displayRect: const Rect.fromLTWH(0, 0, 200, 100),
      outputDirectory: tempDir,
    );

    expect(out, isNot(source));
    expect(File(out).existsSync(), isTrue);
    expect(File(source).readAsBytesSync(), before);
  });

  test('a full-frame crop preserves the source aspect ratio', () async {
    final source = await writeQuadrantSource();
    final out = await writeCroppedImage(
      sourcePath: source,
      cropInDisplaySpace: const Rect.fromLTWH(0, 0, 200, 100),
      displayRect: const Rect.fromLTWH(0, 0, 200, 100),
      outputDirectory: tempDir,
    );

    final image = read(out);
    expect(image.width, 400);
    expect(image.height, 200);
  });

  test('cuts the region the frame was actually over', () async {
    // Top-right quadrant in display space → must come back green.
    final source = await writeQuadrantSource();
    final out = await writeCroppedImage(
      sourcePath: source,
      cropInDisplaySpace: const Rect.fromLTWH(100, 0, 100, 50),
      displayRect: const Rect.fromLTWH(0, 0, 200, 100),
      outputDirectory: tempDir,
    );

    final image = read(out);
    expect(image.width, 200);
    expect(image.height, 100);
    expect(centreColour(image), 'green');
  });

  test('subtracts the letterbox offset when the photo is inset', () async {
    // Same top-right quadrant, but the photo is drawn inset in the viewport.
    // Ignoring display.left/top here would silently cut a different region.
    final source = await writeQuadrantSource();
    final out = await writeCroppedImage(
      sourcePath: source,
      cropInDisplaySpace: const Rect.fromLTWH(130, 40, 100, 50),
      displayRect: const Rect.fromLTWH(30, 40, 200, 100),
      outputDirectory: tempDir,
    );

    expect(centreColour(read(out)), 'green');
  });

  test('a square crop of a 2:1 photo really is square', () async {
    final source = await writeQuadrantSource();
    final out = await writeCroppedImage(
      sourcePath: source,
      cropInDisplaySpace: const Rect.fromLTWH(50, 0, 100, 100),
      displayRect: const Rect.fromLTWH(0, 0, 200, 100),
      outputDirectory: tempDir,
    );

    final image = read(out);
    expect(image.width, image.height);
    expect(image.width, lessThan(400));
  });

  test('a quarter turn swaps the output dimensions', () async {
    final source = await writeQuadrantSource();
    // After one turn the 400×200 photo is 200×400, so the display rect the
    // screen computes is portrait too.
    final out = await writeCroppedImage(
      sourcePath: source,
      cropInDisplaySpace: const Rect.fromLTWH(0, 0, 100, 200),
      displayRect: const Rect.fromLTWH(0, 0, 100, 200),
      quarterTurns: 1,
      outputDirectory: tempDir,
    );

    final image = read(out);
    expect(image.width, 200);
    expect(image.height, 400);
  });

  test('a crop reaching past the edge is clamped, not an error', () async {
    final source = await writeQuadrantSource();
    final out = await writeCroppedImage(
      sourcePath: source,
      cropInDisplaySpace: const Rect.fromLTWH(-100, -100, 1000, 1000),
      displayRect: const Rect.fromLTWH(0, 0, 200, 100),
      outputDirectory: tempDir,
    );

    final image = read(out);
    expect(image.width, lessThanOrEqualTo(400));
    expect(image.height, lessThanOrEqualTo(200));
    expect(image.width, greaterThan(0));
  });

  test('a degenerate frame still yields a decodable image', () async {
    // copyCrop with a zero width/height is a decode error, not a tiny picture.
    final source = await writeQuadrantSource();
    final out = await writeCroppedImage(
      sourcePath: source,
      cropInDisplaySpace: const Rect.fromLTWH(50, 50, 0, 0),
      displayRect: const Rect.fromLTWH(0, 0, 200, 100),
      outputDirectory: tempDir,
    );

    final image = read(out);
    expect(image.width, greaterThan(0));
    expect(image.height, greaterThan(0));
  });

  test('an undecodable file throws rather than writing garbage', () async {
    final path = '${tempDir.path}/not-an-image.jpg';
    await File(path).writeAsString('this is not a JPEG');

    expect(
      () => writeCroppedImage(
        sourcePath: path,
        cropInDisplaySpace: const Rect.fromLTWH(0, 0, 10, 10),
        displayRect: const Rect.fromLTWH(0, 0, 10, 10),
        outputDirectory: tempDir,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('the filename prefix reaches the written file', () async {
    final source = await writeQuadrantSource();
    final out = await writeCroppedImage(
      sourcePath: source,
      cropInDisplaySpace: const Rect.fromLTWH(0, 0, 200, 100),
      displayRect: const Rect.fromLTWH(0, 0, 200, 100),
      outputDirectory: tempDir,
      filePrefix: 'bike_photo',
    );

    expect(out.split('/').last, startsWith('bike_photo_'));
    expect(out, endsWith('.jpg'));
  });
}
