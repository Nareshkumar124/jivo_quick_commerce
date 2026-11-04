import 'dart:math';

import 'package:jivo_core/jivo_core.dart';

/// A random UUID (version 4) for the `Idempotency-Key` header on
/// `POST /orders/` and the payment calls (`02 §5`). The same key is sent
/// again when a request's outcome is unknown (timeout, lost connection), so
/// the server returns the first order instead of creating a second one.
String newIdempotencyKey([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Whether a failed request may still have reached the server and done its
/// work (timeout, lost connection, a 5xx or an unrecognised failure). Then
/// the same `Idempotency-Key` must be sent again; after any definite answer
/// a new attempt gets a new key.
bool isOutcomeUnknown(ApiError error) => switch (error.code) {
  ApiErrorCode.network ||
  ApiErrorCode.timeout ||
  ApiErrorCode.serverError ||
  ApiErrorCode.unknown => true,
  _ => false,
};
