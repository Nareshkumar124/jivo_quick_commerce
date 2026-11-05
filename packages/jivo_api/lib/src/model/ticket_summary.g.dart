// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TicketSummaryCWProxy {
  TicketSummary id(int id);

  TicketSummary number(String number);

  TicketSummary category(TicketCategoryEnum category);

  TicketSummary status(TicketStatusEnum status);

  TicketSummary orderId(int? orderId);

  TicketSummary orderNumber(String? orderNumber);

  TicketSummary lastMessage(String? lastMessage);

  TicketSummary createdAt(DateTime createdAt);

  TicketSummary updatedAt(DateTime updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketSummary call({
    int id,
    String number,
    TicketCategoryEnum category,
    TicketStatusEnum status,
    int? orderId,
    String? orderNumber,
    String? lastMessage,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTicketSummary.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTicketSummary.copyWith.fieldName(...)`
class _$TicketSummaryCWProxyImpl implements _$TicketSummaryCWProxy {
  const _$TicketSummaryCWProxyImpl(this._value);

  final TicketSummary _value;

  @override
  TicketSummary id(int id) => this(id: id);

  @override
  TicketSummary number(String number) => this(number: number);

  @override
  TicketSummary category(TicketCategoryEnum category) =>
      this(category: category);

  @override
  TicketSummary status(TicketStatusEnum status) => this(status: status);

  @override
  TicketSummary orderId(int? orderId) => this(orderId: orderId);

  @override
  TicketSummary orderNumber(String? orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  TicketSummary lastMessage(String? lastMessage) =>
      this(lastMessage: lastMessage);

  @override
  TicketSummary createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  TicketSummary updatedAt(DateTime updatedAt) => this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketSummary call({
    Object? id = const $CopyWithPlaceholder(),
    Object? number = const $CopyWithPlaceholder(),
    Object? category = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? lastMessage = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return TicketSummary(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      number: number == const $CopyWithPlaceholder()
          ? _value.number
          // ignore: cast_nullable_to_non_nullable
          : number as String,
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as TicketCategoryEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as TicketStatusEnum,
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int?,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String?,
      lastMessage: lastMessage == const $CopyWithPlaceholder()
          ? _value.lastMessage
          // ignore: cast_nullable_to_non_nullable
          : lastMessage as String?,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $TicketSummaryCopyWith on TicketSummary {
  /// Returns a callable class that can be used as follows: `instanceOfTicketSummary.copyWith(...)` or like so:`instanceOfTicketSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TicketSummaryCWProxy get copyWith => _$TicketSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TicketSummary _$TicketSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TicketSummary',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'number',
            'category',
            'status',
            'order_id',
            'order_number',
            'last_message',
            'created_at',
            'updated_at',
          ],
        );
        final val = TicketSummary(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          number: $checkedConvert('number', (v) => v as String),
          category: $checkedConvert(
            'category',
            (v) => $enumDecode(
              _$TicketCategoryEnumEnumMap,
              v,
              unknownValue: TicketCategoryEnum.unknownDefaultOpenApi,
            ),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$TicketStatusEnumEnumMap,
              v,
              unknownValue: TicketStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          orderId: $checkedConvert('order_id', (v) => (v as num?)?.toInt()),
          orderNumber: $checkedConvert('order_number', (v) => v as String?),
          lastMessage: $checkedConvert('last_message', (v) => v as String?),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'orderId': 'order_id',
        'orderNumber': 'order_number',
        'lastMessage': 'last_message',
        'createdAt': 'created_at',
        'updatedAt': 'updated_at',
      },
    );

Map<String, dynamic> _$TicketSummaryToJson(TicketSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'category': _$TicketCategoryEnumEnumMap[instance.category]!,
      'status': _$TicketStatusEnumEnumMap[instance.status]!,
      'order_id': instance.orderId,
      'order_number': instance.orderNumber,
      'last_message': instance.lastMessage,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$TicketCategoryEnumEnumMap = {
  TicketCategoryEnum.MISSING_ITEMS: 'MISSING_ITEMS',
  TicketCategoryEnum.DAMAGED_ITEMS: 'DAMAGED_ITEMS',
  TicketCategoryEnum.WRONG_ITEMS: 'WRONG_ITEMS',
  TicketCategoryEnum.LATE_DELIVERY: 'LATE_DELIVERY',
  TicketCategoryEnum.PAYMENT_REFUND: 'PAYMENT_REFUND',
  TicketCategoryEnum.ACCOUNT: 'ACCOUNT',
  TicketCategoryEnum.OTHER: 'OTHER',
  TicketCategoryEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$TicketStatusEnumEnumMap = {
  TicketStatusEnum.OPEN: 'OPEN',
  TicketStatusEnum.IN_PROGRESS: 'IN_PROGRESS',
  TicketStatusEnum.RESOLVED: 'RESOLVED',
  TicketStatusEnum.CLOSED: 'CLOSED',
  TicketStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
