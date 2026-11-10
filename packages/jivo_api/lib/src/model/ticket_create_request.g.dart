// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_create_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TicketCreateRequestCWProxy {
  TicketCreateRequest category(TicketCategoryEnum category);

  TicketCreateRequest message(String message);

  TicketCreateRequest orderId(int? orderId);

  TicketCreateRequest taskId(int? taskId);

  TicketCreateRequest payoutId(int? payoutId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketCreateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketCreateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketCreateRequest call({
    TicketCategoryEnum category,
    String message,
    int? orderId,
    int? taskId,
    int? payoutId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTicketCreateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTicketCreateRequest.copyWith.fieldName(...)`
class _$TicketCreateRequestCWProxyImpl implements _$TicketCreateRequestCWProxy {
  const _$TicketCreateRequestCWProxyImpl(this._value);

  final TicketCreateRequest _value;

  @override
  TicketCreateRequest category(TicketCategoryEnum category) =>
      this(category: category);

  @override
  TicketCreateRequest message(String message) => this(message: message);

  @override
  TicketCreateRequest orderId(int? orderId) => this(orderId: orderId);

  @override
  TicketCreateRequest taskId(int? taskId) => this(taskId: taskId);

  @override
  TicketCreateRequest payoutId(int? payoutId) => this(payoutId: payoutId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketCreateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketCreateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketCreateRequest call({
    Object? category = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? taskId = const $CopyWithPlaceholder(),
    Object? payoutId = const $CopyWithPlaceholder(),
  }) {
    return TicketCreateRequest(
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as TicketCategoryEnum,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int?,
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int?,
      payoutId: payoutId == const $CopyWithPlaceholder()
          ? _value.payoutId
          // ignore: cast_nullable_to_non_nullable
          : payoutId as int?,
    );
  }
}

extension $TicketCreateRequestCopyWith on TicketCreateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfTicketCreateRequest.copyWith(...)` or like so:`instanceOfTicketCreateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TicketCreateRequestCWProxy get copyWith =>
      _$TicketCreateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TicketCreateRequest _$TicketCreateRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TicketCreateRequest',
      json,
      ($checkedConvert) {
        $checkKeys(json, requiredKeys: const ['category', 'message']);
        final val = TicketCreateRequest(
          category: $checkedConvert(
            'category',
            (v) => $enumDecode(
              _$TicketCategoryEnumEnumMap,
              v,
              unknownValue: TicketCategoryEnum.unknownDefaultOpenApi,
            ),
          ),
          message: $checkedConvert('message', (v) => v as String),
          orderId: $checkedConvert('order_id', (v) => (v as num?)?.toInt()),
          taskId: $checkedConvert('task_id', (v) => (v as num?)?.toInt()),
          payoutId: $checkedConvert('payout_id', (v) => (v as num?)?.toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'orderId': 'order_id',
        'taskId': 'task_id',
        'payoutId': 'payout_id',
      },
    );

Map<String, dynamic> _$TicketCreateRequestToJson(
  TicketCreateRequest instance,
) => <String, dynamic>{
  'category': _$TicketCategoryEnumEnumMap[instance.category]!,
  'message': instance.message,
  'order_id': ?instance.orderId,
  'task_id': ?instance.taskId,
  'payout_id': ?instance.payoutId,
};

const _$TicketCategoryEnumEnumMap = {
  TicketCategoryEnum.MISSING_ITEMS: 'MISSING_ITEMS',
  TicketCategoryEnum.DAMAGED_ITEMS: 'DAMAGED_ITEMS',
  TicketCategoryEnum.WRONG_ITEMS: 'WRONG_ITEMS',
  TicketCategoryEnum.LATE_DELIVERY: 'LATE_DELIVERY',
  TicketCategoryEnum.PAYMENT_REFUND: 'PAYMENT_REFUND',
  TicketCategoryEnum.ACCOUNT: 'ACCOUNT',
  TicketCategoryEnum.OTHER: 'OTHER',
  TicketCategoryEnum.TASK: 'TASK',
  TicketCategoryEnum.PAYOUT: 'PAYOUT',
  TicketCategoryEnum.CASH: 'CASH',
  TicketCategoryEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
