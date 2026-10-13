import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Collects a minimal diagnostic bundle and delivers it via the native share
/// sheet (email, WhatsApp, etc.).
///
/// Reports are also written to `<Documents>/bug_reports/` so the rider can
/// find them later via the Files app if the share is dismissed:
///   - iOS:  Files → ThrottleIQ → bug_reports/
///   - Android: Files → Internal Storage → Android/data/…/files/bug_reports/
///
/// Nothing is uploaded automatically — the rider controls where it goes.
class BugReportService {
  BugReportService._();
  static final BugReportService instance = BugReportService._();

  /// Saves the report to disk and opens the native share sheet.
  ///
  /// Returns the saved [File] on success, or null if saving failed (in which
  /// case the share sheet is still attempted with in-memory text).
  Future<File?> submit(String description) async {
    final payload = await buildPayload(description);
    final json = const JsonEncoder.withIndent('  ').convert(payload);

    File? savedFile;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/bug_reports');
      if (!await folder.exists()) await folder.create(recursive: true);
      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      savedFile = File('${folder.path}/report_$ts.json');
      await savedFile.writeAsString(json);
    } catch (e) {
      debugPrint('[BugReport] Could not save report file: $e');
    }

    // Share — either the file or fallback to plain text
    try {
      if (savedFile != null) {
        await Share.shareXFiles(
          [XFile(savedFile.path, mimeType: 'application/json')],
          subject: 'ThrottleIQ Bug Report',
          text: 'Bug report from ThrottleIQ. Please send this to the dev team.',
        );
      } else {
        await Share.share(
          json,
          subject: 'ThrottleIQ Bug Report',
        );
      }
    } catch (e) {
      debugPrint('[BugReport] Share failed: $e');
    }

    return savedFile;
  }

  @visibleForTesting
  Future<Map<String, dynamic>> buildPayload(String description) async {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}

    return {
      'app': 'ThrottleIQ',
      'version': '1.0.0',
      'platform': Platform.operatingSystem,
      'os': Platform.operatingSystemVersion,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'uid': uid ?? 'not-signed-in',
      'description': description,
    };
  }
}
