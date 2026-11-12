import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:travel_app_frontend/features/media/data/photo_orientation.dart';

Uint8List jpeg({required int width, required int height, int? orientation}) {
  final img.Image image = img.Image(width: width, height: height);
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  test('a sideways photo (EXIF 6) is stored upright, without the flag', () async {
    final Uint8List result = await uprightPhoto(jpeg(width: 40, height: 20, orientation: 6), 'image/jpeg');
    final img.Image decoded = img.decodeJpg(result)!;
    expect(decoded.width, 20);
    expect(decoded.height, 40);
    expect(img.decodeJpgExif(result)?.imageIfd.orientation ?? 1, 1);
  });

  test('photos that are already upright, and non-JPEGs, are returned untouched', () async {
    final Uint8List upright = jpeg(width: 40, height: 20);
    expect(await uprightPhoto(upright, 'image/jpeg'), orderedEquals(upright));
    final Uint8List png = Uint8List.fromList(<int>[1, 2, 3]);
    expect(await uprightPhoto(png, 'image/png'), orderedEquals(png));
  });

  test('bytes that are not a readable JPEG come back unchanged', () async {
    final Uint8List junk = Uint8List.fromList(<int>[1, 2, 3, 4]);
    expect(await uprightPhoto(junk, 'image/jpeg'), orderedEquals(junk));
  });
}
