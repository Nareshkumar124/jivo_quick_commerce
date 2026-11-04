// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_cancel_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderCancelRequestCWProxy {
  OrderCancelRequest reason(CancelReasonEnum reason);

  OrderCancelRequest note(String? note);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderCancelRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderCancelRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderCancelRequest call({CancelReasonEnum reason, String? note});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderCancelRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderCancelRequest.copyWith.fieldName(...)`
class _$OrderCancelRequestCWProxyImpl implements _$OrderCancelRequestCWProxy {
  const _$OrderCancelRequestCWProxyImpl(this._value);

  final OrderCancelRequest _value;

  @override
  OrderCancelRequest reason(CancelReasonEnum reason) => this(reason: reason);

  @override
  OrderCancelRequest note(String? note) => this(note: note);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderCancelRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderCancelRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderCancelRequest call({
    Object? reason = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
  }) {
    return OrderCancelRequest(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as CancelReasonEnum,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String?,
    );
  }
}

extension $OrderCancelRequestCopyWith on OrderCancelRequest {
  /// Returns a callable class that can be used as follows: `instanceOfOrderCancelRequest.copyWith(...)` or like so:`instanceOfOrderCancelRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderCancelRequestCWProxy get copyWith =>
      _$OrderCancelRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderCancelRequest _$OrderCancelRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OrderCancelRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['reason']);
      final val = OrderCancelRequest(
        reason: $checkedConvert(
          'reason',
          (v) => $enumDecode(
            _$CancelReasonEnumEnumMap,
            v,
            unknownValue: CancelReasonEnum.unknownDefaultOpenApi,
          ),
        ),
        note: $checkedConvert('note', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$OrderCancelRequestToJson(OrderCancelRequest instance) =>
    <String, dynamic>{
      'reason': _$CancelReasonEnumEnumMap[instance.reason]!,
      'note': ?instance.note,
    };

const _$CancelReasonEnumEnumMap = {
  CancelReasonEnum.CHANGE_PAYMENT_METHOD: 'CHANGE_PAYMENT_METHOD',
  CancelReasonEnum.PAYMENT_PROBLEM: 'PAYMENT_PROBLEM',
  CancelReasonEnum.ORDERED_BY_MISTAKE: 'ORDERED_BY_MISTAKE',
  CancelReasonEnum.CHANGED_MIND: 'CHANGED_MIND',
  CancelReasonEnum.DELIVERY_TOO_SLOW: 'DELIVERY_TOO_SLOW',
  CancelReasonEnum.OTHER: 'OTHER',
  CancelReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
