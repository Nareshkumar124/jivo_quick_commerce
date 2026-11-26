// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/coupon_source_enum.dart';
import 'package:jivo_api/src/model/reward_status_enum.dart';
import 'package:jivo_api/src/model/free_variant.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reward.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Reward {
  /// Returns a new [Reward] instance.
  Reward({
    required this.code,

    required this.title,

    required this.quantity,

    required this.freeVariant,

    required this.source_,

    required this.status,

    required this.expiresAt,

    required this.orderNumber,
  });

  /// Apply it with `POST /cart/coupon/`: {`code`} alone when `free_variant` is set (ADR 0003, no size sheet), else {`code`, `free_variant_id`} with the size the customer picks (ADR 0002).
  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  /// e.g. \"2 free cartons: welcome reward\".
  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  /// ADR 0003: free cartons this reward gives (e.g. 2). Fixed when the reward is given.
  // minimum: 1
  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final int quantity;

  /// ADR 0003: the size of the free cartons, the store's fixed free size (show \"2 free cartons · 1 L x 12\"; **Use** applies it without a size sheet). The store is the one in the optional `X-Store-Id` header, else the store of the caller's cart. Null when that store has no fixed size (or there is no store yet): then the customer picks the size (ADR 0002).
  @JsonKey(name: r'free_variant', required: true, includeIfNull: true)
  final FreeVariant? freeVariant;

  /// WELCOME, REFERRAL_REFERRER or REFERRAL_REFERRED.  * `NONE` - Made by staff * `WELCOME` - Welcome reward (new account) * `REFERRAL_REFERRER` - Referral reward (you invited a friend) * `REFERRAL_REFERRED` - Referral reward (you joined with a friend's code)
  @JsonKey(
    name: r'source',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CouponSourceEnum.unknownDefaultOpenApi,
  )
  final CouponSourceEnum source_;

  /// AVAILABLE: show **Use**. CLAIMED: on order `order_number`, not delivered yet (it comes back to AVAILABLE if that order is cancelled or its payment fails, unless it has expired by then).  * `AVAILABLE` - Can be used * `CLAIMED` - On an order that is not delivered yet * `USED` - Used on a delivered order * `EXPIRED` - Expired without being used
  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RewardStatusEnum.unknownDefaultOpenApi,
  )
  final RewardStatusEnum status;

  /// UTC (show the date in IST); null = no expiry.
  @JsonKey(name: r'expires_at', required: true, includeIfNull: true)
  final DateTime? expiresAt;

  /// CLAIMED: the order it is on. Null when AVAILABLE.
  @JsonKey(name: r'order_number', required: true, includeIfNull: true)
  final String? orderNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reward &&
          other.code == code &&
          other.title == title &&
          other.quantity == quantity &&
          other.freeVariant == freeVariant &&
          other.source_ == source_ &&
          other.status == status &&
          other.expiresAt == expiresAt &&
          other.orderNumber == orderNumber;

  @override
  int get hashCode =>
      code.hashCode +
      title.hashCode +
      quantity.hashCode +
      (freeVariant == null ? 0 : freeVariant.hashCode) +
      source_.hashCode +
      status.hashCode +
      (expiresAt == null ? 0 : expiresAt.hashCode) +
      (orderNumber == null ? 0 : orderNumber.hashCode);

  factory Reward.fromJson(Map<String, dynamic> json) => _$RewardFromJson(json);

  Map<String, dynamic> toJson() => _$RewardToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
