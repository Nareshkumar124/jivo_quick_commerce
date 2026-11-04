// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_option.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaymentOptionCWProxy {
  PaymentOption method(PaymentMethodEnum method);

  PaymentOption isAvailable(bool isAvailable);

  PaymentOption unavailableReason(
    PaymentUnavailableReasonEnum? unavailableReason,
  );

  PaymentOption message(String? message);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaymentOption(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaymentOption(...).copyWith(id: 12, name: "My name")
  /// ````
  PaymentOption call({
    PaymentMethodEnum method,
    bool isAvailable,
    PaymentUnavailableReasonEnum? unavailableReason,
    String? message,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaymentOption.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaymentOption.copyWith.fieldName(...)`
class _$PaymentOptionCWProxyImpl implements _$PaymentOptionCWProxy {
  const _$PaymentOptionCWProxyImpl(this._value);

  final PaymentOption _value;

  @override
  PaymentOption method(PaymentMethodEnum method) => this(method: method);

  @override
  PaymentOption isAvailable(bool isAvailable) => this(isAvailable: isAvailable);

  @override
  PaymentOption unavailableReason(
    PaymentUnavailableReasonEnum? unavailableReason,
  ) => this(unavailableReason: unavailableReason);

  @override
  PaymentOption message(String? message) => this(message: message);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaymentOption(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaymentOption(...).copyWith(id: 12, name: "My name")
  /// ````
  PaymentOption call({
    Object? method = const $CopyWithPlaceholder(),
    Object? isAvailable = const $CopyWithPlaceholder(),
    Object? unavailableReason = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
  }) {
    return PaymentOption(
      method: method == const $CopyWithPlaceholder()
          ? _value.method
          // ignore: cast_nullable_to_non_nullable
          : method as PaymentMethodEnum,
      isAvailable: isAvailable == const $CopyWithPlaceholder()
          ? _value.isAvailable
          // ignore: cast_nullable_to_non_nullable
          : isAvailable as bool,
      unavailableReason: unavailableReason == const $CopyWithPlaceholder()
          ? _value.unavailableReason
          // ignore: cast_nullable_to_non_nullable
          : unavailableReason as PaymentUnavailableReasonEnum?,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String?,
    );
  }
}

extension $PaymentOptionCopyWith on PaymentOption {
  /// Returns a callable class that can be used as follows: `instanceOfPaymentOption.copyWith(...)` or like so:`instanceOfPaymentOption.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaymentOptionCWProxy get copyWith => _$PaymentOptionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentOption _$PaymentOptionFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PaymentOption',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'method',
            'is_available',
            'unavailable_reason',
            'message',
          ],
        );
        final val = PaymentOption(
          method: $checkedConvert(
            'method',
            (v) => $enumDecode(
              _$PaymentMethodEnumEnumMap,
              v,
              unknownValue: PaymentMethodEnum.unknownDefaultOpenApi,
            ),
          ),
          isAvailable: $checkedConvert('is_available', (v) => v as bool),
          unavailableReason: $checkedConvert(
            'unavailable_reason',
            (v) => $enumDecodeNullable(
              _$PaymentUnavailableReasonEnumEnumMap,
              v,
              unknownValue: PaymentUnavailableReasonEnum.unknownDefaultOpenApi,
            ),
          ),
          message: $checkedConvert('message', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'isAvailable': 'is_available',
        'unavailableReason': 'unavailable_reason',
      },
    );

Map<String, dynamic> _$PaymentOptionToJson(PaymentOption instance) =>
    <String, dynamic>{
      'method': _$PaymentMethodEnumEnumMap[instance.method]!,
      'is_available': instance.isAvailable,
      'unavailable_reason':
          _$PaymentUnavailableReasonEnumEnumMap[instance.unavailableReason],
      'message': instance.message,
    };

const _$PaymentMethodEnumEnumMap = {
  PaymentMethodEnum.ONLINE: 'ONLINE',
  PaymentMethodEnum.COD: 'COD',
  PaymentMethodEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$PaymentUnavailableReasonEnumEnumMap = {
  PaymentUnavailableReasonEnum.COD_DISABLED: 'COD_DISABLED',
  PaymentUnavailableReasonEnum.ABOVE_LIMIT: 'ABOVE_LIMIT',
  PaymentUnavailableReasonEnum.NOT_ALLOWED: 'NOT_ALLOWED',
  PaymentUnavailableReasonEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
