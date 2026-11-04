// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkout_blocker.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CheckoutBlockerCWProxy {
  CheckoutBlocker code(CheckoutBlockerCodeEnum code);

  CheckoutBlocker message(String message);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CheckoutBlocker(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CheckoutBlocker(...).copyWith(id: 12, name: "My name")
  /// ````
  CheckoutBlocker call({CheckoutBlockerCodeEnum code, String message});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCheckoutBlocker.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCheckoutBlocker.copyWith.fieldName(...)`
class _$CheckoutBlockerCWProxyImpl implements _$CheckoutBlockerCWProxy {
  const _$CheckoutBlockerCWProxyImpl(this._value);

  final CheckoutBlocker _value;

  @override
  CheckoutBlocker code(CheckoutBlockerCodeEnum code) => this(code: code);

  @override
  CheckoutBlocker message(String message) => this(message: message);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CheckoutBlocker(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CheckoutBlocker(...).copyWith(id: 12, name: "My name")
  /// ````
  CheckoutBlocker call({
    Object? code = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
  }) {
    return CheckoutBlocker(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as CheckoutBlockerCodeEnum,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
    );
  }
}

extension $CheckoutBlockerCopyWith on CheckoutBlocker {
  /// Returns a callable class that can be used as follows: `instanceOfCheckoutBlocker.copyWith(...)` or like so:`instanceOfCheckoutBlocker.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CheckoutBlockerCWProxy get copyWith => _$CheckoutBlockerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CheckoutBlocker _$CheckoutBlockerFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CheckoutBlocker', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['code', 'message']);
      final val = CheckoutBlocker(
        code: $checkedConvert(
          'code',
          (v) => $enumDecode(
            _$CheckoutBlockerCodeEnumEnumMap,
            v,
            unknownValue: CheckoutBlockerCodeEnum.unknownDefaultOpenApi,
          ),
        ),
        message: $checkedConvert('message', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$CheckoutBlockerToJson(CheckoutBlocker instance) =>
    <String, dynamic>{
      'code': _$CheckoutBlockerCodeEnumEnumMap[instance.code]!,
      'message': instance.message,
    };

const _$CheckoutBlockerCodeEnumEnumMap = {
  CheckoutBlockerCodeEnum.CART_EMPTY: 'CART_EMPTY',
  CheckoutBlockerCodeEnum.ADDRESS_REQUIRED: 'ADDRESS_REQUIRED',
  CheckoutBlockerCodeEnum.NOT_SERVICEABLE: 'NOT_SERVICEABLE',
  CheckoutBlockerCodeEnum.STORE_CLOSED: 'STORE_CLOSED',
  CheckoutBlockerCodeEnum.STOCK_UNAVAILABLE: 'STOCK_UNAVAILABLE',
  CheckoutBlockerCodeEnum.MIN_ORDER_NOT_MET: 'MIN_ORDER_NOT_MET',
  CheckoutBlockerCodeEnum.COUPON_INVALID: 'COUPON_INVALID',
  CheckoutBlockerCodeEnum.COUPON_EXPIRED: 'COUPON_EXPIRED',
  CheckoutBlockerCodeEnum.COUPON_NOT_ELIGIBLE: 'COUPON_NOT_ELIGIBLE',
  CheckoutBlockerCodeEnum.COUPON_USAGE_EXCEEDED: 'COUPON_USAGE_EXCEEDED',
  CheckoutBlockerCodeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
