import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';

class ImageUtils {
  // Supported image MIME types
  static const List<String> supportedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
  ];

  // Supported video MIME types
  static const List<String> supportedVideoTypes = [
    'video/mp4',
    'video/avi',
    'video/mov',
    'video/wmv',
    'video/flv',
    'video/webm',
  ];

  // Maximum file size in bytes (10MB)
  static const int maxFileSize = 10 * 1024 * 1024;

  // Thumbnail dimensions
  static const int thumbnailSize = 200;

  /// Validates if a file is a supported image or video type
  static bool isValidFileType(String fileName) {
    final mimeType = lookupMimeType(fileName);
    if (mimeType == null) return false;

    return supportedImageTypes.contains(mimeType) ||
        supportedVideoTypes.contains(mimeType);
  }

  /// Validates if a file is an image
  static bool isImage(String fileName) {
    final mimeType = lookupMimeType(fileName);
    return mimeType != null && supportedImageTypes.contains(mimeType);
  }

  /// Validates if a file is a video
  static bool isVideo(String fileName) {
    final mimeType = lookupMimeType(fileName);
    return mimeType != null && supportedVideoTypes.contains(mimeType);
  }

  /// Validates file size
  static bool isValidFileSize(int fileSize) {
    return fileSize <= maxFileSize;
  }

  /// Compresses an image to reduce file size
  static Future<Uint8List> compressImage(
    Uint8List imageBytes, {
    int quality = 85,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Skip compression if image is already small enough
      if (imageBytes.length < 500 * 1024) {
        // Less than 500KB
        return imageBytes;
      }

      // Calculate new dimensions if maxWidth or maxHeight is specified
      int newWidth = image.width;
      int newHeight = image.height;

      if (maxWidth != null && image.width > maxWidth) {
        newHeight = (image.height * maxWidth / image.width).round();
        newWidth = maxWidth;
      }

      if (maxHeight != null && newHeight > maxHeight) {
        newWidth = (newWidth * maxHeight / newHeight).round();
        newHeight = maxHeight;
      }

      // Resize if needed (use faster interpolation)
      img.Image resizedImage = image;
      if (newWidth != image.width || newHeight != image.height) {
        resizedImage = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear, // Faster than cubic
        );
      }

      // Encode with compression
      return Uint8List.fromList(img.encodeJpg(resizedImage, quality: quality));
    } catch (e) {
      print('Error compressing image: $e');
      return imageBytes; // Return original if compression fails
    }
  }

  /// Generates a thumbnail for an image
  static Future<Uint8List?> generateThumbnail(
    Uint8List imageBytes, {
    int size = thumbnailSize,
  }) async {
    try {
      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Calculate thumbnail dimensions maintaining aspect ratio
      int thumbWidth = size;
      int thumbHeight = size;

      if (image.width > image.height) {
        thumbHeight = (size * image.height / image.width).round();
      } else {
        thumbWidth = (size * image.width / image.height).round();
      }

      // Generate thumbnail with faster interpolation
      final thumbnail = img.copyResize(
        image,
        width: thumbWidth,
        height: thumbHeight,
        interpolation: img.Interpolation.linear, // Faster than cubic
      );

      // Encode as JPEG for consistency with lower quality for speed
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 70));
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Gets file type icon based on MIME type
  static String getFileTypeIcon(String fileName) {
    final mimeType = lookupMimeType(fileName);
    if (mimeType == null) return '📄';

    if (supportedImageTypes.contains(mimeType)) {
      return '🖼️';
    } else if (supportedVideoTypes.contains(mimeType)) {
      return '🎥';
    } else {
      return '📄';
    }
  }

  /// Formats file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
