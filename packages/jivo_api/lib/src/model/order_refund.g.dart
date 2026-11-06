// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_refund.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderRefundCWProxy {
  OrderRefund id(int id);

  OrderRefund amount(String amount);

  OrderRefund status(OrderRefundStatusEnum status);

  OrderRefund reason(OrderRefundReasonEnum reason);

  OrderRefund createdAt(DateTime createdAt);

  OrderRefund processedAt(DateTime? processedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderRefund(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderRefund(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderRefund call({
    int id,
    String amount,
    OrderRefundStatusEnum status,
    OrderRefundReasonEnum reason,
    DateTime createdAt,
    DateTime? processedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderRefund.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderRefund.copyWith.fieldName(...)`
class _$OrderRefundCWProxyImpl implements _$OrderRefundCWProxy {
  const _$OrderRefundCWProxyImpl(this._value);

  final OrderRefund _value;

  @override
  OrderRefund id(int id) => this(id: id);

  @override
  OrderRefund amount(String amount) => this(amount: amount);

  @override
  OrderRefund status(OrderRefundStatusEnum status) => this(status: status);

  @override
  OrderRefund reason(OrderRefundReasonEnum reason) => this(reason: reason);

  @override
  OrderRefund createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  OrderRefund processedAt(DateTime? processedAt) =>
      this(processedAt: processedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderRefund(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderRefund(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderRefund call({
    Object? id = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? processedAt = const $CopyWithPlaceholder(),
  }) {
    return OrderRefund(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as OrderRefundStatusEnum,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as OrderRefundReasonEnum,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      processedAt: processedAt == const $CopyWithPlaceholder()
          ? _value.processedAt
          // ignore: cast_nullable_to_non_nullable
          : processedAt as DateTime?,
    );
  }
}

extension $OrderRefundCopyWith on OrderRefund {
  /// Returns a callable class that can be used as follows: `instanceOfOrderRefund.copyWith(...)` or like so:`instanceOfOrderRefund.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderRefundCWProxy get copyWith => _$OrderRefundCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderRefund _$OrderRefundFromJson(Map<String, dynamic> json) => $checkedCreate(
  'OrderRefund',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'amount',
        'status',
        'reason',
        'created_at',
        'processed_at',
      ],
    );
    final val = OrderRefund(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      amount: $checkedConvert('amount', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$OrderRefundStatusEnumEnumMap,
          v,
          unknownValue: OrderRefundStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      reason: $checkedConvert(
        'reason',
        (v) => $enumDecode(
          _$OrderRefundReasonEnumEnumMap,
          v,
          unknownValue: OrderRefundReasonEnum.unknownDefaultOpenApi,
        ),
      ),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      processedAt: $checkedConvert(
        'processed_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {'createdAt': 'created_at', 'processedAt': 'processed_at'},
);

Map<String, dynamic> _$OrderRefundToJson(OrderRefund instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'status': _$OrderRefundStatusEnumEnumMap[instance.status]!,
      'reason': _$OrderRefundReasonEnumEnumMap[instance.reason]!,
      'created_at': instance.createdAt.toIso8601String(),
      'processed_at': instance.processedAt?.toIso8601String(),
    };

const _$OrderRefundStatusEnumEnumMap = {
  OrderRefundStatusEnum.PENDING: 'PENDING',
  OrderRefundStatusEnum.PROCESSED: 'PROCESSED',
  OrderRefundStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$OrderRefundReasonEnumEnumMap = {
  OrderRefundReasonEnum.ORDER_CANCELLED: 'ORDER_CANCELLED',
  OrderRefundReasonEnum.ITEMS_UNAVAILABLE: 'ITEMS_UNAVAILABLE',
  OrderRefundReasonEnum.DELIVERY_FAILED: 'DELIVERY_FAILED',
  OrderRefundReasonEnum.PAYMENT_ISSUE: 'PAYMENT_ISSUE',
  OrderRefundReasonEnum.GOODWILL: 'GOODWILL',
  OrderRefundReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
