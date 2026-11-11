import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media/data/media_repository.dart';

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
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  final PlatformFile? file = result?.files.single;
  final Uint8List? bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  final String? mimeType = photoMimeType(file.name);
  if (mimeType == null) {
    throw const FormatException('Please pick a JPEG, PNG, WebP or HEIC photo.');
  }
  final int mediaId = await ref.read(mediaRepositoryProvider).uploadPhoto(bytes, mimeType);
  return UploadedPhoto(mediaId, bytes);
}

/// The message to show when [pickAndUploadPhoto] fails.
String photoUploadError(Object error) {
  if (error is FormatException) return error.message;
  if (error is MediaUploadException) return 'Could not upload the photo. $error';
  return 'Could not upload the photo. Please try again.';
}
