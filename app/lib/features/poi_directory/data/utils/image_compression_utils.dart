import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageCompressionUtils {
  /// Maximum file size in bytes (2 MB)
  static const int maxFileSizeBytes = 2 * 1024 * 1024;

  /// Hard cap on decoded pixel count (50 megapixels — far beyond any real
  /// phone camera's default JPEG output, but bounds worst-case decoded
  /// memory to ~200MB instead of whatever a crafted file's header claims).
  ///
  /// docs/Issues.md §33.11: `img.decodeImage` fully decodes into an
  /// uncompressed bitmap with no size check beforehand. A small file whose
  /// header declares huge pixel dimensions (a decompression bomb) could
  /// decode to gigabytes of raw RGBA and crash the app. Checking the header
  /// via `startDecode` first — which parses dimensions without decoding
  /// pixel data — makes this check cheap regardless of the real decode cost.
  static const int _maxDecodePixels = 50 * 1000 * 1000;

  /// Returns the decoded image, or null if the file is unreadable/unsupported
  /// OR its declared dimensions exceed [_maxDecodePixels].
  static img.Image? _safeDecodeImage(Uint8List imageBytes) {
    final decoder = img.findDecoderForData(imageBytes);
    if (decoder == null) return null;
    final info = decoder.startDecode(imageBytes);
    if (info == null || info.width * info.height > _maxDecodePixels) {
      return null;
    }
    return decoder.decode(imageBytes);
  }

  /// Compress image from file path
  static Future<File?> compressImage(String imagePath) async {
    try {
      final file = File(imagePath);

      // Read the image
      final imageBytes = await file.readAsBytes();

      // Decode the image
      final image = _safeDecodeImage(imageBytes);
      if (image == null) return null;

      // Resize if necessary (max width 1280px)
      img.Image resized = image;
      if (image.width > 1280) {
        resized = img.copyResize(
          image,
          width: 1280,
          height: (image.height * 1280 / image.width).toInt(),
          interpolation: img.Interpolation.linear,
        );
      }

      // Compress with quality reduction
      List<int> compressed = img.encodeJpg(resized, quality: 85);

      // If still too large, reduce quality further
      int quality = 85;
      while (compressed.length > maxFileSizeBytes && quality > 50) {
        quality -= 5;
        compressed = img.encodeJpg(resized, quality: quality);
      }

      // Create a temporary file for the compressed image
      final tempDir = Directory.systemTemp;
      final fileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File('${tempDir.path}/$fileName');

      await compressedFile.writeAsBytes(compressed);

      return compressedFile;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  /// Get file size in MB
  static Future<double> getFileSizeMB(String filePath) async {
    final file = File(filePath);
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  /// Check if file is within size limit
  static Future<bool> isFileSizeValid(String filePath) async {
    final file = File(filePath);
    final bytes = await file.length();
    return bytes <= maxFileSizeBytes;
  }

  /// Compress multiple images
  static Future<List<File>> compressImages(List<String> imagePaths) async {
    final compressedFiles = <File>[];

    for (final imagePath in imagePaths) {
      final compressed = await compressImage(imagePath);
      if (compressed != null) {
        compressedFiles.add(compressed);
      }
    }

    return compressedFiles;
  }

  /// Get image dimensions
  static Future<Map<String, int>?> getImageDimensions(String imagePath) async {
    try {
      final file = File(imagePath);
      final imageBytes = await file.readAsBytes();
      final image = _safeDecodeImage(imageBytes);

      if (image == null) return null;

      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      print('Error getting image dimensions: $e');
      return null;
    }
  }

  /// Compress image from bytes
  static Future<Uint8List?> compressImageFromBytes(
    Uint8List imageBytes, {
    int maxWidth = 1280,
    int quality = 85,
  }) async {
    try {
      final image = _safeDecodeImage(imageBytes);
      if (image == null) return null;

      // Resize if necessary
      img.Image resized = image;
      if (image.width > maxWidth) {
        resized = img.copyResize(
          image,
          width: maxWidth,
          height: (image.height * maxWidth / image.width).toInt(),
          interpolation: img.Interpolation.linear,
        );
      }

      // Compress with quality reduction
      List<int> compressed = img.encodeJpg(resized, quality: quality);

      // If still too large, reduce quality further
      int currentQuality = quality;
      while (compressed.length > maxFileSizeBytes && currentQuality > 50) {
        currentQuality -= 5;
        compressed = img.encodeJpg(resized, quality: currentQuality);
      }

      return Uint8List.fromList(compressed);
    } catch (e) {
      print('Error compressing image from bytes: $e');
      return null;
    }
  }
}
