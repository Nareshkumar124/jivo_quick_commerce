import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show
        JivoApi,
        LocationBatchRequest,
        LocationPointRequest,
        RiderLocationSettings;
import 'package:jivo_core/jivo_core.dart';

import '../domain/location_point.dart';
import '../domain/location_uploader.dart';
import '../domain/tracking_config.dart';

/// `POST /rider/locations/` and `POST /rider/heartbeat/` through the
/// generated client (P5 slice 5.2). Runs in the location service isolate,
/// on a Dio with that isolate's own session (see `ServiceIsolateApi`).
///
/// Error mapping (never throws):
/// - 409 `RIDER_OFFLINE`, 403 (rider not ACTIVE), 401 after the refresh
///   failed, 426: stop tracking ([UploadTrackingStopped]);
/// - no network, timeout, 5xx, 429, 503 maintenance: retry later, with the
///   server's `Retry-After` when it sends one;
/// - any other 4xx (`VALIDATION_ERROR`): drop the batch.
///
/// The server de-duplicates on (rider, `recorded_at`), so a batch whose
/// answer was lost is safe to send again.
class ApiLocationUploader implements LocationUploader {
  ApiLocationUploader(this._api);

  final JivoApi _api;

  static const riderOffline = 'RIDER_OFFLINE';

  @override
  Future<UploadResult> upload(List<LocationPoint> batch, {int? taskId}) async {
    try {
      final result = (await _api.getRiderApi().riderLocationsCreate(
        locationBatchRequest: LocationBatchRequest(
          points: [for (final p in batch) point(p)],
          taskId: taskId,
        ),
      )).data!;
      return _accepted(
        result.location,
        dropped: result.rejected,
        outOfOrder: result.outOfOrder,
        lowAccuracy: result.lowAccuracy,
        activeTaskId: result.activeTaskId,
        reportsActiveTask: true,
      );
    } on DioException catch (e) {
      return mapUploadError(ApiError.fromDioException(e));
    } on Object catch (e) {
      return UploadRetryLater(e);
    }
  }

  @override
  Future<UploadResult> heartbeat({LocationPoint? lastKnown}) async {
    try {
      final beat = (await _api.getRiderApi().riderHeartbeat()).data!;
      if (!beat.isOnline) return const UploadTrackingStopped(riderOffline);
      return _accepted(
        beat.location,
        activeTaskId: beat.activeTaskId,
        reportsActiveTask: true,
      );
    } on DioException catch (e) {
      return mapUploadError(ApiError.fromDioException(e));
    } on Object catch (e) {
      return UploadRetryLater(e);
    }
  }

  /// Accuracy sent when the device reported none or an invalid one. Far
  /// above the server's low-accuracy limit (300 m), so such a fix is kept as
  /// history only and never used as the rider's live position.
  static const double unknownAccuracyMeters = 9999;

  /// One fix as sent: position, accuracy, speed, heading and the device
  /// time it was taken (`recorded_at`, UTC).
  ///
  /// Values the contract would refuse are sent as "unknown" instead: an
  /// out-of-range speed, heading or accuracy is a 400 for the whole batch
  /// (T-821), which would drop every good fix with it.
  static LocationPointRequest point(LocationPoint p) {
    final speed = p.speed;
    final heading = p.heading;
    final accuracy = p.accuracy;
    return LocationPointRequest(
      lat: p.lat,
      lng: p.lng,
      // Required by the contract. An unknown or invalid accuracy must never
      // look precise (0 would be trusted as a live fix), so it is sent as
      // [unknownAccuracyMeters]: the server keeps it as history only.
      accuracy: accuracy == null || !accuracy.isFinite || accuracy < 0
          ? unknownAccuracyMeters
          : accuracy,
      speed: speed == null || !speed.isFinite || speed < 0 ? null : speed,
      heading: heading == null || !heading.isFinite || heading < 0
          ? null
          : (heading >= 360 ? heading % 360 : heading),
      recordedAt: p.recordedAt,
      isMocked: p.isMocked,
    );
  }

  static UploadAccepted _accepted(
    RiderLocationSettings s, {
    int dropped = 0,
    int outOfOrder = 0,
    int lowAccuracy = 0,
    int? activeTaskId,
    bool reportsActiveTask = false,
  }) {
    TrackingIntervals? pair(int sample, int upload) => sample > 0 && upload > 0
        ? TrackingIntervals(
            sample: Duration(seconds: sample),
            upload: Duration(seconds: upload),
          )
        : null;
    return UploadAccepted(
      idleIntervals: pair(s.idleSampleSeconds, s.idleIntervalSeconds),
      onTaskIntervals: pair(s.activeSampleSeconds, s.activeIntervalSeconds),
      maxBatch: s.maxBatch > 0 ? s.maxBatch : null,
      dropped: dropped,
      outOfOrder: outOfOrder,
      lowAccuracy: lowAccuracy,
      activeTaskId: activeTaskId,
      reportsActiveTask: reportsActiveTask,
    );
  }
}

/// Maps a failed location or heartbeat call (see [ApiLocationUploader]).
UploadResult mapUploadError(ApiError error) {
  if (error.rawCode == ApiLocationUploader.riderOffline) {
    return const UploadTrackingStopped(ApiLocationUploader.riderOffline);
  }
  final status = error.statusCode;
  switch (error.code) {
    case ApiErrorCode.authRequired ||
        ApiErrorCode.tokenInvalid ||
        ApiErrorCode.permissionDenied ||
        ApiErrorCode.appUpdateRequired:
      return UploadTrackingStopped(error.rawCode ?? error.code.name);
    case ApiErrorCode.maintenance || ApiErrorCode.rateLimited:
      return UploadRetryLater(error.code.name, _retryAfter(error));
    default:
      break;
  }
  if (status == null || status >= 500 || status == 429) {
    return UploadRetryLater(error.code.name, _retryAfter(error));
  }
  return UploadRejected(error.rawCode ?? error.code.name);
}

Duration? _retryAfter(ApiError error) {
  final seconds = error.retryAfterSeconds;
  return seconds == null ? null : Duration(seconds: seconds);
}
