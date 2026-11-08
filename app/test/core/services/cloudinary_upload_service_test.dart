import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:throttleiq/core/services/cloudinary_upload_service.dart';

/// A 40x20 JPEG tagged with GPS 23.7N 90.4E and EXIF orientation 6 (rotate
/// 90° clockwise), the way an iPhone gallery pick arrives.
Uint8List _geotaggedJpeg() {
  final image = img.Image(width: 40, height: 20);
  img.fill(image, color: img.ColorRgb8(200, 30, 30));
  image.exif.gpsIfd
    ..gpsLatitudeRef = 'N'
    ..gpsLatitude = 23.7
    ..gpsLongitudeRef = 'E'
    ..gpsLongitude = 90.4;
  image.exif.imageIfd.orientation = 6;
  return img.encodeJpg(image);
}

/// True when [bytes] carry an EXIF APP1 segment ("Exif\0\0" header).
bool _hasExifSegment(Uint8List bytes) {
  const sig = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
  for (var i = 0; i + sig.length <= bytes.length; i++) {
    var match = true;
    for (var k = 0; k < sig.length && match; k++) {
      match = bytes[i + k] == sig[k];
    }
    if (match) return true;
  }
  return false;
}

void main() {
  test('the fixture really carries GPS EXIF', () {
    final bytes = _geotaggedJpeg();
    expect(_hasExifSegment(bytes), isTrue);
    expect(img.decodeJpgExif(bytes)!.gpsIfd.hasGPSLatitude, isTrue);
  });

  test('stripImageMetadata drops EXIF/GPS and bakes in the rotation', () {
    final out = stripImageMetadata(_geotaggedJpeg());
    expect(_hasExifSegment(out), isFalse);
    final exif = img.decodeJpgExif(out);
    expect(exif?.gpsIfd.hasGPSLatitude ?? false, isFalse);
    final decoded = img.decodeImage(out)!;
    // Orientation 6 on a 40x20 image displays as 20x40.
    expect(decoded.width, 20);
    expect(decoded.height, 40);
  });

  test('stripImageMetadata refuses bytes it cannot decode', () {
    expect(() => stripImageMetadata(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<FormatException>()));
  });

  test('upload() sends only stripped bytes to Cloudinary', () async {
    final dir = await Directory.systemTemp.createTemp('cld');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/photo.jpg')
      ..writeAsBytesSync(_geotaggedJpeg());

    final sent = <int>[];
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, h) async {
        final form = options.data as FormData;
        await for (final chunk in form.files.single.value.finalize()) {
          sent.addAll(chunk);
        }
        h.resolve(Response(
          requestOptions: options,
          data: {
            'secure_url': 'https://example.invalid/x.jpg',
            'public_id': 'x',
            'resource_type': 'image',
          },
        ));
      }));
    final service = CloudinaryUploadService(
      dio: dio,
      firestore: FakeFirebaseFirestore(),
      uid: () => null,
    );

    await service.upload(file, folder: 'avatars/u');

    expect(sent, isNotEmpty);
    final bytes = Uint8List.fromList(sent);
    expect(_hasExifSegment(bytes), isFalse);
    expect(img.decodeImage(bytes), isNotNull);
  });
}
