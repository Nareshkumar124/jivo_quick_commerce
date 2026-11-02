import 'location_point.dart';
import 'tracking_config.dart';

/// Outcome of one batch POST.
sealed class UploadResult {
  const UploadResult();
}

/// The server stored the batch. It may send new intervals back.
final class UploadAccepted extends UploadResult {
  const UploadAccepted({this.idleIntervals, this.onTaskIntervals});

  final TrackingIntervals? idleIntervals;
  final TrackingIntervals? onTaskIntervals;
}

/// Temporary failure (no network, timeout, 5xx, 429). Keep the points and
/// retry on the next tick.
final class UploadRetryLater extends UploadResult {
  const UploadRetryLater([this.reason]);

  final Object? reason;
}

/// The server refused the batch for good (a 4xx validation error). Drop it,
/// otherwise one bad batch would block every later point.
final class UploadRejected extends UploadResult {
  const UploadRejected(this.code);

  /// Error-envelope code from `docs/06` §6.
  final String code;
}

/// Sends a batch to `POST /api/v1/rider/locations/`.
///
/// TODO(api): the real implementation needs the P5 rider contract in
/// `jivo_api` and the shared dio client from `jivo_core`. Until then the app
/// uses [FakeLocationUploader].
abstract interface class LocationUploader {
  /// Must not throw. Map every failure to [UploadRetryLater] or
  /// [UploadRejected].
  Future<UploadResult> upload(List<LocationPoint> batch);
}
