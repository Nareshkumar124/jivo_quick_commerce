import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/image_compression.dart';
import '../domain/image_picking.dart';
import '../domain/kyc_document.dart';

/// image_picker: the camera app, or the Android photo picker for the gallery
/// (no storage permission). Logs never include paths or image data.
class ImagePickerKycPicker implements KycImagePicker {
  ImagePickerKycPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// A first native downscale while picking, so budget phones never hold a
  /// full 50 MP bitmap. [compressToLimit] does the real work afterwards.
  static const _pickMaxSide = 2400.0;

  @override
  Future<PickedImage?> pick(
    ImagePickSource source, {
    required bool selfie,
  }) async {
    final file = await _picker.pickImage(
      source: source == ImagePickSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: _pickMaxSide,
      maxHeight: _pickMaxSide,
      imageQuality: 92,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
      requestFullMetadata: false,
    );
    return file == null ? null : PickedImage(file.path);
  }

  @override
  Future<PickedImage?> retrieveLost() async {
    try {
      final response = await _picker.retrieveLostData();
      final file = response.file;
      if (response.isEmpty || file == null) return null;
      return PickedImage(file.path);
    } on Object catch (error) {
      debugPrint('ImagePickerKycPicker.retrieveLost: ${error.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> discard(PickedImage image) async {
    try {
      final file = File(image.path);
      if (await file.exists()) await file.delete();
    } on Object catch (error) {
      debugPrint('ImagePickerKycPicker.discard: ${error.runtimeType}');
    }
  }
}

/// flutter_image_compress: native JPEG re-encode. `keepExif: false` drops
/// EXIF (GPS, device); `autoCorrectionAngle` applies the EXIF rotation
/// first so the upload is upright.
class NativeImageCodec implements ImageCodec {
  const NativeImageCodec();

  @override
  Future<Uint8List> encodeJpeg(
    String sourcePath, {
    required int shortSide,
    required int quality,
  }) async {
    Uint8List? bytes;
    try {
      bytes = await FlutterImageCompress.compressWithFile(
        sourcePath,
        minWidth: shortSide,
        minHeight: shortSide,
        quality: quality,
      );
    } on Object catch (error) {
      debugPrint('NativeImageCodec: ${error.runtimeType}');
      throw const ImageUnreadableException();
    }
    if (bytes == null || bytes.isEmpty) {
      throw const ImageUnreadableException();
    }
    return bytes;
  }
}

/// The pending-capture marker as a small file in app support storage. Holds
/// only the document type's wire value, never an image or a number.
class FilePendingCaptureStore implements PendingCaptureStore {
  const FilePendingCaptureStore();

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/kyc/pending_capture');
  }

  @override
  Future<KycDocumentType?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return KycDocumentType.fromWire((await file.readAsString()).trim());
    } on Object catch (error) {
      debugPrint('FilePendingCaptureStore.read: ${error.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> write(KycDocumentType type) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(type.wireValue, flush: true);
    } on Object catch (error) {
      debugPrint('FilePendingCaptureStore.write: ${error.runtimeType}');
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } on Object catch (error) {
      debugPrint('FilePendingCaptureStore.clear: ${error.runtimeType}');
    }
  }
}
