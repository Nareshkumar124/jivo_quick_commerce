// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pickup_code_state.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PickupCodeState {
  /// Returns a new [PickupCodeState] instance.
  PickupCodeState({required this.attemptsRemaining, required this.locked});

  /// Wrong order codes left before pickup locks (`PICKUP_CODE_MAX_ATTEMPTS`).
  @JsonKey(name: r'attempts_remaining', required: true, includeIfNull: false)
  final int attemptsRemaining;

  /// True after too many wrong order codes: ops are alerted and can unlock it.
  @JsonKey(name: r'locked', required: true, includeIfNull: false)
  final bool locked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PickupCodeState &&
          other.attemptsRemaining == attemptsRemaining &&
          other.locked == locked;

  @override
  int get hashCode => attemptsRemaining.hashCode + locked.hashCode;

  factory PickupCodeState.fromJson(Map<String, dynamic> json) =>
      _$PickupCodeStateFromJson(json);

  Map<String, dynamic> toJson() => _$PickupCodeStateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
