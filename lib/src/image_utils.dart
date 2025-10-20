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

  /// Resizes an image without compression (preserves quality)
  static Future<Uint8List> resizeImage(
    Uint8List imageBytes, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      // Skip resizing for very small files
      if (imageBytes.length < 500 * 1024) {
        // Less than 500KB
        return imageBytes;
      }

      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

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

      // Only resize if significantly smaller
      if ((newWidth < image.width * 0.8 || newHeight < image.height * 0.8) &&
          (newWidth != image.width || newHeight != image.height)) {
        final resizedImage = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );

        // Encode with high quality (no compression)
        return Uint8List.fromList(img.encodeJpg(resizedImage, quality: 95));
      }

      // Return original if no resizing needed
      return imageBytes;
    } catch (e) {
      print('Error resizing image: $e');
      return imageBytes; // Return original if resize fails
    }
  }

  /// Compresses an image to reduce file size (optimized for speed)
  static Future<Uint8List> compressImage(
    Uint8List imageBytes, {
    int quality = 50, // Very aggressive compression for speed
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      // Skip compression for very small files
      if (imageBytes.length < 200 * 1024) {
        // Less than 200KB
        return imageBytes;
      }

      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

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

      // Only resize if significantly smaller (skip small resizes for speed)
      img.Image resizedImage = image;
      if ((newWidth < image.width * 0.8 || newHeight < image.height * 0.8) &&
          (newWidth != image.width || newHeight != image.height)) {
        resizedImage = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear, // More reliable than nearest
        );
      }

      // Encode with aggressive quality for speed
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

      // Calculate crop dimensions to fill the square
      int cropSize = size;
      int cropX = 0;
      int cropY = 0;

      if (image.width > image.height) {
        // Landscape: crop width to match height
        cropSize = image.height;
        cropX = (image.width - image.height) ~/ 2; // Center the crop
      } else if (image.height > image.width) {
        // Portrait: crop height to match width
        cropSize = image.width;
        cropY = (image.height - image.width) ~/ 2; // Center the crop
      } else {
        // Square: use as-is
        cropSize = image.width;
      }

      // Crop to square first
      final croppedImage = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropSize,
        height: cropSize,
      );

      // Generate thumbnail by resizing the cropped square
      final thumbnail = img.copyResize(
        croppedImage,
        width: size,
        height: size,
        interpolation: img.Interpolation.linear,
      );

      // Encode as JPEG with high quality for better thumbnails
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 90));
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
