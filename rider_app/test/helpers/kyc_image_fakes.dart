import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:rider_app/features/onboarding/domain/image_compression.dart';
import 'package:rider_app/features/onboarding/domain/image_picking.dart';

/// A valid 1x1 PNG, so `Image.memory` in widget tests decodes cleanly.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Camera / gallery stand-in.
class FakeKycImagePicker implements KycImagePicker {
  int _count = 0;

  /// What the next [pick] does: a photo (default), null (cancelled), or
  /// throws [PlatformException].
  bool cancelNext = false;
  bool failNext = false;

  /// Returned once by [retrieveLost].
  PickedImage? lost;

  /// Runs while the camera or gallery is "open".
  Future<void> Function()? whilePicking;

  final picks = <(ImagePickSource, bool)>[];
  final discarded = <String>[];

  @override
  Future<PickedImage?> pick(
    ImagePickSource source, {
    required bool selfie,
  }) async {
    picks.add((source, selfie));
    await whilePicking?.call();
    if (failNext) {
      failNext = false;
      throw PlatformException(code: 'no_available_camera');
    }
    if (cancelNext) {
      cancelNext = false;
      return null;
    }
    return PickedImage('/cache/picked_${_count++}.jpg');
  }

  @override
  Future<PickedImage?> retrieveLost() async {
    final image = lost;
    lost = null;
    return image;
  }

  @override
  Future<void> discard(PickedImage image) async => discarded.add(image.path);
}

/// Codec stand-in: returns [result] (default: a tiny PNG), or throws
/// [ImageUnreadableException] when [unreadable].
class FakeImageCodec implements ImageCodec {
  Uint8List? result;
  bool unreadable = false;
  final calls = <(String, int, int)>[];

  @override
  Future<Uint8List> encodeJpeg(
    String sourcePath, {
    required int shortSide,
    required int quality,
  }) async {
    calls.add((sourcePath, shortSide, quality));
    if (unreadable) throw const ImageUnreadableException();
    return result ?? tinyPng;
  }
}
