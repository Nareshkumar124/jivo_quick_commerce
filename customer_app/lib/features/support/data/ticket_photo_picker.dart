import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/support_models.dart';

enum TicketPhotoSource { camera, gallery }

/// Camera or gallery for ticket photos. Behind an interface so widget tests
/// run without the image_picker platform channel.
abstract interface class TicketPhotoPicker {
  /// The picked photo, or null when the customer cancelled.
  Future<TicketPhotoFile?> pick(TicketPhotoSource source);
}

/// image_picker: the camera app, or the Android photo picker for the
/// gallery (no storage permission). The photo is downscaled and re-encoded
/// while picking, so a phone camera's 10 MB JPEG fits the 5 MB API limit
/// (and, in practice, the proxy's lower one). Logs never include paths or
/// image data.
class ImagePickerTicketPhotoPicker implements TicketPhotoPicker {
  ImagePickerTicketPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Enough to read a label or see damage; keeps uploads small.
  static const _maxSide = 1600.0;

  @override
  Future<TicketPhotoFile?> pick(TicketPhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == TicketPhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      return TicketPhotoFile(
        bytes: await file.readAsBytes(),
        filename: file.name,
      );
    } on Object catch (error) {
      // Camera access denied, or no camera app.
      debugPrint('ImagePickerTicketPhotoPicker: ${error.runtimeType}');
      rethrow;
    }
  }
}
