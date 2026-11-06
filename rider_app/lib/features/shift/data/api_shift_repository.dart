import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show
        JivoApi,
        RiderLocationSettings,
        RiderShift,
        ShiftEndedByEnum,
        ShiftStartRequest;
import 'package:jivo_core/jivo_core.dart';

import '../../location/domain/tracking_config.dart';
import '../../task/domain/rider_task.dart';
import '../domain/shift_repository.dart';

/// `rider_shift_start`, `rider_shift_end` and `rider_heartbeat` through the
/// generated client (P5 slice 5.2).
class ApiShiftRepository implements ShiftRepository {
  ApiShiftRepository(this._api);

  final JivoApi _api;

  @override
  Future<ShiftStart> start(GeoPoint at, {double? accuracy}) async {
    try {
      final response = await _api.getRiderApi().riderShiftStart(
        shiftStartRequest: ShiftStartRequest(
          lat: at.lat,
          lng: at.lng,
          accuracy: accuracy,
        ),
      );
      final state = response.data!;
      final settings = state.location;
      return ShiftStart(
        idleIntervals: _intervals(
          settings.idleSampleSeconds,
          settings.idleIntervalSeconds,
        ),
        onTaskIntervals: _intervals(
          settings.activeSampleSeconds,
          settings.activeIntervalSeconds,
        ),
        maxBatch: settings.maxBatch,
        prepaidOnly: state.prepaidOnly,
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  @override
  Future<void> end() async {
    try {
      await _api.getRiderApi().riderShiftEnd();
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  @override
  Future<ShiftStatus> status() async {
    try {
      final beat = (await _api.getRiderApi().riderHeartbeat()).data!;
      return ShiftStatus(
        isOnline: beat.isOnline,
        endedBy: beat.isOnline ? null : endedByOf(beat.shift),
        pendingOfferId: beat.pendingOfferId,
        activeTaskId: beat.activeTaskId,
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  static TrackingIntervals? _intervals(int sample, int upload) =>
      sample > 0 && upload > 0
      ? TrackingIntervals(
          sample: Duration(seconds: sample),
          upload: Duration(seconds: upload),
        )
      : null;
}

/// `shift.ended_by` as the domain enum.
ShiftEndedBy? endedByOf(RiderShift? shift) => switch (shift?.endedBy) {
  null => null,
  ShiftEndedByEnum.rider => ShiftEndedBy.rider,
  ShiftEndedByEnum.system => ShiftEndedBy.system,
  ShiftEndedByEnum.ops => ShiftEndedBy.ops,
  _ => ShiftEndedBy.unknown,
};

/// The server's `rider_location` settings applied to [base].
TrackingConfig applyRiderLocation(
  TrackingConfig base,
  RiderLocationSettings settings,
) => base.fromRiderLocationSeconds(
  active: settings.activeIntervalSeconds,
  idle: settings.idleIntervalSeconds,
  activeSample: settings.activeSampleSeconds,
  idleSample: settings.idleSampleSeconds,
  maxBatch: settings.maxBatch,
);
