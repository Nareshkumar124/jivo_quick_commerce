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
  Future<UploadResult> upload(List<LocationPoint> batch) async {
    try {
      final result = (await _api.getRiderApi().riderLocationsCreate(
        locationBatchRequest: LocationBatchRequest(
          points: [for (final p in batch) _point(p)],
        ),
      )).data!;
      return _accepted(result.location);
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
      return _accepted(beat.location);
    } on DioException catch (e) {
      return mapUploadError(ApiError.fromDioException(e));
    } on Object catch (e) {
      return UploadRetryLater(e);
    }
  }

  static LocationPointRequest _point(LocationPoint p) => LocationPointRequest(
    lat: p.lat,
    lng: p.lng,
    // Required by the contract; geolocator always reports it on Android.
    accuracy: p.accuracy ?? 0,
    speed: p.speed,
    heading: p.heading,
    recordedAt: p.recordedAt,
    isMocked: p.isMocked,
  );

  static UploadAccepted _accepted(RiderLocationSettings s) {
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
