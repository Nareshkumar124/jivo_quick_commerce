import 'dart:typed_data';

/// KYC images must be at most 1 MB each (04 §2.2). Decimal megabyte, so the
/// file passes whether the server reads "1 MB" as 10^6 or 2^20 bytes.
const kKycImageMaxBytes = 1000000;

/// One re-encode attempt: the shorter side scaled down to at most
/// [shortSide] pixels (never up), JPEG at [quality].
class CompressionStep {
  const CompressionStep(this.shortSide, this.quality);

  final int shortSide;
  final int quality;

  @override
  String toString() => 'CompressionStep($shortSide px, q$quality)';
}

/// Tried in order until the result fits. The first step keeps documents
/// readable (text on a PAN or RC); later steps trade quality, then size.
const kKycCompressionLadder = [
  CompressionStep(1600, 85),
  CompressionStep(1600, 70),
  CompressionStep(1280, 70),
  CompressionStep(1280, 55),
  CompressionStep(1024, 55),
  CompressionStep(1024, 40),
  CompressionStep(800, 40),
];

/// Re-encodes an image file as JPEG. The platform implementation drops EXIF
/// (camera photos carry GPS) and applies the EXIF rotation.
abstract interface class ImageCodec {
  /// Throws [ImageUnreadableException] when [sourcePath] is not an image.
  Future<Uint8List> encodeJpeg(
    String sourcePath, {
    required int shortSide,
    required int quality,
  });
}

/// The picked file could not be decoded (not an image, or corrupt).
class ImageUnreadableException implements Exception {
  const ImageUnreadableException();

  @override
  String toString() => 'ImageUnreadableException';
}

/// Even the last [CompressionStep] produced more than the limit.
class ImageTooLargeException implements Exception {
  const ImageTooLargeException(this.smallestBytes);

  final int smallestBytes;

  @override
  String toString() => 'ImageTooLargeException($smallestBytes bytes)';
}

/// A compressed KYC image, ready to upload.
class CompressedImage {
  const CompressedImage({required this.bytes, required this.step});

  final Uint8List bytes;

  /// The step that produced [bytes].
  final CompressionStep step;

  int get length => bytes.length;
}

/// Re-encodes [sourcePath] with each step of [ladder] until the JPEG is at
/// most [maxBytes]. Always re-encodes at least once, even when the original
/// is already small, so EXIF (location) never leaves the phone.
///
/// Throws [ImageUnreadableException] or [ImageTooLargeException].
Future<CompressedImage> compressToLimit({
  required ImageCodec codec,
  required String sourcePath,
  int maxBytes = kKycImageMaxBytes,
  List<CompressionStep> ladder = kKycCompressionLadder,
}) async {
  assert(ladder.isNotEmpty, 'the ladder needs at least one step');
  var smallest = -1;
  for (final step in ladder) {
    final bytes = await codec.encodeJpeg(
      sourcePath,
      shortSide: step.shortSide,
      quality: step.quality,
    );
    if (bytes.isEmpty) throw const ImageUnreadableException();
    if (bytes.length <= maxBytes) {
      return CompressedImage(bytes: bytes, step: step);
    }
    if (smallest < 0 || bytes.length < smallest) smallest = bytes.length;
  }
  throw ImageTooLargeException(smallest);
}
