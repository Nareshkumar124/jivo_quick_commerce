// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_cash_updated_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsCashUpdatedData {
  /// Returns a new [WsCashUpdatedData] instance.
  WsCashUpdatedData({
    required this.riderId,

    required this.cashInHand,

    required this.cashLimit,

    required this.limitReached,

    required this.depositRequired,

    required this.reason,

    required this.updatedAt,
  });

  @JsonKey(name: r'rider_id', required: true, includeIfNull: false)
  final int riderId;

  @JsonKey(name: r'cash_in_hand', required: true, includeIfNull: false)
  final String cashInHand;

  @JsonKey(name: r'cash_limit', required: true, includeIfNull: false)
  final String cashLimit;

  @JsonKey(name: r'limit_reached', required: true, includeIfNull: false)
  final bool limitReached;

  /// Show the \"deposit cash\" banner (08 §5, DL-61 b).
  @JsonKey(name: r'deposit_required', required: true, includeIfNull: false)
  final bool depositRequired;

  @JsonKey(
    name: r'reason',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WsCashUpdatedDataReasonEnum.unknownDefaultOpenApi,
  )
  final WsCashUpdatedDataReasonEnum reason;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsCashUpdatedData &&
          other.riderId == riderId &&
          other.cashInHand == cashInHand &&
          other.cashLimit == cashLimit &&
          other.limitReached == limitReached &&
          other.depositRequired == depositRequired &&
          other.reason == reason &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      riderId.hashCode +
      cashInHand.hashCode +
      cashLimit.hashCode +
      limitReached.hashCode +
      depositRequired.hashCode +
      reason.hashCode +
      updatedAt.hashCode;

  factory WsCashUpdatedData.fromJson(Map<String, dynamic> json) =>
      _$WsCashUpdatedDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsCashUpdatedDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum WsCashUpdatedDataReasonEnum {
  @JsonValue(r'COD_COLLECTED')
  COD_COLLECTED(r'COD_COLLECTED'),
  @JsonValue(r'DEPOSIT')
  DEPOSIT(r'DEPOSIT'),
  @JsonValue(r'ADJUSTMENT')
  ADJUSTMENT(r'ADJUSTMENT'),
  @JsonValue(r'DEPOSIT_REQUIRED')
  DEPOSIT_REQUIRED(r'DEPOSIT_REQUIRED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WsCashUpdatedDataReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
