import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/onboarding/domain/image_compression.dart';

/// Returns a JPEG of [sizeFor] bytes for each step, and records the steps.
class LadderCodec implements ImageCodec {
  LadderCodec(this.sizeFor);

  final int Function(CompressionStep step) sizeFor;
  final steps = <CompressionStep>[];

  @override
  Future<Uint8List> encodeJpeg(
    String sourcePath, {
    required int shortSide,
    required int quality,
  }) async {
    final step = CompressionStep(shortSide, quality);
    steps.add(step);
    return Uint8List(sizeFor(step));
  }
}

void main() {
  group('compressToLimit (04 §2.2: <= 1 MB)', () {
    test('the cap is 1,000,000 bytes', () {
      expect(kKycImageMaxBytes, 1000000);
    });

    test('a small photo is still re-encoded once (drops EXIF)', () async {
      final codec = LadderCodec((_) => 200000);
      final result = await compressToLimit(codec: codec, sourcePath: 'a.jpg');

      expect(codec.steps, hasLength(1));
      expect(result.length, 200000);
      expect(result.step.shortSide, 1600);
      expect(result.step.quality, 85);
    });

    test('steps down until the result fits, then stops', () async {
      // Over the cap until the shorter side is 1280 px.
      final codec = LadderCodec((s) => s.shortSide > 1280 ? 1600000 : 900000);
      final result = await compressToLimit(codec: codec, sourcePath: 'a.jpg');

      expect(codec.steps.map((s) => '${s.shortSide}/${s.quality}'), [
        '1600/85',
        '1600/70',
        '1280/70',
      ]);
      expect(result.length, lessThanOrEqualTo(kKycImageMaxBytes));
    });

    test('exactly the cap passes; one byte over does not', () async {
      final atCap = await compressToLimit(
        codec: LadderCodec((_) => kKycImageMaxBytes),
        sourcePath: 'a.jpg',
      );
      expect(atCap.length, kKycImageMaxBytes);

      final overCodec = LadderCodec(
        (s) => s.quality == 85 ? kKycImageMaxBytes + 1 : 500000,
      );
      final next = await compressToLimit(codec: overCodec, sourcePath: 'a.jpg');
      expect(overCodec.steps, hasLength(2));
      expect(next.length, 500000);
    });

    test('still too large at the last step: ImageTooLargeException with the '
        'smallest size', () async {
      var size = 3000000;
      final codec = LadderCodec((_) => size -= 100000);

      await expectLater(
        compressToLimit(codec: codec, sourcePath: 'a.jpg'),
        throwsA(
          isA<ImageTooLargeException>().having(
            (e) => e.smallestBytes,
            'smallestBytes',
            3000000 - 100000 * kKycCompressionLadder.length,
          ),
        ),
      );
      expect(codec.steps, hasLength(kKycCompressionLadder.length));
    });

    test('an empty result means the file is not an image', () async {
      await expectLater(
        compressToLimit(codec: LadderCodec((_) => 0), sourcePath: 'a.pdf'),
        throwsA(isA<ImageUnreadableException>()),
      );
    });

    test('a custom limit and ladder', () async {
      final codec = LadderCodec((s) => s.quality * 1000);
      final result = await compressToLimit(
        codec: codec,
        sourcePath: 'a.jpg',
        maxBytes: 60000,
        ladder: const [CompressionStep(800, 90), CompressionStep(800, 50)],
      );
      expect(result.length, 50000);
    });

    test('the ladder only ever gets smaller', () {
      for (var i = 1; i < kKycCompressionLadder.length; i++) {
        final previous = kKycCompressionLadder[i - 1];
        final step = kKycCompressionLadder[i];
        expect(
          step.shortSide < previous.shortSide ||
              (step.shortSide == previous.shortSide &&
                  step.quality < previous.quality),
          isTrue,
          reason: '$step after $previous',
        );
      }
    });
  });
}
