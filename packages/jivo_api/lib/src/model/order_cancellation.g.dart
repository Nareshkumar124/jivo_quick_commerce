// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_cancellation.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderCancellationCWProxy {
  OrderCancellation reason(OrderCancelReasonEnum reason);

  OrderCancellation message(String message);

  OrderCancellation cancelledBy(CancelledByEnum cancelledBy);

  OrderCancellation cancelledAt(DateTime cancelledAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderCancellation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderCancellation(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderCancellation call({
    OrderCancelReasonEnum reason,
    String message,
    CancelledByEnum cancelledBy,
    DateTime cancelledAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderCancellation.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderCancellation.copyWith.fieldName(...)`
class _$OrderCancellationCWProxyImpl implements _$OrderCancellationCWProxy {
  const _$OrderCancellationCWProxyImpl(this._value);

  final OrderCancellation _value;

  @override
  OrderCancellation reason(OrderCancelReasonEnum reason) =>
      this(reason: reason);

  @override
  OrderCancellation message(String message) => this(message: message);

  @override
  OrderCancellation cancelledBy(CancelledByEnum cancelledBy) =>
      this(cancelledBy: cancelledBy);

  @override
  OrderCancellation cancelledAt(DateTime cancelledAt) =>
      this(cancelledAt: cancelledAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderCancellation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderCancellation(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderCancellation call({
    Object? reason = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? cancelledBy = const $CopyWithPlaceholder(),
    Object? cancelledAt = const $CopyWithPlaceholder(),
  }) {
    return OrderCancellation(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as OrderCancelReasonEnum,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      cancelledBy: cancelledBy == const $CopyWithPlaceholder()
          ? _value.cancelledBy
          // ignore: cast_nullable_to_non_nullable
          : cancelledBy as CancelledByEnum,
      cancelledAt: cancelledAt == const $CopyWithPlaceholder()
          ? _value.cancelledAt
          // ignore: cast_nullable_to_non_nullable
          : cancelledAt as DateTime,
    );
  }
}

extension $OrderCancellationCopyWith on OrderCancellation {
  /// Returns a callable class that can be used as follows: `instanceOfOrderCancellation.copyWith(...)` or like so:`instanceOfOrderCancellation.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderCancellationCWProxy get copyWith =>
      _$OrderCancellationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderCancellation _$OrderCancellationFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OrderCancellation',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'reason',
            'message',
            'cancelled_by',
            'cancelled_at',
          ],
        );
        final val = OrderCancellation(
          reason: $checkedConvert(
            'reason',
            (v) => $enumDecode(
              _$OrderCancelReasonEnumEnumMap,
              v,
              unknownValue: OrderCancelReasonEnum.unknownDefaultOpenApi,
            ),
          ),
          message: $checkedConvert('message', (v) => v as String),
          cancelledBy: $checkedConvert(
            'cancelled_by',
            (v) => $enumDecode(
              _$CancelledByEnumEnumMap,
              v,
              unknownValue: CancelledByEnum.unknownDefaultOpenApi,
            ),
          ),
          cancelledAt: $checkedConvert(
            'cancelled_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'cancelledBy': 'cancelled_by',
        'cancelledAt': 'cancelled_at',
      },
    );

Map<String, dynamic> _$OrderCancellationToJson(OrderCancellation instance) =>
    <String, dynamic>{
      'reason': _$OrderCancelReasonEnumEnumMap[instance.reason]!,
      'message': instance.message,
      'cancelled_by': _$CancelledByEnumEnumMap[instance.cancelledBy]!,
      'cancelled_at': instance.cancelledAt.toIso8601String(),
    };

const _$OrderCancelReasonEnumEnumMap = {
  OrderCancelReasonEnum.CHANGE_PAYMENT_METHOD: 'CHANGE_PAYMENT_METHOD',
  OrderCancelReasonEnum.PAYMENT_PROBLEM: 'PAYMENT_PROBLEM',
  OrderCancelReasonEnum.ORDERED_BY_MISTAKE: 'ORDERED_BY_MISTAKE',
  OrderCancelReasonEnum.CHANGED_MIND: 'CHANGED_MIND',
  OrderCancelReasonEnum.DELIVERY_TOO_SLOW: 'DELIVERY_TOO_SLOW',
  OrderCancelReasonEnum.OTHER: 'OTHER',
  OrderCancelReasonEnum.ITEMS_UNAVAILABLE: 'ITEMS_UNAVAILABLE',
  OrderCancelReasonEnum.STORE_CLOSING: 'STORE_CLOSING',
  OrderCancelReasonEnum.ADDRESS_ISSUE: 'ADDRESS_ISSUE',
  OrderCancelReasonEnum.CUSTOMER_REQUEST: 'CUSTOMER_REQUEST',
  OrderCancelReasonEnum.SUSPECTED_FRAUD: 'SUSPECTED_FRAUD',
  OrderCancelReasonEnum.NO_RIDER: 'NO_RIDER',
  OrderCancelReasonEnum.OTHER_STAFF: 'OTHER_STAFF',
  OrderCancelReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$CancelledByEnumEnumMap = {
  CancelledByEnum.customer: 'customer',
  CancelledByEnum.store: 'store',
  CancelledByEnum.rider: 'rider',
  CancelledByEnum.ops: 'ops',
  CancelledByEnum.system: 'system',
  CancelledByEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
