// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_shift.dart';
import 'package:jivo_api/src/model/rider_cash.dart';
import 'package:jivo_api/src/model/rider_location_settings.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'shift_state.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ShiftState {
  /// Returns a new [ShiftState] instance.
  ShiftState({
    required this.isOnline,

    required this.shift,

    required this.prepaidOnly,

    required this.cash,

    required this.location,

    required this.serverTime,
  });

  @JsonKey(name: r'is_online', required: true, includeIfNull: false)
  final bool isOnline;

  /// The current shift (online), or the one just ended.
  @JsonKey(name: r'shift', required: true, includeIfNull: true)
  final RiderShift? shift;

  /// True when cash in hand is at or above the limit: online, but only prepaid offers come (04 §2.3). Show the \"Deposit cash\" banner.
  @JsonKey(name: r'prepaid_only', required: true, includeIfNull: false)
  final bool prepaidOnly;

  @JsonKey(name: r'cash', required: true, includeIfNull: false)
  final RiderCash cash;

  @JsonKey(name: r'location', required: true, includeIfNull: false)
  final RiderLocationSettings location;

  /// Server clock, for skew correction.
  @JsonKey(name: r'server_time', required: true, includeIfNull: false)
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftState &&
          other.isOnline == isOnline &&
          other.shift == shift &&
          other.prepaidOnly == prepaidOnly &&
          other.cash == cash &&
          other.location == location &&
          other.serverTime == serverTime;

  @override
  int get hashCode =>
      isOnline.hashCode +
      (shift == null ? 0 : shift.hashCode) +
      prepaidOnly.hashCode +
      cash.hashCode +
      location.hashCode +
      serverTime.hashCode;

  factory ShiftState.fromJson(Map<String, dynamic> json) =>
      _$ShiftStateFromJson(json);

  Map<String, dynamic> toJson() => _$ShiftStateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
