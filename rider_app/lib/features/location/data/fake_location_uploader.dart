import 'package:flutter/foundation.dart';

import '../domain/location_point.dart';
import '../domain/location_uploader.dart';

/// TODO(api): stand-in for `POST /api/v1/rider/locations/` until the P5 rider
/// contract is in `jivo_api`. It accepts every batch unless [simulateOffline]
/// is on, in which case it behaves like a dropped network
/// ([UploadRetryLater]). Used by the dev-flavor location debug screen only.
class FakeLocationUploader implements LocationUploader {
  FakeLocationUploader({this.simulateOffline = false, this.latency});

  bool simulateOffline;

  /// Optional artificial delay per request.
  final Duration? latency;

  /// Batches "sent" so far, newest last. Kept small: only the last 20.
  final List<List<LocationPoint>> sentBatches = [];

  @override
  Future<UploadResult> upload(List<LocationPoint> batch) async {
    if (latency != null) await Future<void>.delayed(latency!);
    if (simulateOffline) {
      return const UploadRetryLater('simulated offline');
    }
    sentBatches.add(List.unmodifiable(batch));
    if (sentBatches.length > 20) sentBatches.removeAt(0);
    debugPrint(
      'FakeLocationUploader: POST /rider/locations/ ${batch.length} points, '
      'first recorded_at=${batch.first.recordedAt.toIso8601String()}',
    );
    return const UploadAccepted();
  }
}
