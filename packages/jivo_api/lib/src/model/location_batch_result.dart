// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/location_reject_reasons.dart';
import 'package:jivo_api/src/model/rider_location_settings.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'location_batch_result.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LocationBatchResult {
  /// Returns a new [LocationBatchResult] instance.
  LocationBatchResult({
    required this.accepted,

    required this.duplicates,

    required this.rejected,

    required this.rejectedReasons,

    required this.outOfOrder,

    required this.lowAccuracy,

    required this.activeTaskId,

    required this.location,

    required this.serverTime,
  });

  /// Points stored now.
  @JsonKey(name: r'accepted', required: true, includeIfNull: false)
  final int accepted;

  /// Points already stored (a resent batch).
  @JsonKey(name: r'duplicates', required: true, includeIfNull: false)
  final int duplicates;

  /// Points not stored (sum of `rejected_reasons`): too old, in the future, (0, 0) or an implausible jump. Do not resend them.
  @JsonKey(name: r'rejected', required: true, includeIfNull: false)
  final int rejected;

  /// T-821.
  @JsonKey(name: r'rejected_reasons', required: true, includeIfNull: false)
  final LocationRejectReasons rejectedReasons;

  /// T-821: of `accepted`, points older than the live position (a late buffer): kept as history, they do not move the rider on the maps.
  @JsonKey(name: r'out_of_order', required: true, includeIfNull: false)
  final int outOfOrder;

  /// T-821: of `accepted`, points less accurate than RIDER_LOCATION_MAX_ACCURACY_M (300 m): history only.
  @JsonKey(name: r'low_accuracy', required: true, includeIfNull: false)
  final int lowAccuracy;

  /// T-821: the task the points were linked to, or null.
  @JsonKey(name: r'active_task_id', required: true, includeIfNull: true)
  final int? activeTaskId;

  @JsonKey(name: r'location', required: true, includeIfNull: false)
  final RiderLocationSettings location;

  @JsonKey(name: r'server_time', required: true, includeIfNull: false)
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationBatchResult &&
          other.accepted == accepted &&
          other.duplicates == duplicates &&
          other.rejected == rejected &&
          other.rejectedReasons == rejectedReasons &&
          other.outOfOrder == outOfOrder &&
          other.lowAccuracy == lowAccuracy &&
          other.activeTaskId == activeTaskId &&
          other.location == location &&
          other.serverTime == serverTime;

  @override
  int get hashCode =>
      accepted.hashCode +
      duplicates.hashCode +
      rejected.hashCode +
      rejectedReasons.hashCode +
      outOfOrder.hashCode +
      lowAccuracy.hashCode +
      (activeTaskId == null ? 0 : activeTaskId.hashCode) +
      location.hashCode +
      serverTime.hashCode;

  factory LocationBatchResult.fromJson(Map<String, dynamic> json) =>
      _$LocationBatchResultFromJson(json);

  Map<String, dynamic> toJson() => _$LocationBatchResultToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
