import 'dart:io';

import 'package:dio/dio.dart';

/// Uploads images to Cloudinary via an unsigned upload preset.
///
/// Stands in for Firebase Storage, which as of Feb 2026 requires the project
/// to be on the Blaze billing plan (a payment method on file) even to stay
/// within the free usage tier — not available for this project. Cloudinary's
/// free plan needs no card and comfortably covers avatar/ride-photo volume
/// at beta-tester scale (~25GB/month across storage + bandwidth).
///
/// The preset (`throttleiq_unsigned`) is configured in the Cloudinary
/// console under Settings > Upload > Upload presets, signing mode
/// "Unsigned". Nothing secret is embedded here — unsigned presets are
/// designed to be called directly from client apps; only the cloud name and
/// preset name are needed, no API key/secret.
///
/// Deliberately does not try to force a fixed `public_id`/overwrite — that
/// requires extra preset configuration unsigned uploads restrict by design.
/// Instead each upload gets Cloudinary's auto-generated unique URL, which the
/// caller stores as the new `photoUrl` in Firestore; the previous image is
/// simply orphaned (harmless at this scale, well within the free tier).
class CloudinaryUploadService {
  final Dio _dio;
  CloudinaryUploadService({Dio? dio}) : _dio = dio ?? Dio();

  static const _cloudName = 'vjvcigkt';
  static const _uploadPreset = 'throttleiq_unsigned';
  static const _endpoint =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Uploads [file] under the given [folder] (organizational only, e.g.
  /// `avatars` or `rideShares/$uid`) and returns its public `secure_url`.
  Future<String> upload(File file, {required String folder}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'upload_preset': _uploadPreset,
      'folder': folder,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      data: formData,
    );
    final url = response.data?['secure_url'] as String?;
    if (url == null) {
      throw StateError('Cloudinary upload succeeded but returned no secure_url.');
    }
    return url;
  }
}
