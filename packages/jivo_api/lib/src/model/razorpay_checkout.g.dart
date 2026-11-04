// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'razorpay_checkout.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RazorpayCheckoutCWProxy {
  RazorpayCheckout keyId(String keyId);

  RazorpayCheckout orderId(String orderId);

  RazorpayCheckout amount(int amount);

  RazorpayCheckout currency(String currency);

  RazorpayCheckout name(String name);

  RazorpayCheckout description(String description);

  RazorpayCheckout prefill(RazorpayPrefill prefill);

  RazorpayCheckout expiresAt(DateTime expiresAt);

  RazorpayCheckout timeoutSeconds(int timeoutSeconds);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RazorpayCheckout(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RazorpayCheckout(...).copyWith(id: 12, name: "My name")
  /// ````
  RazorpayCheckout call({
    String keyId,
    String orderId,
    int amount,
    String currency,
    String name,
    String description,
    RazorpayPrefill prefill,
    DateTime expiresAt,
    int timeoutSeconds,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRazorpayCheckout.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRazorpayCheckout.copyWith.fieldName(...)`
class _$RazorpayCheckoutCWProxyImpl implements _$RazorpayCheckoutCWProxy {
  const _$RazorpayCheckoutCWProxyImpl(this._value);

  final RazorpayCheckout _value;

  @override
  RazorpayCheckout keyId(String keyId) => this(keyId: keyId);

  @override
  RazorpayCheckout orderId(String orderId) => this(orderId: orderId);

  @override
  RazorpayCheckout amount(int amount) => this(amount: amount);

  @override
  RazorpayCheckout currency(String currency) => this(currency: currency);

  @override
  RazorpayCheckout name(String name) => this(name: name);

  @override
  RazorpayCheckout description(String description) =>
      this(description: description);

  @override
  RazorpayCheckout prefill(RazorpayPrefill prefill) => this(prefill: prefill);

  @override
  RazorpayCheckout expiresAt(DateTime expiresAt) => this(expiresAt: expiresAt);

  @override
  RazorpayCheckout timeoutSeconds(int timeoutSeconds) =>
      this(timeoutSeconds: timeoutSeconds);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RazorpayCheckout(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RazorpayCheckout(...).copyWith(id: 12, name: "My name")
  /// ````
  RazorpayCheckout call({
    Object? keyId = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? prefill = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? timeoutSeconds = const $CopyWithPlaceholder(),
  }) {
    return RazorpayCheckout(
      keyId: keyId == const $CopyWithPlaceholder()
          ? _value.keyId
          // ignore: cast_nullable_to_non_nullable
          : keyId as String,
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as String,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as int,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String,
      prefill: prefill == const $CopyWithPlaceholder()
          ? _value.prefill
          // ignore: cast_nullable_to_non_nullable
          : prefill as RazorpayPrefill,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      timeoutSeconds: timeoutSeconds == const $CopyWithPlaceholder()
          ? _value.timeoutSeconds
          // ignore: cast_nullable_to_non_nullable
          : timeoutSeconds as int,
    );
  }
}

extension $RazorpayCheckoutCopyWith on RazorpayCheckout {
  /// Returns a callable class that can be used as follows: `instanceOfRazorpayCheckout.copyWith(...)` or like so:`instanceOfRazorpayCheckout.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RazorpayCheckoutCWProxy get copyWith => _$RazorpayCheckoutCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RazorpayCheckout _$RazorpayCheckoutFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RazorpayCheckout',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'key_id',
            'order_id',
            'amount',
            'currency',
            'name',
            'description',
            'prefill',
            'expires_at',
            'timeout_seconds',
          ],
        );
        final val = RazorpayCheckout(
          keyId: $checkedConvert('key_id', (v) => v as String),
          orderId: $checkedConvert('order_id', (v) => v as String),
          amount: $checkedConvert('amount', (v) => (v as num).toInt()),
          currency: $checkedConvert('currency', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String),
          description: $checkedConvert('description', (v) => v as String),
          prefill: $checkedConvert(
            'prefill',
            (v) => RazorpayPrefill.fromJson(v as Map<String, dynamic>),
          ),
          expiresAt: $checkedConvert(
            'expires_at',
            (v) => DateTime.parse(v as String),
          ),
          timeoutSeconds: $checkedConvert(
            'timeout_seconds',
            (v) => (v as num).toInt(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'keyId': 'key_id',
        'orderId': 'order_id',
        'expiresAt': 'expires_at',
        'timeoutSeconds': 'timeout_seconds',
      },
    );

Map<String, dynamic> _$RazorpayCheckoutToJson(RazorpayCheckout instance) =>
    <String, dynamic>{
      'key_id': instance.keyId,
      'order_id': instance.orderId,
      'amount': instance.amount,
      'currency': instance.currency,
      'name': instance.name,
      'description': instance.description,
      'prefill': instance.prefill.toJson(),
      'expires_at': instance.expiresAt.toIso8601String(),
      'timeout_seconds': instance.timeoutSeconds,
    };
