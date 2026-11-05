import 'location_point.dart';
import 'tracking_config.dart';

/// Outcome of one batch POST (or one heartbeat).
sealed class UploadResult {
  const UploadResult();
}

/// The server stored the batch. It may send new intervals back.
final class UploadAccepted extends UploadResult {
  const UploadAccepted({
    this.idleIntervals,
    this.onTaskIntervals,
    this.maxBatch,
  });

  final TrackingIntervals? idleIntervals;
  final TrackingIntervals? onTaskIntervals;
  final int? maxBatch;
}

/// Temporary failure (no network, timeout, 5xx, 429). Keep the points and
/// retry after a backoff.
final class UploadRetryLater extends UploadResult {
  const UploadRetryLater([this.reason, this.retryAfter]);

  final Object? reason;

  /// The server's `Retry-After`, if it sent one (429/503).
  final Duration? retryAfter;
}

/// The server refused the batch for good (a 4xx validation error). Drop it,
/// otherwise one bad batch would block every later point.
final class UploadRejected extends UploadResult {
  const UploadRejected(this.code);

  /// Error-envelope code from `docs/06` §6.
  final String code;
}

/// The server says this rider must not be tracked any more: it already ended
/// the shift (auto-offline after 10 min without a heartbeat, 04 §2.3), or the
/// session is over. The tracker stops at once and the service shuts down;
/// the points still buffered are kept on disk until logout.
///
/// TODO(api): the code is api-requests #4 (`RIDER_OFFLINE`, 409); a refresh
/// token the server rejected also ends up here.
final class UploadTrackingStopped extends UploadResult {
  const UploadTrackingStopped(this.code);

  final String code;
}

/// Sends a batch to `POST /api/v1/rider/locations/`.
///
/// TODO(api): the real implementation needs the P5 rider contract in
/// `jivo_api`. Until then the app uses [FakeLocationUploader].
abstract interface class LocationUploader {
  /// Must not throw. Map every failure to [UploadRetryLater],
  /// [UploadRejected] or [UploadTrackingStopped].
  Future<UploadResult> upload(List<LocationPoint> batch);

  /// Tells the server the rider is still online when no point was uploaded
  /// for [TrackingConfig.heartbeat] (rider standing still indoors with no
  /// fix, GPS stream restarting). [lastKnown] is the newest fix, if any.
  /// Must not throw.
  ///
  /// TODO(api): bind to the P5 heartbeat contract (06 §3 does not list one
  /// yet; it may be an empty `POST /rider/locations/` or its own endpoint).
  Future<UploadResult> heartbeat({LocationPoint? lastKnown});
}
