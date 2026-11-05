// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_task.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RecentTaskCWProxy {
  RecentTask id(int id);

  RecentTask orderNumber(String orderNumber);

  RecentTask status(DeliveryTaskStatusEnum status);

  RecentTask endedAt(DateTime endedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RecentTask(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RecentTask(...).copyWith(id: 12, name: "My name")
  /// ````
  RecentTask call({
    int id,
    String orderNumber,
    DeliveryTaskStatusEnum status,
    DateTime endedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRecentTask.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRecentTask.copyWith.fieldName(...)`
class _$RecentTaskCWProxyImpl implements _$RecentTaskCWProxy {
  const _$RecentTaskCWProxyImpl(this._value);

  final RecentTask _value;

  @override
  RecentTask id(int id) => this(id: id);

  @override
  RecentTask orderNumber(String orderNumber) => this(orderNumber: orderNumber);

  @override
  RecentTask status(DeliveryTaskStatusEnum status) => this(status: status);

  @override
  RecentTask endedAt(DateTime endedAt) => this(endedAt: endedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RecentTask(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RecentTask(...).copyWith(id: 12, name: "My name")
  /// ````
  RecentTask call({
    Object? id = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? endedAt = const $CopyWithPlaceholder(),
  }) {
    return RecentTask(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as DeliveryTaskStatusEnum,
      endedAt: endedAt == const $CopyWithPlaceholder()
          ? _value.endedAt
          // ignore: cast_nullable_to_non_nullable
          : endedAt as DateTime,
    );
  }
}

extension $RecentTaskCopyWith on RecentTask {
  /// Returns a callable class that can be used as follows: `instanceOfRecentTask.copyWith(...)` or like so:`instanceOfRecentTask.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RecentTaskCWProxy get copyWith => _$RecentTaskCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecentTask _$RecentTaskFromJson(Map<String, dynamic> json) => $checkedCreate(
  'RecentTask',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['id', 'order_number', 'status', 'ended_at'],
    );
    final val = RecentTask(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      orderNumber: $checkedConvert('order_number', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$DeliveryTaskStatusEnumEnumMap,
          v,
          unknownValue: DeliveryTaskStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      endedAt: $checkedConvert('ended_at', (v) => DateTime.parse(v as String)),
    );
    return val;
  },
  fieldKeyMap: const {'orderNumber': 'order_number', 'endedAt': 'ended_at'},
);

Map<String, dynamic> _$RecentTaskToJson(RecentTask instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_number': instance.orderNumber,
      'status': _$DeliveryTaskStatusEnumEnumMap[instance.status]!,
      'ended_at': instance.endedAt.toIso8601String(),
    };

const _$DeliveryTaskStatusEnumEnumMap = {
  DeliveryTaskStatusEnum.SEARCHING: 'SEARCHING',
  DeliveryTaskStatusEnum.OFFERED: 'OFFERED',
  DeliveryTaskStatusEnum.ASSIGNED: 'ASSIGNED',
  DeliveryTaskStatusEnum.AT_STORE: 'AT_STORE',
  DeliveryTaskStatusEnum.PICKED_UP: 'PICKED_UP',
  DeliveryTaskStatusEnum.AT_CUSTOMER: 'AT_CUSTOMER',
  DeliveryTaskStatusEnum.DELIVERED: 'DELIVERED',
  DeliveryTaskStatusEnum.FAILED: 'FAILED',
  DeliveryTaskStatusEnum.RETURNING: 'RETURNING',
  DeliveryTaskStatusEnum.RETURNED: 'RETURNED',
  DeliveryTaskStatusEnum.UNASSIGNED: 'UNASSIGNED',
  DeliveryTaskStatusEnum.CANCELLED: 'CANCELLED',
  DeliveryTaskStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
