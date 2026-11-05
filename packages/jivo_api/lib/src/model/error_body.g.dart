// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ErrorBodyCWProxy {
  ErrorBody code(ErrorCodeEnum code);

  ErrorBody message(String message);

  ErrorBody details(Map<String, Object> details);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorBody call({
    ErrorCodeEnum code,
    String message,
    Map<String, Object> details,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfErrorBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfErrorBody.copyWith.fieldName(...)`
class _$ErrorBodyCWProxyImpl implements _$ErrorBodyCWProxy {
  const _$ErrorBodyCWProxyImpl(this._value);

  final ErrorBody _value;

  @override
  ErrorBody code(ErrorCodeEnum code) => this(code: code);

  @override
  ErrorBody message(String message) => this(message: message);

  @override
  ErrorBody details(Map<String, Object> details) => this(details: details);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorBody call({
    Object? code = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? details = const $CopyWithPlaceholder(),
  }) {
    return ErrorBody(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as ErrorCodeEnum,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      details: details == const $CopyWithPlaceholder()
          ? _value.details
          // ignore: cast_nullable_to_non_nullable
          : details as Map<String, Object>,
    );
  }
}

extension $ErrorBodyCopyWith on ErrorBody {
  /// Returns a callable class that can be used as follows: `instanceOfErrorBody.copyWith(...)` or like so:`instanceOfErrorBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ErrorBodyCWProxy get copyWith => _$ErrorBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorBody _$ErrorBodyFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ErrorBody',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['code', 'message', 'details']);
    final val = ErrorBody(
      code: $checkedConvert(
        'code',
        (v) => $enumDecode(
          _$ErrorCodeEnumEnumMap,
          v,
          unknownValue: ErrorCodeEnum.unknownDefaultOpenApi,
        ),
      ),
      message: $checkedConvert('message', (v) => v as String),
      details: $checkedConvert(
        'details',
        (v) =>
            (v as Map<String, dynamic>).map((k, e) => MapEntry(k, e as Object)),
      ),
    );
    return val;
  },
);

Map<String, dynamic> _$ErrorBodyToJson(ErrorBody instance) => <String, dynamic>{
  'code': _$ErrorCodeEnumEnumMap[instance.code]!,
  'message': instance.message,
  'details': instance.details,
};

const _$ErrorCodeEnumEnumMap = {
  ErrorCodeEnum.VALIDATION_ERROR: 'VALIDATION_ERROR',
  ErrorCodeEnum.OTP_INVALID: 'OTP_INVALID',
  ErrorCodeEnum.OTP_EXPIRED: 'OTP_EXPIRED',
  ErrorCodeEnum.OTP_RATE_LIMITED: 'OTP_RATE_LIMITED',
  ErrorCodeEnum.AUTH_REQUIRED: 'AUTH_REQUIRED',
  ErrorCodeEnum.TOKEN_INVALID: 'TOKEN_INVALID',
  ErrorCodeEnum.PERMISSION_DENIED: 'PERMISSION_DENIED',
  ErrorCodeEnum.NOT_FOUND: 'NOT_FOUND',
  ErrorCodeEnum.APP_UPDATE_REQUIRED: 'APP_UPDATE_REQUIRED',
  ErrorCodeEnum.NOT_SERVICEABLE: 'NOT_SERVICEABLE',
  ErrorCodeEnum.STORE_CLOSED: 'STORE_CLOSED',
  ErrorCodeEnum.STOCK_UNAVAILABLE: 'STOCK_UNAVAILABLE',
  ErrorCodeEnum.MAX_QTY_EXCEEDED: 'MAX_QTY_EXCEEDED',
  ErrorCodeEnum.MIN_ORDER_NOT_MET: 'MIN_ORDER_NOT_MET',
  ErrorCodeEnum.COUPON_INVALID: 'COUPON_INVALID',
  ErrorCodeEnum.COUPON_EXPIRED: 'COUPON_EXPIRED',
  ErrorCodeEnum.COUPON_NOT_ELIGIBLE: 'COUPON_NOT_ELIGIBLE',
  ErrorCodeEnum.COUPON_USAGE_EXCEEDED: 'COUPON_USAGE_EXCEEDED',
  ErrorCodeEnum.COD_NOT_AVAILABLE: 'COD_NOT_AVAILABLE',
  ErrorCodeEnum.PRICE_CHANGED: 'PRICE_CHANGED',
  ErrorCodeEnum.PAYMENT_VERIFICATION_FAILED: 'PAYMENT_VERIFICATION_FAILED',
  ErrorCodeEnum.INVALID_STATE_TRANSITION: 'INVALID_STATE_TRANSITION',
  ErrorCodeEnum.OFFER_EXPIRED: 'OFFER_EXPIRED',
  ErrorCodeEnum.OFFER_TAKEN: 'OFFER_TAKEN',
  ErrorCodeEnum.OUTSIDE_GEOFENCE: 'OUTSIDE_GEOFENCE',
  ErrorCodeEnum.DELIVERY_OTP_INVALID: 'DELIVERY_OTP_INVALID',
  ErrorCodeEnum.DELIVERY_OTP_LOCKED: 'DELIVERY_OTP_LOCKED',
  ErrorCodeEnum.CASH_LIMIT_EXCEEDED: 'CASH_LIMIT_EXCEEDED',
  ErrorCodeEnum.MAINTENANCE: 'MAINTENANCE',
  ErrorCodeEnum.METHOD_NOT_ALLOWED: 'METHOD_NOT_ALLOWED',
  ErrorCodeEnum.NOT_ACCEPTABLE: 'NOT_ACCEPTABLE',
  ErrorCodeEnum.UNSUPPORTED_MEDIA_TYPE: 'UNSUPPORTED_MEDIA_TYPE',
  ErrorCodeEnum.RATE_LIMITED: 'RATE_LIMITED',
  ErrorCodeEnum.SERVER_ERROR: 'SERVER_ERROR',
  ErrorCodeEnum.SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE',
  ErrorCodeEnum.STORE_NOT_FOUND: 'STORE_NOT_FOUND',
  ErrorCodeEnum.PAYLOAD_TOO_LARGE: 'PAYLOAD_TOO_LARGE',
  ErrorCodeEnum.RIDER_OFFLINE: 'RIDER_OFFLINE',
  ErrorCodeEnum.PICKUP_CODE_INVALID: 'PICKUP_CODE_INVALID',
  ErrorCodeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
