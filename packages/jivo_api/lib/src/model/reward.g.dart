// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RewardCWProxy {
  Reward code(String code);

  Reward title(String title);

  Reward source_(CouponSourceEnum source_);

  Reward status(RewardStatusEnum status);

  Reward expiresAt(DateTime? expiresAt);

  Reward orderNumber(String? orderNumber);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Reward(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Reward(...).copyWith(id: 12, name: "My name")
  /// ````
  Reward call({
    String code,
    String title,
    CouponSourceEnum source_,
    RewardStatusEnum status,
    DateTime? expiresAt,
    String? orderNumber,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReward.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReward.copyWith.fieldName(...)`
class _$RewardCWProxyImpl implements _$RewardCWProxy {
  const _$RewardCWProxyImpl(this._value);

  final Reward _value;

  @override
  Reward code(String code) => this(code: code);

  @override
  Reward title(String title) => this(title: title);

  @override
  Reward source_(CouponSourceEnum source_) => this(source_: source_);

  @override
  Reward status(RewardStatusEnum status) => this(status: status);

  @override
  Reward expiresAt(DateTime? expiresAt) => this(expiresAt: expiresAt);

  @override
  Reward orderNumber(String? orderNumber) => this(orderNumber: orderNumber);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Reward(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Reward(...).copyWith(id: 12, name: "My name")
  /// ````
  Reward call({
    Object? code = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
  }) {
    return Reward(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      source_: source_ == const $CopyWithPlaceholder()
          ? _value.source_
          // ignore: cast_nullable_to_non_nullable
          : source_ as CouponSourceEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as RewardStatusEnum,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String?,
    );
  }
}

extension $RewardCopyWith on Reward {
  /// Returns a callable class that can be used as follows: `instanceOfReward.copyWith(...)` or like so:`instanceOfReward.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RewardCWProxy get copyWith => _$RewardCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Reward _$RewardFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Reward',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'code',
        'title',
        'source',
        'status',
        'expires_at',
        'order_number',
      ],
    );
    final val = Reward(
      code: $checkedConvert('code', (v) => v as String),
      title: $checkedConvert('title', (v) => v as String),
      source_: $checkedConvert(
        'source',
        (v) => $enumDecode(
          _$CouponSourceEnumEnumMap,
          v,
          unknownValue: CouponSourceEnum.unknownDefaultOpenApi,
        ),
      ),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$RewardStatusEnumEnumMap,
          v,
          unknownValue: RewardStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      expiresAt: $checkedConvert(
        'expires_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      orderNumber: $checkedConvert('order_number', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'source_': 'source',
    'expiresAt': 'expires_at',
    'orderNumber': 'order_number',
  },
);

Map<String, dynamic> _$RewardToJson(Reward instance) => <String, dynamic>{
  'code': instance.code,
  'title': instance.title,
  'source': _$CouponSourceEnumEnumMap[instance.source_]!,
  'status': _$RewardStatusEnumEnumMap[instance.status]!,
  'expires_at': instance.expiresAt?.toIso8601String(),
  'order_number': instance.orderNumber,
};

const _$CouponSourceEnumEnumMap = {
  CouponSourceEnum.NONE: 'NONE',
  CouponSourceEnum.WELCOME: 'WELCOME',
  CouponSourceEnum.REFERRAL_REFERRER: 'REFERRAL_REFERRER',
  CouponSourceEnum.REFERRAL_REFERRED: 'REFERRAL_REFERRED',
  CouponSourceEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$RewardStatusEnumEnumMap = {
  RewardStatusEnum.AVAILABLE: 'AVAILABLE',
  RewardStatusEnum.CLAIMED: 'CLAIMED',
  RewardStatusEnum.USED: 'USED',
  RewardStatusEnum.EXPIRED: 'EXPIRED',
  RewardStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
