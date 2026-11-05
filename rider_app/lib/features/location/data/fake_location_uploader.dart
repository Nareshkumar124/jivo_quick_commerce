import 'package:flutter/foundation.dart';

import '../domain/location_point.dart';
import '../domain/location_uploader.dart';

/// TODO(api): stand-in for `POST /api/v1/rider/locations/` (and the
/// heartbeat) until the P5 rider contract is in `jivo_api`. It accepts every
/// batch unless:
/// - [simulateOffline] is on: it behaves like a dropped network
///   ([UploadRetryLater]);
/// - [simulateServerOffline] is on: the server already auto-offlined the
///   rider ([UploadTrackingStopped] with `RIDER_OFFLINE`, api-requests #4).
class FakeLocationUploader implements LocationUploader {
  FakeLocationUploader({
    this.simulateOffline = false,
    this.simulateServerOffline = false,
    this.latency,
  });

  /// The error code assumed for "the server already ended the shift".
  static const riderOfflineCode = 'RIDER_OFFLINE';

  bool simulateOffline;
  bool simulateServerOffline;

  /// Optional artificial delay per request.
  final Duration? latency;

  /// Batches "sent" so far, newest last. Kept small: only the last 20.
  final List<List<LocationPoint>> sentBatches = [];
  int heartbeats = 0;

  Future<UploadResult?> _common() async {
    if (latency != null) await Future<void>.delayed(latency!);
    if (simulateOffline) return const UploadRetryLater('simulated offline');
    if (simulateServerOffline) {
      return const UploadTrackingStopped(riderOfflineCode);
    }
    return null;
  }

  @override
  Future<UploadResult> upload(List<LocationPoint> batch) async {
    final failure = await _common();
    if (failure != null) return failure;
    sentBatches.add(List.unmodifiable(batch));
    if (sentBatches.length > 20) sentBatches.removeAt(0);
    debugPrint(
      'FakeLocationUploader: POST /rider/locations/ ${batch.length} points, '
      'first recorded_at=${batch.first.recordedAt.toIso8601String()}',
    );
    return const UploadAccepted();
  }

  @override
  Future<UploadResult> heartbeat({LocationPoint? lastKnown}) async {
    final failure = await _common();
    if (failure != null) return failure;
    heartbeats++;
    debugPrint('FakeLocationUploader: heartbeat (last fix: $lastKnown)');
    return const UploadAccepted();
  }
}
