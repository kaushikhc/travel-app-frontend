import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/media/data/photo_metadata.dart';

void main() {
  test('parseExifDateTime reads the EXIF date format as device-local time', () {
    expect(parseExifDateTime('2026:11:12 10:11:12'), DateTime(2026, 11, 12, 10, 11, 12));
    expect(parseExifDateTime('2026:11:12 10:11:12\u0000'), DateTime(2026, 11, 12, 10, 11, 12));
  });

  test('parseExifDateTime rejects missing, zeroed and malformed dates', () {
    expect(parseExifDateTime(null), isNull);
    expect(parseExifDateTime(''), isNull);
    expect(parseExifDateTime('0000:00:00 00:00:00'), isNull);
    expect(parseExifDateTime('2026:13:40 10:11:12'), isNull);
    expect(parseExifDateTime('yesterday'), isNull);
  });

  test('photoCaptureTime is null for non-JPEGs and unreadable bytes, and never throws', () {
    expect(photoCaptureTime(Uint8List.fromList(<int>[1, 2, 3]), 'image/png'), isNull);
    expect(photoCaptureTime(Uint8List.fromList(<int>[1, 2, 3, 4]), 'image/jpeg'), isNull);
  });
}
