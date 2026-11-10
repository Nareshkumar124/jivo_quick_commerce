// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_order_eta_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOrderEtaDataCWProxy {
  WsOrderEtaData orderId(int orderId);

  WsOrderEtaData etaAt(DateTime etaAt);

  WsOrderEtaData etaMinutes(int etaMinutes);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderEtaData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderEtaData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderEtaData call({int orderId, DateTime etaAt, int etaMinutes});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOrderEtaData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOrderEtaData.copyWith.fieldName(...)`
class _$WsOrderEtaDataCWProxyImpl implements _$WsOrderEtaDataCWProxy {
  const _$WsOrderEtaDataCWProxyImpl(this._value);

  final WsOrderEtaData _value;

  @override
  WsOrderEtaData orderId(int orderId) => this(orderId: orderId);

  @override
  WsOrderEtaData etaAt(DateTime etaAt) => this(etaAt: etaAt);

  @override
  WsOrderEtaData etaMinutes(int etaMinutes) => this(etaMinutes: etaMinutes);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderEtaData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderEtaData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderEtaData call({
    Object? orderId = const $CopyWithPlaceholder(),
    Object? etaAt = const $CopyWithPlaceholder(),
    Object? etaMinutes = const $CopyWithPlaceholder(),
  }) {
    return WsOrderEtaData(
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int,
      etaAt: etaAt == const $CopyWithPlaceholder()
          ? _value.etaAt
          // ignore: cast_nullable_to_non_nullable
          : etaAt as DateTime,
      etaMinutes: etaMinutes == const $CopyWithPlaceholder()
          ? _value.etaMinutes
          // ignore: cast_nullable_to_non_nullable
          : etaMinutes as int,
    );
  }
}

extension $WsOrderEtaDataCopyWith on WsOrderEtaData {
  /// Returns a callable class that can be used as follows: `instanceOfWsOrderEtaData.copyWith(...)` or like so:`instanceOfWsOrderEtaData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOrderEtaDataCWProxy get copyWith => _$WsOrderEtaDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOrderEtaData _$WsOrderEtaDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WsOrderEtaData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['order_id', 'eta_at', 'eta_minutes'],
        );
        final val = WsOrderEtaData(
          orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
          etaAt: $checkedConvert('eta_at', (v) => DateTime.parse(v as String)),
          etaMinutes: $checkedConvert('eta_minutes', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'orderId': 'order_id',
        'etaAt': 'eta_at',
        'etaMinutes': 'eta_minutes',
      },
    );

Map<String, dynamic> _$WsOrderEtaDataToJson(WsOrderEtaData instance) =>
    <String, dynamic>{
      'order_id': instance.orderId,
      'eta_at': instance.etaAt.toIso8601String(),
      'eta_minutes': instance.etaMinutes,
    };
