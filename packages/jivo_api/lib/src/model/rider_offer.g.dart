// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_offer.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderOfferCWProxy {
  RiderOffer id(int id);

  RiderOffer taskId(int taskId);

  RiderOffer storeName(String storeName);

  RiderOffer dropLocality(String dropLocality);

  RiderOffer distanceKm(String distanceKm);

  RiderOffer paymentType(RiderPaymentTypeEnum paymentType);

  RiderOffer codAmount(String? codAmount);

  RiderOffer estimatedPayout(String estimatedPayout);

  RiderOffer itemCount(int itemCount);

  RiderOffer offeredAt(DateTime offeredAt);

  RiderOffer expiresAt(DateTime expiresAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderOffer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderOffer(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderOffer call({
    int id,
    int taskId,
    String storeName,
    String dropLocality,
    String distanceKm,
    RiderPaymentTypeEnum paymentType,
    String? codAmount,
    String estimatedPayout,
    int itemCount,
    DateTime offeredAt,
    DateTime expiresAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderOffer.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderOffer.copyWith.fieldName(...)`
class _$RiderOfferCWProxyImpl implements _$RiderOfferCWProxy {
  const _$RiderOfferCWProxyImpl(this._value);

  final RiderOffer _value;

  @override
  RiderOffer id(int id) => this(id: id);

  @override
  RiderOffer taskId(int taskId) => this(taskId: taskId);

  @override
  RiderOffer storeName(String storeName) => this(storeName: storeName);

  @override
  RiderOffer dropLocality(String dropLocality) =>
      this(dropLocality: dropLocality);

  @override
  RiderOffer distanceKm(String distanceKm) => this(distanceKm: distanceKm);

  @override
  RiderOffer paymentType(RiderPaymentTypeEnum paymentType) =>
      this(paymentType: paymentType);

  @override
  RiderOffer codAmount(String? codAmount) => this(codAmount: codAmount);

  @override
  RiderOffer estimatedPayout(String estimatedPayout) =>
      this(estimatedPayout: estimatedPayout);

  @override
  RiderOffer itemCount(int itemCount) => this(itemCount: itemCount);

  @override
  RiderOffer offeredAt(DateTime offeredAt) => this(offeredAt: offeredAt);

  @override
  RiderOffer expiresAt(DateTime expiresAt) => this(expiresAt: expiresAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderOffer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderOffer(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderOffer call({
    Object? id = const $CopyWithPlaceholder(),
    Object? taskId = const $CopyWithPlaceholder(),
    Object? storeName = const $CopyWithPlaceholder(),
    Object? dropLocality = const $CopyWithPlaceholder(),
    Object? distanceKm = const $CopyWithPlaceholder(),
    Object? paymentType = const $CopyWithPlaceholder(),
    Object? codAmount = const $CopyWithPlaceholder(),
    Object? estimatedPayout = const $CopyWithPlaceholder(),
    Object? itemCount = const $CopyWithPlaceholder(),
    Object? offeredAt = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
  }) {
    return RiderOffer(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int,
      storeName: storeName == const $CopyWithPlaceholder()
          ? _value.storeName
          // ignore: cast_nullable_to_non_nullable
          : storeName as String,
      dropLocality: dropLocality == const $CopyWithPlaceholder()
          ? _value.dropLocality
          // ignore: cast_nullable_to_non_nullable
          : dropLocality as String,
      distanceKm: distanceKm == const $CopyWithPlaceholder()
          ? _value.distanceKm
          // ignore: cast_nullable_to_non_nullable
          : distanceKm as String,
      paymentType: paymentType == const $CopyWithPlaceholder()
          ? _value.paymentType
          // ignore: cast_nullable_to_non_nullable
          : paymentType as RiderPaymentTypeEnum,
      codAmount: codAmount == const $CopyWithPlaceholder()
          ? _value.codAmount
          // ignore: cast_nullable_to_non_nullable
          : codAmount as String?,
      estimatedPayout: estimatedPayout == const $CopyWithPlaceholder()
          ? _value.estimatedPayout
          // ignore: cast_nullable_to_non_nullable
          : estimatedPayout as String,
      itemCount: itemCount == const $CopyWithPlaceholder()
          ? _value.itemCount
          // ignore: cast_nullable_to_non_nullable
          : itemCount as int,
      offeredAt: offeredAt == const $CopyWithPlaceholder()
          ? _value.offeredAt
          // ignore: cast_nullable_to_non_nullable
          : offeredAt as DateTime,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
    );
  }
}

extension $RiderOfferCopyWith on RiderOffer {
  /// Returns a callable class that can be used as follows: `instanceOfRiderOffer.copyWith(...)` or like so:`instanceOfRiderOffer.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderOfferCWProxy get copyWith => _$RiderOfferCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderOffer _$RiderOfferFromJson(Map<String, dynamic> json) => $checkedCreate(
  'RiderOffer',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'task_id',
        'store_name',
        'drop_locality',
        'distance_km',
        'payment_type',
        'cod_amount',
        'estimated_payout',
        'item_count',
        'offered_at',
        'expires_at',
      ],
    );
    final val = RiderOffer(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      taskId: $checkedConvert('task_id', (v) => (v as num).toInt()),
      storeName: $checkedConvert('store_name', (v) => v as String),
      dropLocality: $checkedConvert('drop_locality', (v) => v as String),
      distanceKm: $checkedConvert('distance_km', (v) => v as String),
      paymentType: $checkedConvert(
        'payment_type',
        (v) => $enumDecode(
          _$RiderPaymentTypeEnumEnumMap,
          v,
          unknownValue: RiderPaymentTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      codAmount: $checkedConvert('cod_amount', (v) => v as String?),
      estimatedPayout: $checkedConvert('estimated_payout', (v) => v as String),
      itemCount: $checkedConvert('item_count', (v) => (v as num).toInt()),
      offeredAt: $checkedConvert(
        'offered_at',
        (v) => DateTime.parse(v as String),
      ),
      expiresAt: $checkedConvert(
        'expires_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'taskId': 'task_id',
    'storeName': 'store_name',
    'dropLocality': 'drop_locality',
    'distanceKm': 'distance_km',
    'paymentType': 'payment_type',
    'codAmount': 'cod_amount',
    'estimatedPayout': 'estimated_payout',
    'itemCount': 'item_count',
    'offeredAt': 'offered_at',
    'expiresAt': 'expires_at',
  },
);

Map<String, dynamic> _$RiderOfferToJson(RiderOffer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'task_id': instance.taskId,
      'store_name': instance.storeName,
      'drop_locality': instance.dropLocality,
      'distance_km': instance.distanceKm,
      'payment_type': _$RiderPaymentTypeEnumEnumMap[instance.paymentType]!,
      'cod_amount': instance.codAmount,
      'estimated_payout': instance.estimatedPayout,
      'item_count': instance.itemCount,
      'offered_at': instance.offeredAt.toIso8601String(),
      'expires_at': instance.expiresAt.toIso8601String(),
    };

const _$RiderPaymentTypeEnumEnumMap = {
  RiderPaymentTypeEnum.PREPAID: 'PREPAID',
  RiderPaymentTypeEnum.COD: 'COD',
  RiderPaymentTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
