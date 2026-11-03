// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkout_status.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CheckoutStatusCWProxy {
  CheckoutStatus canPlaceOrder(bool canPlaceOrder);

  CheckoutStatus blockers(List<CheckoutBlocker> blockers);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CheckoutStatus(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CheckoutStatus(...).copyWith(id: 12, name: "My name")
  /// ````
  CheckoutStatus call({bool canPlaceOrder, List<CheckoutBlocker> blockers});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCheckoutStatus.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCheckoutStatus.copyWith.fieldName(...)`
class _$CheckoutStatusCWProxyImpl implements _$CheckoutStatusCWProxy {
  const _$CheckoutStatusCWProxyImpl(this._value);

  final CheckoutStatus _value;

  @override
  CheckoutStatus canPlaceOrder(bool canPlaceOrder) =>
      this(canPlaceOrder: canPlaceOrder);

  @override
  CheckoutStatus blockers(List<CheckoutBlocker> blockers) =>
      this(blockers: blockers);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CheckoutStatus(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CheckoutStatus(...).copyWith(id: 12, name: "My name")
  /// ````
  CheckoutStatus call({
    Object? canPlaceOrder = const $CopyWithPlaceholder(),
    Object? blockers = const $CopyWithPlaceholder(),
  }) {
    return CheckoutStatus(
      canPlaceOrder: canPlaceOrder == const $CopyWithPlaceholder()
          ? _value.canPlaceOrder
          // ignore: cast_nullable_to_non_nullable
          : canPlaceOrder as bool,
      blockers: blockers == const $CopyWithPlaceholder()
          ? _value.blockers
          // ignore: cast_nullable_to_non_nullable
          : blockers as List<CheckoutBlocker>,
    );
  }
}

extension $CheckoutStatusCopyWith on CheckoutStatus {
  /// Returns a callable class that can be used as follows: `instanceOfCheckoutStatus.copyWith(...)` or like so:`instanceOfCheckoutStatus.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CheckoutStatusCWProxy get copyWith => _$CheckoutStatusCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CheckoutStatus _$CheckoutStatusFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CheckoutStatus', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['can_place_order', 'blockers']);
      final val = CheckoutStatus(
        canPlaceOrder: $checkedConvert('can_place_order', (v) => v as bool),
        blockers: $checkedConvert(
          'blockers',
          (v) => (v as List<dynamic>)
              .map((e) => CheckoutBlocker.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'canPlaceOrder': 'can_place_order'});

Map<String, dynamic> _$CheckoutStatusToJson(CheckoutStatus instance) =>
    <String, dynamic>{
      'can_place_order': instance.canPlaceOrder,
      'blockers': instance.blockers.map((e) => e.toJson()).toList(),
    };
