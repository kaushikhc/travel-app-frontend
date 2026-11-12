import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Phone cameras store many JPEGs sideways and add an EXIF flag saying how to turn them. Not every
/// viewer honours the flag, so a photo can show rotated. This turns the pixels upright and drops the
/// flag, so the stored file looks right everywhere.
///
/// Photos without a turn flag (and every non-JPEG) are returned untouched. If the file can't be
/// read, the original bytes are returned: a photo is never lost over its rotation.
Future<Uint8List> uprightPhoto(Uint8List bytes, String mimeType) async {
  if (mimeType != 'image/jpeg') return bytes;
  return compute(uprightJpeg, bytes);
}

/// The synchronous work of [uprightPhoto]; top level so it can run in another isolate.
@visibleForTesting
Uint8List uprightJpeg(Uint8List bytes) {
  try {
    final int orientation = img.decodeJpgExif(bytes)?.imageIfd.orientation ?? 1;
    if (orientation <= 1) return bytes;
    final img.Image? decoded = img.decodeJpg(bytes);
    if (decoded == null) return bytes;
    return Uint8List.fromList(img.encodeJpg(img.bakeOrientation(decoded), quality: 92));
  } catch (_) {
    return bytes;
  }
}
