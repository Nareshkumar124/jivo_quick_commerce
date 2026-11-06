// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/earning_type_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'earnings_adjustment.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EarningsAdjustment {
  /// Returns a new [EarningsAdjustment] instance.
  EarningsAdjustment({
    required this.type,

    required this.amount,

    required this.note,

    required this.recordedAt,
  });

  /// INCENTIVE or PENALTY (not tied to an order).  * `BASE` - Base pay * `DISTANCE` - Distance pay * `TIP` - Customer tip * `INCENTIVE` - Incentive * `PENALTY` - Penalty
  @JsonKey(
    name: r'type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: EarningTypeEnum.unknownDefaultOpenApi,
  )
  final EarningTypeEnum type;

  /// Signed.
  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final String amount;

  @JsonKey(name: r'note', required: true, includeIfNull: false)
  final String note;

  @JsonKey(name: r'recorded_at', required: true, includeIfNull: false)
  final DateTime recordedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EarningsAdjustment &&
          other.type == type &&
          other.amount == amount &&
          other.note == note &&
          other.recordedAt == recordedAt;

  @override
  int get hashCode =>
      type.hashCode + amount.hashCode + note.hashCode + recordedAt.hashCode;

  factory EarningsAdjustment.fromJson(Map<String, dynamic> json) =>
      _$EarningsAdjustmentFromJson(json);

  Map<String, dynamic> toJson() => _$EarningsAdjustmentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
