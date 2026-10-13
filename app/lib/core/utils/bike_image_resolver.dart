import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Utilities for resolving and validating bike photo paths and URLs.
class BikeImageResolver {
  BikeImageResolver._();

  static String? cachedDocumentsDirectoryPath;

  /// Checks if [path] is a remote HTTP or HTTPS URL.
  static bool isRemoteUrl(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// Synchronously resolves [path] to a usable path or URL.
  ///
  ///  * If [path] is null or empty, returns null.
  ///  * If [path] is a remote URL (http/https), returns it as-is.
  ///  * If [path] points to an existing file, returns it as-is.
  ///  * If the file does not exist at [path] (e.g. across an iOS app rebuild
  ///    or update where the sandbox container UUID changed), checks whether
  ///    the file with the same basename exists in [documentsDirectory] (or
  ///    [cachedDocumentsDirectoryPath]). If found, returns the valid path.
  ///  * Otherwise returns null.
  static String? resolvePathSync(
    String? path, {
    Directory? documentsDirectory,
  }) {
    if (path == null || path.isEmpty) return null;
    if (isRemoteUrl(path)) return path;

    final directFile = File(path);
    if (directFile.existsSync()) return path;

    final docsPath = documentsDirectory?.path ?? cachedDocumentsDirectoryPath;
    if (docsPath != null && docsPath.isNotEmpty) {
      final fileName = p.basename(path);
      final candidate = File(p.join(docsPath, fileName));
      if (candidate.existsSync()) {
        return candidate.path;
      }
    }

    return null;
  }

  /// Asynchronously resolves [path], fetching [getApplicationDocumentsDirectory]
  /// if not provided and updating [cachedDocumentsDirectoryPath].
  static Future<String?> resolvePath(
    String? path, {
    Directory? documentsDirectory,
  }) async {
    if (path == null || path.isEmpty) return null;
    if (isRemoteUrl(path)) return path;

    final directFile = File(path);
    if (directFile.existsSync()) return path;

    Directory? dir = documentsDirectory;
    if (dir == null) {
      try {
        dir = await getApplicationDocumentsDirectory();
        cachedDocumentsDirectoryPath = dir.path;
      } catch (_) {
        // In test environments or where path_provider isn't configured,
        // fall back to cached path if any.
      }
    }

    return resolvePathSync(path, documentsDirectory: dir);
  }
}
