import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// EXIF tags that hold when a photo was taken: DateTimeOriginal, then DateTimeDigitized, then the
/// file's DateTime.
const List<int> _exifDateTags = <int>[0x9003, 0x9004, 0x0132];

/// Parses an EXIF date such as `2026:11:12 10:11:12`. EXIF has no time zone, so the result is in
/// the device's local time. Returns null for anything else (including the all-zero "unknown" date).
DateTime? parseExifDateTime(String? value) {
  if (value == null) return null;
  final RegExpMatch? m = RegExp(r'^\s*(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(value);
  if (m == null) return null;
  final List<int> p = <int>[for (int i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  if (p[0] == 0 || p[1] < 1 || p[1] > 12 || p[2] < 1 || p[2] > 31 || p[3] > 23 || p[4] > 59 || p[5] > 59) {
    return null;
  }
  return DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
}

/// When the photo was taken, from its EXIF metadata, or null if it has none (or is not a JPEG).
/// Never throws: a photo without readable metadata just has no capture time.
DateTime? photoCaptureTime(Uint8List bytes, String mimeType) {
  if (mimeType != 'image/jpeg') return null;
  try {
    final img.ExifData? exif = img.decodeJpgExif(bytes);
    if (exif == null) return null;
    for (final int tag in _exifDateTags) {
      final DateTime? found = parseExifDateTime((exif.exifIfd.data[tag] ?? exif.imageIfd.data[tag])?.toString());
      if (found != null) return found;
    }
  } catch (_) {}
  return null;
}
