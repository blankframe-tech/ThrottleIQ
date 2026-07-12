import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageCompressionUtils {
  /// Maximum file size in bytes (2 MB)
  static const int maxFileSizeBytes = 2 * 1024 * 1024;

  /// Compress image from file path
  static Future<File?> compressImage(String imagePath) async {
    try {
      final file = File(imagePath);

      // Read the image
      final imageBytes = await file.readAsBytes();

      // Decode the image
      final image = img.decodeImage(imageBytes);
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
      final image = img.decodeImage(imageBytes);

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
      final image = img.decodeImage(imageBytes);
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
