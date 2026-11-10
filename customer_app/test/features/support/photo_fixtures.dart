import 'dart:convert';
import 'dart:typed_data';

import 'package:customer_app/features/support/data/ticket_photo_picker.dart';
import 'package:customer_app/features/support/domain/support_models.dart';

/// A real 1x1 PNG, so `Image.memory` can decode it.
final pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGA'
  'WjR9awAAAABJRU5ErkJggg==',
);

/// Just the JPEG and WebP signatures (enough for the type check).
final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);
final webpBytes = Uint8List.fromList([
  ...'RIFF'.codeUnits,
  0x24,
  0,
  0,
  0,
  ...'WEBP'.codeUnits,
  ...'VP8 '.codeUnits,
]);

/// Answers picks from a queue; an empty queue means "cancelled".
class FakeTicketPhotoPicker implements TicketPhotoPicker {
  FakeTicketPhotoPicker([List<TicketPhotoFile>? queue]) : queue = queue ?? [];

  final List<TicketPhotoFile> queue;
  final List<TicketPhotoSource> sources = [];

  /// When set, the next pick throws it once (camera permission denied).
  Object? failNext;

  @override
  Future<TicketPhotoFile?> pick(TicketPhotoSource source) async {
    sources.add(source);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return queue.isEmpty ? null : queue.removeAt(0);
  }
}

TicketPhotoFile pngPhoto([String name = 'IMG.png']) =>
    TicketPhotoFile(bytes: pngBytes, filename: name);
