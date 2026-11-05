import 'package:flutter/foundation.dart';

import '../../location/domain/tracking_config.dart';
import '../../task/domain/rider_task.dart';

/// What the server answers when a shift starts (`rider_shift_start`).
@immutable
class ShiftStart {
  const ShiftStart({
    this.idleIntervals,
    this.onTaskIntervals,
    this.maxBatch,
    this.prepaidOnly = false,
  });

  /// Location periods for this shift (the server's `location` settings).
  /// Null keeps the `config/app` values.
  final TrackingIntervals? idleIntervals;
  final TrackingIntervals? onTaskIntervals;
  final int? maxBatch;

  /// Cash in hand is at the limit: the rider is online but gets prepaid
  /// offers only (04 §2.3). Not a refusal.
  final bool prepaidOnly;

  /// [base] with the server's values applied (clamped to safe bounds).
  TrackingConfig applyTo(TrackingConfig base) => base.withServerIntervals(
    idle: idleIntervals,
    onTask: onTaskIntervals,
    maxBatchSize: maxBatch,
  );
}

/// Who ended the last shift (`shift.ended_by`).
enum ShiftEndedBy { rider, system, ops, unknown }

/// The server's view of the shift (`rider_heartbeat`).
@immutable
class ShiftStatus {
  const ShiftStatus({
    required this.isOnline,
    this.endedBy,
    this.pendingOfferId,
    this.activeTaskId,
  });

  final bool isOnline;

  /// Set when [isOnline] is false and a shift ended: [ShiftEndedBy.system]
  /// is the auto-offline after 10 minutes without location.
  final ShiftEndedBy? endedBy;
  final int? pendingOfferId;
  final int? activeTaskId;
}

/// The rider's shift (04 §2.3): `POST /rider/shift/start/`,
/// `POST /rider/shift/end/` and `POST /rider/heartbeat/` (06 §3).
///
/// The server owns the guards. A refusal is thrown as a jivo_core
/// `ApiError` whose `details.reason` says which: `RIDER_NOT_ACTIVE` (403),
/// `DOCUMENTS_NOT_APPROVED` (409, `doc_types`) or `TOO_FAR_FROM_STORE`
/// (422 `OUTSIDE_GEOFENCE`, `distance_m`, `radius_m`).
abstract interface class ShiftRepository {
  /// Goes online from [at] (the server checks the distance to the home
  /// store).
  Future<ShiftStart> start(GeoPoint at, {double? accuracy});

  /// Goes offline.
  Future<void> end();

  /// Whether the server still has the rider online (app start, resume).
  Future<ShiftStatus> status();
}
