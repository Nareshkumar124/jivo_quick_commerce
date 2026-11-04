// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_create_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderCreateRequestCWProxy {
  OrderCreateRequest addressId(int addressId);

  OrderCreateRequest paymentMethod(PaymentMethodEnum paymentMethod);

  OrderCreateRequest expectedGrandTotal(String expectedGrandTotal);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderCreateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderCreateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderCreateRequest call({
    int addressId,
    PaymentMethodEnum paymentMethod,
    String expectedGrandTotal,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderCreateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderCreateRequest.copyWith.fieldName(...)`
class _$OrderCreateRequestCWProxyImpl implements _$OrderCreateRequestCWProxy {
  const _$OrderCreateRequestCWProxyImpl(this._value);

  final OrderCreateRequest _value;

  @override
  OrderCreateRequest addressId(int addressId) => this(addressId: addressId);

  @override
  OrderCreateRequest paymentMethod(PaymentMethodEnum paymentMethod) =>
      this(paymentMethod: paymentMethod);

  @override
  OrderCreateRequest expectedGrandTotal(String expectedGrandTotal) =>
      this(expectedGrandTotal: expectedGrandTotal);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderCreateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderCreateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderCreateRequest call({
    Object? addressId = const $CopyWithPlaceholder(),
    Object? paymentMethod = const $CopyWithPlaceholder(),
    Object? expectedGrandTotal = const $CopyWithPlaceholder(),
  }) {
    return OrderCreateRequest(
      addressId: addressId == const $CopyWithPlaceholder()
          ? _value.addressId
          // ignore: cast_nullable_to_non_nullable
          : addressId as int,
      paymentMethod: paymentMethod == const $CopyWithPlaceholder()
          ? _value.paymentMethod
          // ignore: cast_nullable_to_non_nullable
          : paymentMethod as PaymentMethodEnum,
      expectedGrandTotal: expectedGrandTotal == const $CopyWithPlaceholder()
          ? _value.expectedGrandTotal
          // ignore: cast_nullable_to_non_nullable
          : expectedGrandTotal as String,
    );
  }
}

extension $OrderCreateRequestCopyWith on OrderCreateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfOrderCreateRequest.copyWith(...)` or like so:`instanceOfOrderCreateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderCreateRequestCWProxy get copyWith =>
      _$OrderCreateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderCreateRequest _$OrderCreateRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OrderCreateRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'address_id',
            'payment_method',
            'expected_grand_total',
          ],
        );
        final val = OrderCreateRequest(
          addressId: $checkedConvert('address_id', (v) => (v as num).toInt()),
          paymentMethod: $checkedConvert(
            'payment_method',
            (v) => $enumDecode(
              _$PaymentMethodEnumEnumMap,
              v,
              unknownValue: PaymentMethodEnum.unknownDefaultOpenApi,
            ),
          ),
          expectedGrandTotal: $checkedConvert(
            'expected_grand_total',
            (v) => v as String,
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'addressId': 'address_id',
        'paymentMethod': 'payment_method',
        'expectedGrandTotal': 'expected_grand_total',
      },
    );

Map<String, dynamic> _$OrderCreateRequestToJson(OrderCreateRequest instance) =>
    <String, dynamic>{
      'address_id': instance.addressId,
      'payment_method': _$PaymentMethodEnumEnumMap[instance.paymentMethod]!,
      'expected_grand_total': instance.expectedGrandTotal,
    };

const _$PaymentMethodEnumEnumMap = {
  PaymentMethodEnum.ONLINE: 'ONLINE',
  PaymentMethodEnum.COD: 'COD',
  PaymentMethodEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
