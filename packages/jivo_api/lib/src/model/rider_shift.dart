// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/shift_end_reason_enum.dart';
import 'package:jivo_api/src/model/shift_ended_by_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_shift.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderShift {
  /// Returns a new [RiderShift] instance.
  RiderShift({
    required this.id,

    required this.startedAt,

    required this.endedAt,

    required this.endReason,

    required this.endedBy,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'started_at', required: true, includeIfNull: false)
  final DateTime startedAt;

  @JsonKey(name: r'ended_at', required: true, includeIfNull: true)
  final DateTime? endedAt;

  /// MANUAL, AUTO_OFFLINE (no location for 10 min) or ADMIN; null while open.  * `MANUAL` - Rider went offline * `AUTO_OFFLINE` - No location for too long * `ADMIN` - Set offline by ops
  @JsonKey(
    name: r'end_reason',
    required: true,
    includeIfNull: true,
    unknownEnumValue: ShiftEndReasonEnum.unknownDefaultOpenApi,
  )
  final ShiftEndReasonEnum? endReason;

  /// rider, system or ops; null while open.  * `rider` - The rider * `system` - The server (no location) * `ops` - Ops
  @JsonKey(
    name: r'ended_by',
    required: true,
    includeIfNull: true,
    unknownEnumValue: ShiftEndedByEnum.unknownDefaultOpenApi,
  )
  final ShiftEndedByEnum? endedBy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderShift &&
          other.id == id &&
          other.startedAt == startedAt &&
          other.endedAt == endedAt &&
          other.endReason == endReason &&
          other.endedBy == endedBy;

  @override
  int get hashCode =>
      id.hashCode +
      startedAt.hashCode +
      (endedAt == null ? 0 : endedAt.hashCode) +
      (endReason == null ? 0 : endReason.hashCode) +
      (endedBy == null ? 0 : endedBy.hashCode);

  factory RiderShift.fromJson(Map<String, dynamic> json) =>
      _$RiderShiftFromJson(json);

  Map<String, dynamic> toJson() => _$RiderShiftToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
