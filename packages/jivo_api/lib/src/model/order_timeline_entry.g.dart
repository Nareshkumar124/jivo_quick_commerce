// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_timeline_entry.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderTimelineEntryCWProxy {
  OrderTimelineEntry status(OrderStatusEnum status);

  OrderTimelineEntry title(String title);

  OrderTimelineEntry at(DateTime at);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderTimelineEntry(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderTimelineEntry(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderTimelineEntry call({OrderStatusEnum status, String title, DateTime at});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderTimelineEntry.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderTimelineEntry.copyWith.fieldName(...)`
class _$OrderTimelineEntryCWProxyImpl implements _$OrderTimelineEntryCWProxy {
  const _$OrderTimelineEntryCWProxyImpl(this._value);

  final OrderTimelineEntry _value;

  @override
  OrderTimelineEntry status(OrderStatusEnum status) => this(status: status);

  @override
  OrderTimelineEntry title(String title) => this(title: title);

  @override
  OrderTimelineEntry at(DateTime at) => this(at: at);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderTimelineEntry(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderTimelineEntry(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderTimelineEntry call({
    Object? status = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? at = const $CopyWithPlaceholder(),
  }) {
    return OrderTimelineEntry(
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as OrderStatusEnum,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      at: at == const $CopyWithPlaceholder()
          ? _value.at
          // ignore: cast_nullable_to_non_nullable
          : at as DateTime,
    );
  }
}

extension $OrderTimelineEntryCopyWith on OrderTimelineEntry {
  /// Returns a callable class that can be used as follows: `instanceOfOrderTimelineEntry.copyWith(...)` or like so:`instanceOfOrderTimelineEntry.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderTimelineEntryCWProxy get copyWith =>
      _$OrderTimelineEntryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderTimelineEntry _$OrderTimelineEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OrderTimelineEntry', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status', 'title', 'at']);
      final val = OrderTimelineEntry(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$OrderStatusEnumEnumMap,
            v,
            unknownValue: OrderStatusEnum.unknownDefaultOpenApi,
          ),
        ),
        title: $checkedConvert('title', (v) => v as String),
        at: $checkedConvert('at', (v) => DateTime.parse(v as String)),
      );
      return val;
    });

Map<String, dynamic> _$OrderTimelineEntryToJson(OrderTimelineEntry instance) =>
    <String, dynamic>{
      'status': _$OrderStatusEnumEnumMap[instance.status]!,
      'title': instance.title,
      'at': instance.at.toIso8601String(),
    };

const _$OrderStatusEnumEnumMap = {
  OrderStatusEnum.PAYMENT_PENDING: 'PAYMENT_PENDING',
  OrderStatusEnum.PLACED: 'PLACED',
  OrderStatusEnum.ACCEPTED: 'ACCEPTED',
  OrderStatusEnum.PACKING: 'PACKING',
  OrderStatusEnum.PACKED: 'PACKED',
  OrderStatusEnum.OUT_FOR_DELIVERY: 'OUT_FOR_DELIVERY',
  OrderStatusEnum.DELIVERED: 'DELIVERED',
  OrderStatusEnum.CANCELLED: 'CANCELLED',
  OrderStatusEnum.PAYMENT_FAILED: 'PAYMENT_FAILED',
  OrderStatusEnum.DELIVERY_FAILED: 'DELIVERY_FAILED',
  OrderStatusEnum.RETURNED: 'RETURNED',
  OrderStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
