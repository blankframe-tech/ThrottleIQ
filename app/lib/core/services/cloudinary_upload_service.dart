import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
/// simply orphaned.
///
/// Orphaning is fine for *storage* at this scale. It is NOT fine for
/// **deletion**: an unsigned preset cannot authorise a destroy call, so
/// nothing in the app could remove a rider's uploaded media, and "delete my
/// account" left every avatar, bike photo, ride photo, place photo and voice
/// note readable forever at its public `secure_url` (issues §83.15).
///
/// Every upload is therefore recorded in a ledger at
/// `users/{uid}/cloudinaryAssets/{docId}` — `public_id` plus the resource
/// type, which is all Cloudinary's `destroy` endpoint needs. The server-side
/// sweep that consumes it lives in `functions/src/account-deletion.ts` and is
/// gated on a `CLOUDINARY_API_SECRET` being configured; until it is, the
/// ledger still accumulates, so nothing is lost and the sweep can run
/// retroactively the first time it is deployed.
///
/// The ledger write is best-effort and never blocks or fails an upload: a
/// rider losing connectivity between the upload and the ledger write gets
/// their photo, and the ledger gets an orphan that the folder-prefix fallback
/// in the sweep still catches (every folder is `<kind>/<uid>`).
class CloudinaryUploadService {
  final Dio _dio;
  final FirebaseFirestore _firestore;

  /// Resolves the signed-in rider's uid. Injectable so the ledger write is
  /// testable without Firebase Auth.
  final String? Function() _uid;

  CloudinaryUploadService({
    Dio? dio,
    FirebaseFirestore? firestore,
    String? Function()? uid,
  })  : _dio = dio ?? Dio(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  static const _cloudName = 'vjvcigkt';
  static const _uploadPreset = 'throttleiq_unsigned';
  static const _endpoint =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Cloudinary routes non-image media (audio included) through its `video`
  /// resource type — confirmed against the live `throttleiq_unsigned`
  /// preset before wiring this in (a short AAC clip uploaded successfully
  /// and came back with `is_audio: true`), so no preset/account change was
  /// needed to add voice notes.
  static const _videoEndpoint =
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload';

  /// Uploads [file] under the given [folder] (organizational only, e.g.
  /// `avatars` or `rideShares/$uid`) and returns its public `secure_url`.
  Future<String> upload(File file, {required String folder}) async {
    final url = await _post(_endpoint, file, folder: folder);
    return url;
  }

  /// Uploads a short audio clip (e.g. a push-to-talk voice note) and
  /// returns its public `secure_url`. Kept separate from [upload] rather
  /// than adding a resource-type parameter to it, so the avatar/ride-photo
  /// upload path is untouched by this addition.
  Future<String> uploadAudio(File file, {required String folder}) async {
    return _post(_videoEndpoint, file, folder: folder);
  }

  Future<String> _post(String endpoint, File file,
      {required String folder}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'upload_preset': _uploadPreset,
      'folder': folder,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      endpoint,
      data: formData,
    );
    final url = response.data?['secure_url'] as String?;
    if (url == null) {
      throw StateError(
          'Cloudinary upload succeeded but returned no secure_url.');
    }
    // Fire-and-forget: see the class doc comment for why a failed ledger write
    // must not fail the upload the rider is waiting on.
    unawaited(_recordAsset(
      publicId: response.data?['public_id'] as String?,
      resourceType: response.data?['resource_type'] as String?,
      folder: folder,
      url: url,
    ));
    return url;
  }

  /// Notes one uploaded asset in the per-rider ledger the deletion sweep reads.
  Future<void> _recordAsset({
    required String? publicId,
    required String? resourceType,
    required String folder,
    required String url,
  }) async {
    if (publicId == null) return;
    final uid = _uid();
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('cloudinaryAssets')
          .add({
        'publicId': publicId,
        // 'image' or 'video' — Cloudinary routes audio through 'video', and
        // destroy() must be called with the matching resource_type.
        'resourceType': resourceType ?? 'image',
        'folder': folder,
        'secureUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort by design. The folder-prefix fallback in the sweep covers
      // an asset whose ledger row never landed.
    }
  }
}
