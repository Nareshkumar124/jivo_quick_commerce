import 'kyc_document.dart';

enum ImagePickSource { camera, gallery }

/// A photo the rider took or chose, as a temporary file. It still has its
/// EXIF data: never upload it, compress it ([compressToLimit]) and then
/// [KycImagePicker.discard] it.
class PickedImage {
  const PickedImage(this.path);

  final String path;

  @override
  String toString() => 'PickedImage';
}

/// Camera or gallery. Behind an interface so widget tests run without the
/// image_picker platform channel.
abstract interface class KycImagePicker {
  /// Null when the rider cancelled.
  Future<PickedImage?> pick(ImagePickSource source, {required bool selfie});

  /// On low-memory phones Android can stop the app while the camera is
  /// open; the photo is then delivered on the next start. Null when there is
  /// none.
  Future<PickedImage?> retrieveLost();

  /// Deletes the temporary file (best effort), so KYC photos do not stay in
  /// the app cache.
  Future<void> discard(PickedImage image);
}

/// Remembers which document the camera was opened for, so a photo recovered
/// with [KycImagePicker.retrieveLost] after Android stopped the app goes to
/// the right document. Holds only the document type.
abstract interface class PendingCaptureStore {
  Future<KycDocumentType?> read();
  Future<void> write(KycDocumentType type);
  Future<void> clear();
}

class InMemoryPendingCaptureStore implements PendingCaptureStore {
  KycDocumentType? _type;

  @override
  Future<KycDocumentType?> read() async => _type;

  @override
  Future<void> write(KycDocumentType type) async => _type = type;

  @override
  Future<void> clear() async => _type = null;
}
