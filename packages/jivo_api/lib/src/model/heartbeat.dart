// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_shift.dart';
import 'package:jivo_api/src/model/rider_location_settings.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'heartbeat.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Heartbeat {
  /// Returns a new [Heartbeat] instance.
  Heartbeat({
    required this.isOnline,

    required this.pendingOfferId,

    required this.activeTaskId,

    required this.shift,

    required this.location,

    required this.serverTime,
  });

  /// False after an auto-offline or ops action: stop the location service.
  @JsonKey(name: r'is_online', required: true, includeIfNull: false)
  final bool isOnline;

  /// A PENDING offer for this rider: open `offers/current/`.
  @JsonKey(name: r'pending_offer_id', required: true, includeIfNull: true)
  final int? pendingOfferId;

  @JsonKey(name: r'active_task_id', required: true, includeIfNull: true)
  final int? activeTaskId;

  /// The open shift, or the last one: when `is_online` turned false, `ended_at` and `ended_by` say when and why (\"set offline at 14:05, no location\").
  @JsonKey(name: r'shift', required: true, includeIfNull: true)
  final RiderShift? shift;

  @JsonKey(name: r'location', required: true, includeIfNull: false)
  final RiderLocationSettings location;

  @JsonKey(name: r'server_time', required: true, includeIfNull: false)
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Heartbeat &&
          other.isOnline == isOnline &&
          other.pendingOfferId == pendingOfferId &&
          other.activeTaskId == activeTaskId &&
          other.shift == shift &&
          other.location == location &&
          other.serverTime == serverTime;

  @override
  int get hashCode =>
      isOnline.hashCode +
      (pendingOfferId == null ? 0 : pendingOfferId.hashCode) +
      (activeTaskId == null ? 0 : activeTaskId.hashCode) +
      (shift == null ? 0 : shift.hashCode) +
      location.hashCode +
      serverTime.hashCode;

  factory Heartbeat.fromJson(Map<String, dynamic> json) =>
      _$HeartbeatFromJson(json);

  Map<String, dynamic> toJson() => _$HeartbeatToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
