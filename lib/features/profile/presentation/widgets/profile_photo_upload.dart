import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media/data/media_repository.dart';
import '../../../media/data/photo_orientation.dart';

/// The system photo picker failed before any upload started.
class PhotoPickException implements Exception {
  const PhotoPickException(this.detail);
  final String detail;

  @override
  String toString() => 'Could not open the photo picker: $detail';
}

/// A photo picked and uploaded, ready to save on the profile.
class UploadedPhoto {
  const UploadedPhoto(this.mediaId, this.bytes);

  final int mediaId;

  /// For the preview until the profile is saved and reloaded.
  final Uint8List bytes;
}

/// Lets the traveler pick an image and uploads it. Returns null if they cancel.
/// Throws a [FormatException] with a message to show for an unsupported file,
/// and the network error if the upload fails.
Future<UploadedPhoto?> pickAndUploadPhoto(WidgetRef ref) async {
  final FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
  } catch (e) {
    throw PhotoPickException(e.toString());
  }
  final PlatformFile? file = result?.files.single;
  final Uint8List? bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  final String? mimeType = photoMimeType(file.name);
  if (mimeType == null) {
    throw const FormatException('Please pick a JPEG, PNG, WebP or HEIC photo.');
  }
  // Straighten first so the preview matches what is stored (upload does it too, but it is a no-op then).
  final Uint8List upright = await uprightPhoto(bytes, mimeType);
  final int mediaId = await ref.read(mediaRepositoryProvider).uploadPhoto(upright, mimeType);
  return UploadedPhoto(mediaId, upright);
}

/// The message to show when [pickAndUploadPhoto] fails.
String photoUploadError(Object error) {
  if (error is FormatException) return error.message;
  if (error is MediaUploadException) return 'Could not upload the photo. $error';
  if (error is PhotoPickException) return error.toString();
  // Unexpected error: include its type and text so a bug report says what broke.
  final String text = error.toString();
  return 'Could not upload the photo (${error.runtimeType}): ${text.length > 160 ? text.substring(0, 160) : text}';
}
