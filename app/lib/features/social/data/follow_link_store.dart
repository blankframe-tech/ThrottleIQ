import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device persistence for follow links:
///
///  - the rider's own follow link, keyed by uid, so "My QR code" opens with
///    the same code instantly instead of rebuilding it (and so it is stable
///    even if the link format ever changes for new codes);
///  - the rendered QR PNG, written once and reused for share / save;
///  - a pending follow from a link opened while signed out, completed after
///    sign-in (see follow_link_listener.dart).
class FollowLinkStore {
  const FollowLinkStore();

  static const String _myLinkKeyPrefix = 'follow_qr_link_';
  static const String _pendingKey = 'pending_follow_uid';

  Future<String?> readMyLink(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_myLinkKeyPrefix$uid');
  }

  Future<void> saveMyLink(String uid, String link) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_myLinkKeyPrefix$uid', link);
  }

  /// Where the rider's follow-QR image lives. Under app documents (not the
  /// temp dir) so the OS doesn't clear it between launches.
  Future<File> myQrImageFile(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/follow_qr');
    if (!await folder.exists()) await folder.create(recursive: true);
    return File('${folder.path}/throttleiq_follow_$uid.png');
  }

  Future<String?> readPendingFollow() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingKey);
  }

  Future<void> savePendingFollow(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, uid);
  }

  Future<void> clearPendingFollow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }
}
