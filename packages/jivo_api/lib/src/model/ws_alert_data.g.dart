// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_alert_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsAlertDataCWProxy {
  WsAlertData code(WsAlertDataCodeEnum code);

  WsAlertData message(String message);

  WsAlertData storeId(int? storeId);

  WsAlertData orderId(int? orderId);

  WsAlertData riderId(int? riderId);

  WsAlertData at(DateTime at);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAlertData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAlertData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAlertData call({
    WsAlertDataCodeEnum code,
    String message,
    int? storeId,
    int? orderId,
    int? riderId,
    DateTime at,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsAlertData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsAlertData.copyWith.fieldName(...)`
class _$WsAlertDataCWProxyImpl implements _$WsAlertDataCWProxy {
  const _$WsAlertDataCWProxyImpl(this._value);

  final WsAlertData _value;

  @override
  WsAlertData code(WsAlertDataCodeEnum code) => this(code: code);

  @override
  WsAlertData message(String message) => this(message: message);

  @override
  WsAlertData storeId(int? storeId) => this(storeId: storeId);

  @override
  WsAlertData orderId(int? orderId) => this(orderId: orderId);

  @override
  WsAlertData riderId(int? riderId) => this(riderId: riderId);

  @override
  WsAlertData at(DateTime at) => this(at: at);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAlertData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAlertData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAlertData call({
    Object? code = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? storeId = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? riderId = const $CopyWithPlaceholder(),
    Object? at = const $CopyWithPlaceholder(),
  }) {
    return WsAlertData(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as WsAlertDataCodeEnum,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      storeId: storeId == const $CopyWithPlaceholder()
          ? _value.storeId
          // ignore: cast_nullable_to_non_nullable
          : storeId as int?,
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int?,
      riderId: riderId == const $CopyWithPlaceholder()
          ? _value.riderId
          // ignore: cast_nullable_to_non_nullable
          : riderId as int?,
      at: at == const $CopyWithPlaceholder()
          ? _value.at
          // ignore: cast_nullable_to_non_nullable
          : at as DateTime,
    );
  }
}

extension $WsAlertDataCopyWith on WsAlertData {
  /// Returns a callable class that can be used as follows: `instanceOfWsAlertData.copyWith(...)` or like so:`instanceOfWsAlertData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsAlertDataCWProxy get copyWith => _$WsAlertDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsAlertData _$WsAlertDataFromJson(Map<String, dynamic> json) => $checkedCreate(
  'WsAlertData',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'code',
        'message',
        'store_id',
        'order_id',
        'rider_id',
        'at',
      ],
    );
    final val = WsAlertData(
      code: $checkedConvert(
        'code',
        (v) => $enumDecode(
          _$WsAlertDataCodeEnumEnumMap,
          v,
          unknownValue: WsAlertDataCodeEnum.unknownDefaultOpenApi,
        ),
      ),
      message: $checkedConvert('message', (v) => v as String),
      storeId: $checkedConvert('store_id', (v) => (v as num?)?.toInt()),
      orderId: $checkedConvert('order_id', (v) => (v as num?)?.toInt()),
      riderId: $checkedConvert('rider_id', (v) => (v as num?)?.toInt()),
      at: $checkedConvert('at', (v) => DateTime.parse(v as String)),
    );
    return val;
  },
  fieldKeyMap: const {
    'storeId': 'store_id',
    'orderId': 'order_id',
    'riderId': 'rider_id',
  },
);

Map<String, dynamic> _$WsAlertDataToJson(WsAlertData instance) =>
    <String, dynamic>{
      'code': _$WsAlertDataCodeEnumEnumMap[instance.code]!,
      'message': instance.message,
      'store_id': instance.storeId,
      'order_id': instance.orderId,
      'rider_id': instance.riderId,
      'at': instance.at.toIso8601String(),
    };

const _$WsAlertDataCodeEnumEnumMap = {
  WsAlertDataCodeEnum.ACCEPTANCE_SLA_BREACHED: 'ACCEPTANCE_SLA_BREACHED',
  WsAlertDataCodeEnum.LATE_CAPTURE: 'LATE_CAPTURE',
  WsAlertDataCodeEnum.REFUND_FAILED: 'REFUND_FAILED',
  WsAlertDataCodeEnum.DELIVERY_FAILED: 'DELIVERY_FAILED',
  WsAlertDataCodeEnum.DISPATCH_UNASSIGNED: 'DISPATCH_UNASSIGNED',
  WsAlertDataCodeEnum.PICKUP_CODE_LOCKED: 'PICKUP_CODE_LOCKED',
  WsAlertDataCodeEnum.DELIVERY_OTP_LOCKED: 'DELIVERY_OTP_LOCKED',
  WsAlertDataCodeEnum.STOCK_NOT_COMMITTED: 'STOCK_NOT_COMMITTED',
  WsAlertDataCodeEnum.ARRIVAL_GEOFENCE_OVERRIDE: 'ARRIVAL_GEOFENCE_OVERRIDE',
  WsAlertDataCodeEnum.MOCKED_LOCATION: 'MOCKED_LOCATION',
  WsAlertDataCodeEnum.RIDER_STALE_ON_TASK: 'RIDER_STALE_ON_TASK',
  WsAlertDataCodeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
