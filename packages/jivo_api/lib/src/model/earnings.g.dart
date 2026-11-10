// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earnings.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EarningsCWProxy {
  Earnings from(DateTime from);

  Earnings to(DateTime to);

  Earnings total(String total);

  Earnings ordersCount(int ordersCount);

  Earnings totalsByType(EarningTotals totalsByType);

  Earnings orders(List<EarningsOrder> orders);

  Earnings ordersTruncated(bool ordersTruncated);

  Earnings adjustments(List<EarningsAdjustment> adjustments);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Earnings(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Earnings(...).copyWith(id: 12, name: "My name")
  /// ````
  Earnings call({
    DateTime from,
    DateTime to,
    String total,
    int ordersCount,
    EarningTotals totalsByType,
    List<EarningsOrder> orders,
    bool ordersTruncated,
    List<EarningsAdjustment> adjustments,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEarnings.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEarnings.copyWith.fieldName(...)`
class _$EarningsCWProxyImpl implements _$EarningsCWProxy {
  const _$EarningsCWProxyImpl(this._value);

  final Earnings _value;

  @override
  Earnings from(DateTime from) => this(from: from);

  @override
  Earnings to(DateTime to) => this(to: to);

  @override
  Earnings total(String total) => this(total: total);

  @override
  Earnings ordersCount(int ordersCount) => this(ordersCount: ordersCount);

  @override
  Earnings totalsByType(EarningTotals totalsByType) =>
      this(totalsByType: totalsByType);

  @override
  Earnings orders(List<EarningsOrder> orders) => this(orders: orders);

  @override
  Earnings ordersTruncated(bool ordersTruncated) =>
      this(ordersTruncated: ordersTruncated);

  @override
  Earnings adjustments(List<EarningsAdjustment> adjustments) =>
      this(adjustments: adjustments);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Earnings(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Earnings(...).copyWith(id: 12, name: "My name")
  /// ````
  Earnings call({
    Object? from = const $CopyWithPlaceholder(),
    Object? to = const $CopyWithPlaceholder(),
    Object? total = const $CopyWithPlaceholder(),
    Object? ordersCount = const $CopyWithPlaceholder(),
    Object? totalsByType = const $CopyWithPlaceholder(),
    Object? orders = const $CopyWithPlaceholder(),
    Object? ordersTruncated = const $CopyWithPlaceholder(),
    Object? adjustments = const $CopyWithPlaceholder(),
  }) {
    return Earnings(
      from: from == const $CopyWithPlaceholder()
          ? _value.from
          // ignore: cast_nullable_to_non_nullable
          : from as DateTime,
      to: to == const $CopyWithPlaceholder()
          ? _value.to
          // ignore: cast_nullable_to_non_nullable
          : to as DateTime,
      total: total == const $CopyWithPlaceholder()
          ? _value.total
          // ignore: cast_nullable_to_non_nullable
          : total as String,
      ordersCount: ordersCount == const $CopyWithPlaceholder()
          ? _value.ordersCount
          // ignore: cast_nullable_to_non_nullable
          : ordersCount as int,
      totalsByType: totalsByType == const $CopyWithPlaceholder()
          ? _value.totalsByType
          // ignore: cast_nullable_to_non_nullable
          : totalsByType as EarningTotals,
      orders: orders == const $CopyWithPlaceholder()
          ? _value.orders
          // ignore: cast_nullable_to_non_nullable
          : orders as List<EarningsOrder>,
      ordersTruncated: ordersTruncated == const $CopyWithPlaceholder()
          ? _value.ordersTruncated
          // ignore: cast_nullable_to_non_nullable
          : ordersTruncated as bool,
      adjustments: adjustments == const $CopyWithPlaceholder()
          ? _value.adjustments
          // ignore: cast_nullable_to_non_nullable
          : adjustments as List<EarningsAdjustment>,
    );
  }
}

extension $EarningsCopyWith on Earnings {
  /// Returns a callable class that can be used as follows: `instanceOfEarnings.copyWith(...)` or like so:`instanceOfEarnings.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EarningsCWProxy get copyWith => _$EarningsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Earnings _$EarningsFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Earnings',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'from',
        'to',
        'total',
        'orders_count',
        'totals_by_type',
        'orders',
        'orders_truncated',
        'adjustments',
      ],
    );
    final val = Earnings(
      from: $checkedConvert('from', (v) => DateTime.parse(v as String)),
      to: $checkedConvert('to', (v) => DateTime.parse(v as String)),
      total: $checkedConvert('total', (v) => v as String),
      ordersCount: $checkedConvert('orders_count', (v) => (v as num).toInt()),
      totalsByType: $checkedConvert(
        'totals_by_type',
        (v) => EarningTotals.fromJson(v as Map<String, dynamic>),
      ),
      orders: $checkedConvert(
        'orders',
        (v) => (v as List<dynamic>)
            .map((e) => EarningsOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      ordersTruncated: $checkedConvert('orders_truncated', (v) => v as bool),
      adjustments: $checkedConvert(
        'adjustments',
        (v) => (v as List<dynamic>)
            .map((e) => EarningsAdjustment.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'ordersCount': 'orders_count',
    'totalsByType': 'totals_by_type',
    'ordersTruncated': 'orders_truncated',
  },
);

Map<String, dynamic> _$EarningsToJson(Earnings instance) => <String, dynamic>{
  'from': jivoDateToJson(instance.from),
  'to': jivoDateToJson(instance.to),
  'total': instance.total,
  'orders_count': instance.ordersCount,
  'totals_by_type': instance.totalsByType.toJson(),
  'orders': instance.orders.map((e) => e.toJson()).toList(),
  'orders_truncated': instance.ordersTruncated,
  'adjustments': instance.adjustments.map((e) => e.toJson()).toList(),
};
