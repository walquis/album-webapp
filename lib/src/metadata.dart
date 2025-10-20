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
    print(
      'GPS-related tags: ${data.keys.where((key) => key.startsWith('GPS')).toList()}',
    );

    if (data.containsKey('GPS GPSLatitude') &&
        data.containsKey('GPS GPSLongitude')) {
      try {
        final latValue = data['GPS GPSLatitude'];
        final lngValue = data['GPS GPSLongitude'];
        final latRef = data['GPS GPSLatitudeRef']?.toString();
        final lngRef = data['GPS GPSLongitudeRef']?.toString();

        print('GPS Latitude raw: $latValue (${latValue.runtimeType})');
        print('GPS Longitude raw: $lngValue (${lngValue.runtimeType})');
        print('GPS LatitudeRef: $latRef');
        print('GPS LongitudeRef: $lngRef');

        final lat = _parseGpsCoordinate(latValue);
        final lng = _parseGpsCoordinate(lngValue);

        if (lat != null && lng != null) {
          // Apply direction (N/S, E/W)
          final finalLat = latRef == 'S' ? -lat : lat;
          final finalLng = lngRef == 'W' ? -lng : lng;

          geo = {'lat': finalLat, 'lng': finalLng};
          print('Parsed GPS coordinates: lat=$finalLat, lng=$finalLng');
        } else {
          print('Failed to parse GPS coordinates: lat=$lat, lng=$lng');
        }
      } catch (e) {
        print('Error parsing GPS coordinates: $e');
      }
    } else {
      print('GPS coordinates not found in EXIF data');
    }

    return ExtractedMetadata(takenAt: takenAt, geo: geo);
  } catch (e) {
    print('Error extracting EXIF data: $e');
    return const ExtractedMetadata();
  }
}

double? _parseGpsCoordinate(dynamic coordValue) {
  if (coordValue == null) return null;

  try {
    print('Parsing GPS coordinate: $coordValue (${coordValue.runtimeType})');

    // Handle IfdTag with array values
    if (coordValue.toString().startsWith('[') &&
        coordValue.toString().endsWith(']')) {
      // Parse the string representation of the array: "[41, 52, 533/20]"
      final coordStr = coordValue.toString();
      print('Parsing GPS coordinate array string: $coordStr');

      // Remove brackets and split by comma
      final cleanStr = coordStr.substring(1, coordStr.length - 1);
      final parts = cleanStr.split(',').map((s) => s.trim()).toList();

      if (parts.length >= 3) {
        final degrees = _parseGpsPart(parts[0]);
        final minutes = _parseGpsPart(parts[1]);
        final seconds = _parseGpsPart(parts[2]);

        if (degrees != null && minutes != null && seconds != null) {
          final result = degrees + (minutes / 60.0) + (seconds / 3600.0);
          print('Parsed GPS coordinate: $result');
          return result;
        }
      }
    }

    // Handle actual List format
    if (coordValue is List && coordValue.length >= 3) {
      final degrees = _parseGpsPart(coordValue[0].toString());
      final minutes = _parseGpsPart(coordValue[1].toString());
      final seconds = _parseGpsPart(coordValue[2].toString());

      if (degrees != null && minutes != null && seconds != null) {
        final result = degrees + (minutes / 60.0) + (seconds / 3600.0);
        print('Parsed GPS coordinate: $result');
        return result;
      }
    }

    // Handle string format: "DD/1 MM/1 SS/1" or "DD MM SS"
    String coordStr;
    if (coordValue is String) {
      coordStr = coordValue;
    } else {
      coordStr = coordValue.toString();
    }

    print('Parsing GPS coordinate string: $coordStr');

    final parts = coordStr.split(' ');
    if (parts.length >= 3) {
      final degrees = _parseGpsPart(parts[0]);
      final minutes = _parseGpsPart(parts[1]);
      final seconds = _parseGpsPart(parts[2]);

      if (degrees != null && minutes != null && seconds != null) {
        final result = degrees + (minutes / 60.0) + (seconds / 3600.0);
        print('Parsed GPS coordinate: $result');
        return result;
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
