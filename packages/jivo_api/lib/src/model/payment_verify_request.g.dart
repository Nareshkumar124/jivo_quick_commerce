// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_verify_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaymentVerifyRequestCWProxy {
  PaymentVerifyRequest orderId(int orderId);

  PaymentVerifyRequest razorpayOrderId(String razorpayOrderId);

  PaymentVerifyRequest razorpayPaymentId(String razorpayPaymentId);

  PaymentVerifyRequest razorpaySignature(String razorpaySignature);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaymentVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaymentVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PaymentVerifyRequest call({
    int orderId,
    String razorpayOrderId,
    String razorpayPaymentId,
    String razorpaySignature,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaymentVerifyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaymentVerifyRequest.copyWith.fieldName(...)`
class _$PaymentVerifyRequestCWProxyImpl
    implements _$PaymentVerifyRequestCWProxy {
  const _$PaymentVerifyRequestCWProxyImpl(this._value);

  final PaymentVerifyRequest _value;

  @override
  PaymentVerifyRequest orderId(int orderId) => this(orderId: orderId);

  @override
  PaymentVerifyRequest razorpayOrderId(String razorpayOrderId) =>
      this(razorpayOrderId: razorpayOrderId);

  @override
  PaymentVerifyRequest razorpayPaymentId(String razorpayPaymentId) =>
      this(razorpayPaymentId: razorpayPaymentId);

  @override
  PaymentVerifyRequest razorpaySignature(String razorpaySignature) =>
      this(razorpaySignature: razorpaySignature);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaymentVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaymentVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PaymentVerifyRequest call({
    Object? orderId = const $CopyWithPlaceholder(),
    Object? razorpayOrderId = const $CopyWithPlaceholder(),
    Object? razorpayPaymentId = const $CopyWithPlaceholder(),
    Object? razorpaySignature = const $CopyWithPlaceholder(),
  }) {
    return PaymentVerifyRequest(
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int,
      razorpayOrderId: razorpayOrderId == const $CopyWithPlaceholder()
          ? _value.razorpayOrderId
          // ignore: cast_nullable_to_non_nullable
          : razorpayOrderId as String,
      razorpayPaymentId: razorpayPaymentId == const $CopyWithPlaceholder()
          ? _value.razorpayPaymentId
          // ignore: cast_nullable_to_non_nullable
          : razorpayPaymentId as String,
      razorpaySignature: razorpaySignature == const $CopyWithPlaceholder()
          ? _value.razorpaySignature
          // ignore: cast_nullable_to_non_nullable
          : razorpaySignature as String,
    );
  }
}

extension $PaymentVerifyRequestCopyWith on PaymentVerifyRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPaymentVerifyRequest.copyWith(...)` or like so:`instanceOfPaymentVerifyRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaymentVerifyRequestCWProxy get copyWith =>
      _$PaymentVerifyRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentVerifyRequest _$PaymentVerifyRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PaymentVerifyRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'order_id',
        'razorpay_order_id',
        'razorpay_payment_id',
        'razorpay_signature',
      ],
    );
    final val = PaymentVerifyRequest(
      orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
      razorpayOrderId: $checkedConvert('razorpay_order_id', (v) => v as String),
      razorpayPaymentId: $checkedConvert(
        'razorpay_payment_id',
        (v) => v as String,
      ),
      razorpaySignature: $checkedConvert(
        'razorpay_signature',
        (v) => v as String,
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'orderId': 'order_id',
    'razorpayOrderId': 'razorpay_order_id',
    'razorpayPaymentId': 'razorpay_payment_id',
    'razorpaySignature': 'razorpay_signature',
  },
);

Map<String, dynamic> _$PaymentVerifyRequestToJson(
  PaymentVerifyRequest instance,
) => <String, dynamic>{
  'order_id': instance.orderId,
  'razorpay_order_id': instance.razorpayOrderId,
  'razorpay_payment_id': instance.razorpayPaymentId,
  'razorpay_signature': instance.razorpaySignature,
};
