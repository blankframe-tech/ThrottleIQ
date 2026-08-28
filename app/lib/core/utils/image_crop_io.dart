import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'crop_geometry.dart';

/// Decoding, rotating, cropping and writing the actual pixels.
///
/// Deliberately separate from `shared/screens/image_crop_screen.dart`. The
/// screen is a gesture surface; this is file I/O and image codecs, and keeping
/// them apart is what makes this half testable at all — `flutter_test` runs
/// widget code in a fake-async zone where real file reads and image decodes
/// never complete, so a pipeline like this one buried inside a `State` method
/// can only be exercised by hand.
///
/// [outputDirectory] exists for the same reason: a test passes a temp dir, and
/// production omits it and gets the app documents directory.
Future<String> writeCroppedImage({
  required String sourcePath,
  required Rect cropInDisplaySpace,
  required Rect displayRect,
  int quarterTurns = 0,
  Directory? outputDirectory,
  String filePrefix = 'photo',
  int quality = 90,
}) async {
  final bytes = await File(sourcePath).readAsBytes();

  // docs/Issues.md §33.11: check the header-declared dimensions (cheap —
  // `startDecode` parses dimensions without decoding pixel data) before the
  // full pixel decode below, which would otherwise happily materialize a
  // multi-gigabyte bitmap for a crafted file with tiny compressed bytes but
  // a huge declared width/height (a decompression bomb).
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (decoder == null ||
      info == null ||
      info.width * info.height > 50 * 1000 * 1000) {
    throw const FormatException('Unsupported, corrupt, or oversized image');
  }
  final decoded = decoder.decode(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image');
  }

  // EXIF orientation is baked in *before* anything measures the image.
  // ImagePicker normally normalises orientation when it re-encodes, but
  // "normally" is doing a lot of work in that sentence — and a crop applied to
  // an image whose orientation tag hasn't been applied cuts the wrong region,
  // sideways, with no error.
  var source = img.bakeOrientation(decoded);
  if (quarterTurns % 4 != 0) {
    source = img.copyRotate(source, angle: (quarterTurns % 4) * 90);
  }

  final rect = toSourceRect(
    cropInDisplaySpace,
    displayRect,
    Size(source.width.toDouble(), source.height.toDouble()),
  );

  final x = rect.left.round().clamp(0, source.width - 1);
  final y = rect.top.round().clamp(0, source.height - 1);
  final cropped = img.copyCrop(
    source,
    x: x,
    y: y,
    width: rect.width.round().clamp(1, source.width - x),
    height: rect.height.round().clamp(1, source.height - y),
  );

  // The output goes somewhere durable rather than beside the ImagePicker
  // original. A bike's `imagePath` is stored in SQLite and read back for the
  // lifetime of that bike, while the pick lands in a cache directory the OS is
  // free to reclaim — which is the documented reason `BikePhoto` needs a
  // fallback for a non-null-but-stale path at all.
  final dir = outputDirectory ?? await getApplicationDocumentsDirectory();
  final file = File(
    '${dir.path}/${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(img.encodeJpg(cropped, quality: quality));
  return file.path;
}

/// Copies [sourcePath] into the same durable, app-owned location
/// [writeCroppedImage] writes to, without touching pixels — for when the
/// rider picks a photo but skips the crop step entirely rather than
/// cancelling out of it. `ImagePicker`'s own path lives in a cache directory
/// the OS is free to reclaim (and doesn't survive an app reinstall), so
/// storing it as-is in `Bike.imagePath` is the same trap [writeCroppedImage]
/// above already avoids — this exists so the "skip crop" path avoids it too.
Future<String> persistPickedImage({
  required String sourcePath,
  Directory? outputDirectory,
  String filePrefix = 'photo',
}) async {
  final dir = outputDirectory ?? await getApplicationDocumentsDirectory();
  final ext = p.extension(sourcePath);
  final file = File(
    '${dir.path}/${filePrefix}_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
  await File(sourcePath).copy(file.path);
  return file.path;
}
