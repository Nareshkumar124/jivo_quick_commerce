// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_offer_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOfferDataCWProxy {
  WsOfferData id(int id);

  WsOfferData taskId(int taskId);

  WsOfferData storeName(String storeName);

  WsOfferData dropLocality(String dropLocality);

  WsOfferData distanceKm(String distanceKm);

  WsOfferData paymentType(String paymentType);

  WsOfferData codAmount(String? codAmount);

  WsOfferData estimatedPayout(String estimatedPayout);

  WsOfferData itemCount(int itemCount);

  WsOfferData offeredAt(DateTime offeredAt);

  WsOfferData expiresAt(DateTime expiresAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferData call({
    int id,
    int taskId,
    String storeName,
    String dropLocality,
    String distanceKm,
    String paymentType,
    String? codAmount,
    String estimatedPayout,
    int itemCount,
    DateTime offeredAt,
    DateTime expiresAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOfferData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOfferData.copyWith.fieldName(...)`
class _$WsOfferDataCWProxyImpl implements _$WsOfferDataCWProxy {
  const _$WsOfferDataCWProxyImpl(this._value);

  final WsOfferData _value;

  @override
  WsOfferData id(int id) => this(id: id);

  @override
  WsOfferData taskId(int taskId) => this(taskId: taskId);

  @override
  WsOfferData storeName(String storeName) => this(storeName: storeName);

  @override
  WsOfferData dropLocality(String dropLocality) =>
      this(dropLocality: dropLocality);

  @override
  WsOfferData distanceKm(String distanceKm) => this(distanceKm: distanceKm);

  @override
  WsOfferData paymentType(String paymentType) => this(paymentType: paymentType);

  @override
  WsOfferData codAmount(String? codAmount) => this(codAmount: codAmount);

  @override
  WsOfferData estimatedPayout(String estimatedPayout) =>
      this(estimatedPayout: estimatedPayout);

  @override
  WsOfferData itemCount(int itemCount) => this(itemCount: itemCount);

  @override
  WsOfferData offeredAt(DateTime offeredAt) => this(offeredAt: offeredAt);

  @override
  WsOfferData expiresAt(DateTime expiresAt) => this(expiresAt: expiresAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferData call({
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
    return WsOfferData(
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
          : paymentType as String,
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

extension $WsOfferDataCopyWith on WsOfferData {
  /// Returns a callable class that can be used as follows: `instanceOfWsOfferData.copyWith(...)` or like so:`instanceOfWsOfferData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOfferDataCWProxy get copyWith => _$WsOfferDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOfferData _$WsOfferDataFromJson(Map<String, dynamic> json) => $checkedCreate(
  'WsOfferData',
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
    final val = WsOfferData(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      taskId: $checkedConvert('task_id', (v) => (v as num).toInt()),
      storeName: $checkedConvert('store_name', (v) => v as String),
      dropLocality: $checkedConvert('drop_locality', (v) => v as String),
      distanceKm: $checkedConvert('distance_km', (v) => v as String),
      paymentType: $checkedConvert('payment_type', (v) => v as String),
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

Map<String, dynamic> _$WsOfferDataToJson(WsOfferData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'task_id': instance.taskId,
      'store_name': instance.storeName,
      'drop_locality': instance.dropLocality,
      'distance_km': instance.distanceKm,
      'payment_type': instance.paymentType,
      'cod_amount': instance.codAmount,
      'estimated_payout': instance.estimatedPayout,
      'item_count': instance.itemCount,
      'offered_at': instance.offeredAt.toIso8601String(),
      'expires_at': instance.expiresAt.toIso8601String(),
    };
