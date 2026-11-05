// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pickup_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PickupRequestCWProxy {
  PickupRequest orderCode(String orderCode);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PickupRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PickupRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PickupRequest call({String orderCode});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPickupRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPickupRequest.copyWith.fieldName(...)`
class _$PickupRequestCWProxyImpl implements _$PickupRequestCWProxy {
  const _$PickupRequestCWProxyImpl(this._value);

  final PickupRequest _value;

  @override
  PickupRequest orderCode(String orderCode) => this(orderCode: orderCode);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PickupRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PickupRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PickupRequest call({Object? orderCode = const $CopyWithPlaceholder()}) {
    return PickupRequest(
      orderCode: orderCode == const $CopyWithPlaceholder()
          ? _value.orderCode
          // ignore: cast_nullable_to_non_nullable
          : orderCode as String,
    );
  }
}

extension $PickupRequestCopyWith on PickupRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPickupRequest.copyWith(...)` or like so:`instanceOfPickupRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PickupRequestCWProxy get copyWith => _$PickupRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PickupRequest _$PickupRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PickupRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['order_code']);
      final val = PickupRequest(
        orderCode: $checkedConvert('order_code', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'orderCode': 'order_code'});

Map<String, dynamic> _$PickupRequestToJson(PickupRequest instance) =>
    <String, dynamic>{'order_code': instance.orderCode};
