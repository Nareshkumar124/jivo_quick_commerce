// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
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

    required this.location,

    required this.serverTime,
  });

  /// Points stored now.
  @JsonKey(name: r'accepted', required: true, includeIfNull: false)
  final int accepted;

  /// Points already stored (a resent batch).
  @JsonKey(name: r'duplicates', required: true, includeIfNull: false)
  final int duplicates;

  /// Points not stored: recorded more than 24 hours ago, or more than 2 minutes in the future. Do not resend them.
  @JsonKey(name: r'rejected', required: true, includeIfNull: false)
  final int rejected;

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
          other.location == location &&
          other.serverTime == serverTime;

  @override
  int get hashCode =>
      accepted.hashCode +
      duplicates.hashCode +
      rejected.hashCode +
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
