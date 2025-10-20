import 'dart:typed_data';
import 'package:exif/exif.dart';

class ExtractedMetadata {
  final DateTime? takenAt;
  final Map<String, double>? geo; // {lat, lng}

  const ExtractedMetadata({this.takenAt, this.geo});
}

Future<ExtractedMetadata> extractFromImageBytes(Uint8List bytes) async {
  try {
    // Parse EXIF data
    final data = await readExifFromBytes(bytes);

    // Debug: Print all available EXIF tags
    print('Available EXIF tags: ${data.keys.toList()}');

    DateTime? takenAt;
    Map<String, double>? geo;

    // Extract creation date - try multiple possible field names
    String? dateTimeStr;

    // Try different EXIF date fields in order of preference
    if (data.containsKey('EXIF DateTimeOriginal')) {
      dateTimeStr = data['EXIF DateTimeOriginal']?.toString();
      print('Found EXIF DateTimeOriginal: $dateTimeStr');
    } else if (data.containsKey('EXIF DateTime')) {
      dateTimeStr = data['EXIF DateTime']?.toString();
      print('Found EXIF DateTime: $dateTimeStr');
    } else if (data.containsKey('EXIF DateTimeDigitized')) {
      dateTimeStr = data['EXIF DateTimeDigitized']?.toString();
      print('Found EXIF DateTimeDigitized: $dateTimeStr');
    } else if (data.containsKey('Image DateTime')) {
      dateTimeStr = data['Image DateTime']?.toString();
      print('Found Image DateTime: $dateTimeStr');
    }

    if (dateTimeStr != null) {
      try {
        // EXIF date format: "YYYY:MM:DD HH:MM:SS"
        final parts = dateTimeStr.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split(':');
          final timeParts = parts[1].split(':');
          if (dateParts.length == 3 && timeParts.length == 3) {
            takenAt = DateTime(
              int.parse(dateParts[0]), // year
              int.parse(dateParts[1]), // month
              int.parse(dateParts[2]), // day
              int.parse(timeParts[0]), // hour
              int.parse(timeParts[1]), // minute
              int.parse(timeParts[2]), // second
            );
            print('Parsed takenAt: $takenAt');
          }
        }
      } catch (e) {
        print('Error parsing EXIF date: $e');
      }
    } else {
      print('No EXIF date found in any standard field');
    }

    // Extract GPS coordinates
    if (data.containsKey('GPS GPSLatitude') &&
        data.containsKey('GPS GPSLongitude')) {
      try {
        final lat = _parseGpsCoordinate(data['GPS GPSLatitude']?.toString());
        final lng = _parseGpsCoordinate(data['GPS GPSLongitude']?.toString());
        final latRef = data['GPS GPSLatitudeRef']?.toString();
        final lngRef = data['GPS GPSLongitudeRef']?.toString();

        if (lat != null && lng != null) {
          // Apply direction (N/S, E/W)
          final finalLat = latRef == 'S' ? -lat : lat;
          final finalLng = lngRef == 'W' ? -lng : lng;

          geo = {'lat': finalLat, 'lng': finalLng};
        }
      } catch (e) {
        print('Error parsing GPS coordinates: $e');
      }
    }

    return ExtractedMetadata(takenAt: takenAt, geo: geo);
  } catch (e) {
    print('Error extracting EXIF data: $e');
    return const ExtractedMetadata();
  }
}

double? _parseGpsCoordinate(String? coordStr) {
  if (coordStr == null) return null;

  try {
    // GPS format: "DD/1 MM/1 SS/1" or "DD MM SS"
    final parts = coordStr.split(' ');
    if (parts.length >= 3) {
      final degrees = _parseGpsPart(parts[0]);
      final minutes = _parseGpsPart(parts[1]);
      final seconds = _parseGpsPart(parts[2]);

      if (degrees != null && minutes != null && seconds != null) {
        return degrees + (minutes / 60.0) + (seconds / 3600.0);
      }
    }
  } catch (e) {
    print('Error parsing GPS coordinate: $e');
  }

  return null;
}

double? _parseGpsPart(String part) {
  try {
    if (part.contains('/')) {
      final parts = part.split('/');
      if (parts.length == 2) {
        final numerator = double.parse(parts[0]);
        final denominator = double.parse(parts[1]);
        return denominator != 0 ? numerator / denominator : null;
      }
    } else {
      return double.parse(part);
    }
  } catch (e) {
    print('Error parsing GPS part: $e');
  }

  return null;
}
