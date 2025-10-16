class ExtractedMetadata {
  final DateTime? takenAt;
  final Map<String, double>? geo; // {lat, lng}

  const ExtractedMetadata({this.takenAt, this.geo});
}

ExtractedMetadata extractFromImageBytes(Object /*Uint8List*/ _bytes) {
  // TODO: Implement real EXIF extraction for creation date and GPS when needed.
  return const ExtractedMetadata();
}


