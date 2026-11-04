// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_thresholds.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CartThresholdsCWProxy {
  CartThresholds minOrderValue(String minOrderValue);

  CartThresholds amountToMinOrder(String? amountToMinOrder);

  CartThresholds freeDeliveryThreshold(String? freeDeliveryThreshold);

  CartThresholds amountToFreeDelivery(String? amountToFreeDelivery);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartThresholds(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartThresholds(...).copyWith(id: 12, name: "My name")
  /// ````
  CartThresholds call({
    String minOrderValue,
    String? amountToMinOrder,
    String? freeDeliveryThreshold,
    String? amountToFreeDelivery,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCartThresholds.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCartThresholds.copyWith.fieldName(...)`
class _$CartThresholdsCWProxyImpl implements _$CartThresholdsCWProxy {
  const _$CartThresholdsCWProxyImpl(this._value);

  final CartThresholds _value;

  @override
  CartThresholds minOrderValue(String minOrderValue) =>
      this(minOrderValue: minOrderValue);

  @override
  CartThresholds amountToMinOrder(String? amountToMinOrder) =>
      this(amountToMinOrder: amountToMinOrder);

  @override
  CartThresholds freeDeliveryThreshold(String? freeDeliveryThreshold) =>
      this(freeDeliveryThreshold: freeDeliveryThreshold);

  @override
  CartThresholds amountToFreeDelivery(String? amountToFreeDelivery) =>
      this(amountToFreeDelivery: amountToFreeDelivery);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartThresholds(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartThresholds(...).copyWith(id: 12, name: "My name")
  /// ````
  CartThresholds call({
    Object? minOrderValue = const $CopyWithPlaceholder(),
    Object? amountToMinOrder = const $CopyWithPlaceholder(),
    Object? freeDeliveryThreshold = const $CopyWithPlaceholder(),
    Object? amountToFreeDelivery = const $CopyWithPlaceholder(),
  }) {
    return CartThresholds(
      minOrderValue: minOrderValue == const $CopyWithPlaceholder()
          ? _value.minOrderValue
          // ignore: cast_nullable_to_non_nullable
          : minOrderValue as String,
      amountToMinOrder: amountToMinOrder == const $CopyWithPlaceholder()
          ? _value.amountToMinOrder
          // ignore: cast_nullable_to_non_nullable
          : amountToMinOrder as String?,
      freeDeliveryThreshold:
          freeDeliveryThreshold == const $CopyWithPlaceholder()
          ? _value.freeDeliveryThreshold
          // ignore: cast_nullable_to_non_nullable
          : freeDeliveryThreshold as String?,
      amountToFreeDelivery: amountToFreeDelivery == const $CopyWithPlaceholder()
          ? _value.amountToFreeDelivery
          // ignore: cast_nullable_to_non_nullable
          : amountToFreeDelivery as String?,
    );
  }
}

extension $CartThresholdsCopyWith on CartThresholds {
  /// Returns a callable class that can be used as follows: `instanceOfCartThresholds.copyWith(...)` or like so:`instanceOfCartThresholds.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CartThresholdsCWProxy get copyWith => _$CartThresholdsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartThresholds _$CartThresholdsFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CartThresholds',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'min_order_value',
            'amount_to_min_order',
            'free_delivery_threshold',
            'amount_to_free_delivery',
          ],
        );
        final val = CartThresholds(
          minOrderValue: $checkedConvert('min_order_value', (v) => v as String),
          amountToMinOrder: $checkedConvert(
            'amount_to_min_order',
            (v) => v as String?,
          ),
          freeDeliveryThreshold: $checkedConvert(
            'free_delivery_threshold',
            (v) => v as String?,
          ),
          amountToFreeDelivery: $checkedConvert(
            'amount_to_free_delivery',
            (v) => v as String?,
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'minOrderValue': 'min_order_value',
        'amountToMinOrder': 'amount_to_min_order',
        'freeDeliveryThreshold': 'free_delivery_threshold',
        'amountToFreeDelivery': 'amount_to_free_delivery',
      },
    );

Map<String, dynamic> _$CartThresholdsToJson(CartThresholds instance) =>
    <String, dynamic>{
      'min_order_value': instance.minOrderValue,
      'amount_to_min_order': instance.amountToMinOrder,
      'free_delivery_threshold': instance.freeDeliveryThreshold,
      'amount_to_free_delivery': instance.amountToFreeDelivery,
    };
