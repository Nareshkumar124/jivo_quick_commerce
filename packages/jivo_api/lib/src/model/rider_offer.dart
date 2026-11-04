// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_payment_type_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_offer.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderOffer {
  /// Returns a new [RiderOffer] instance.
  RiderOffer({
    required this.id,

    required this.taskId,

    required this.storeName,

    required this.dropLocality,

    required this.distanceKm,

    required this.paymentType,

    required this.codAmount,

    required this.estimatedPayout,

    required this.itemCount,

    required this.offeredAt,

    required this.expiresAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'task_id', required: true, includeIfNull: false)
  final int taskId;

  @JsonKey(name: r'store_name', required: true, includeIfNull: false)
  final String storeName;

  /// Area only, e.g. \"Sector 21, Gurugram\".
  @JsonKey(name: r'drop_locality', required: true, includeIfNull: false)
  final String dropLocality;

  /// Store to drop (road estimate), e.g. \"2.40\".
  @JsonKey(name: r'distance_km', required: true, includeIfNull: false)
  final String distanceKm;

  @JsonKey(
    name: r'payment_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderPaymentTypeEnum.unknownDefaultOpenApi,
  )
  final RiderPaymentTypeEnum paymentType;

  /// Cash to collect for COD; null for prepaid.
  @JsonKey(name: r'cod_amount', required: true, includeIfNull: true)
  final String? codAmount;

  /// What the rider earns for this order (before tips).
  @JsonKey(name: r'estimated_payout', required: true, includeIfNull: false)
  final String estimatedPayout;

  @JsonKey(name: r'item_count', required: true, includeIfNull: false)
  final int itemCount;

  @JsonKey(name: r'offered_at', required: true, includeIfNull: false)
  final DateTime offeredAt;

  /// Accept before this (offered_at + 30 s). Correct with `server_time`.
  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderOffer &&
          other.id == id &&
          other.taskId == taskId &&
          other.storeName == storeName &&
          other.dropLocality == dropLocality &&
          other.distanceKm == distanceKm &&
          other.paymentType == paymentType &&
          other.codAmount == codAmount &&
          other.estimatedPayout == estimatedPayout &&
          other.itemCount == itemCount &&
          other.offeredAt == offeredAt &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      id.hashCode +
      taskId.hashCode +
      storeName.hashCode +
      dropLocality.hashCode +
      distanceKm.hashCode +
      paymentType.hashCode +
      (codAmount == null ? 0 : codAmount.hashCode) +
      estimatedPayout.hashCode +
      itemCount.hashCode +
      offeredAt.hashCode +
      expiresAt.hashCode;

  factory RiderOffer.fromJson(Map<String, dynamic> json) =>
      _$RiderOfferFromJson(json);

  Map<String, dynamic> toJson() => _$RiderOfferToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
