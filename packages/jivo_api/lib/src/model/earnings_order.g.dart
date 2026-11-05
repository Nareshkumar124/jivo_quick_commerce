// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earnings_order.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EarningsOrderCWProxy {
  EarningsOrder taskId(int taskId);

  EarningsOrder orderNumber(String orderNumber);

  EarningsOrder completedAt(DateTime completedAt);

  EarningsOrder total(String total);

  EarningsOrder lines(List<EarningLine> lines);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EarningsOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EarningsOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  EarningsOrder call({
    int taskId,
    String orderNumber,
    DateTime completedAt,
    String total,
    List<EarningLine> lines,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEarningsOrder.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEarningsOrder.copyWith.fieldName(...)`
class _$EarningsOrderCWProxyImpl implements _$EarningsOrderCWProxy {
  const _$EarningsOrderCWProxyImpl(this._value);

  final EarningsOrder _value;

  @override
  EarningsOrder taskId(int taskId) => this(taskId: taskId);

  @override
  EarningsOrder orderNumber(String orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  EarningsOrder completedAt(DateTime completedAt) =>
      this(completedAt: completedAt);

  @override
  EarningsOrder total(String total) => this(total: total);

  @override
  EarningsOrder lines(List<EarningLine> lines) => this(lines: lines);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EarningsOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EarningsOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  EarningsOrder call({
    Object? taskId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? completedAt = const $CopyWithPlaceholder(),
    Object? total = const $CopyWithPlaceholder(),
    Object? lines = const $CopyWithPlaceholder(),
  }) {
    return EarningsOrder(
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String,
      completedAt: completedAt == const $CopyWithPlaceholder()
          ? _value.completedAt
          // ignore: cast_nullable_to_non_nullable
          : completedAt as DateTime,
      total: total == const $CopyWithPlaceholder()
          ? _value.total
          // ignore: cast_nullable_to_non_nullable
          : total as String,
      lines: lines == const $CopyWithPlaceholder()
          ? _value.lines
          // ignore: cast_nullable_to_non_nullable
          : lines as List<EarningLine>,
    );
  }
}

extension $EarningsOrderCopyWith on EarningsOrder {
  /// Returns a callable class that can be used as follows: `instanceOfEarningsOrder.copyWith(...)` or like so:`instanceOfEarningsOrder.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EarningsOrderCWProxy get copyWith => _$EarningsOrderCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EarningsOrder _$EarningsOrderFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'EarningsOrder',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'task_id',
            'order_number',
            'completed_at',
            'total',
            'lines',
          ],
        );
        final val = EarningsOrder(
          taskId: $checkedConvert('task_id', (v) => (v as num).toInt()),
          orderNumber: $checkedConvert('order_number', (v) => v as String),
          completedAt: $checkedConvert(
            'completed_at',
            (v) => DateTime.parse(v as String),
          ),
          total: $checkedConvert('total', (v) => v as String),
          lines: $checkedConvert(
            'lines',
            (v) => (v as List<dynamic>)
                .map((e) => EarningLine.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'taskId': 'task_id',
        'orderNumber': 'order_number',
        'completedAt': 'completed_at',
      },
    );

Map<String, dynamic> _$EarningsOrderToJson(EarningsOrder instance) =>
    <String, dynamic>{
      'task_id': instance.taskId,
      'order_number': instance.orderNumber,
      'completed_at': instance.completedAt.toIso8601String(),
      'total': instance.total,
      'lines': instance.lines.map((e) => e.toJson()).toList(),
    };
