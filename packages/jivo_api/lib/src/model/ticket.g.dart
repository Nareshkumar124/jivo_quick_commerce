// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TicketCWProxy {
  Ticket id(int id);

  Ticket number(String number);

  Ticket category(TicketCategoryEnum category);

  Ticket status(TicketStatusEnum status);

  Ticket orderId(int? orderId);

  Ticket orderNumber(String? orderNumber);

  Ticket taskId(int? taskId);

  Ticket payoutId(int? payoutId);

  Ticket lastMessage(String? lastMessage);

  Ticket createdAt(DateTime createdAt);

  Ticket updatedAt(DateTime updatedAt);

  Ticket canReply(bool canReply);

  Ticket messages(List<TicketMessage> messages);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Ticket(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Ticket(...).copyWith(id: 12, name: "My name")
  /// ````
  Ticket call({
    int id,
    String number,
    TicketCategoryEnum category,
    TicketStatusEnum status,
    int? orderId,
    String? orderNumber,
    int? taskId,
    int? payoutId,
    String? lastMessage,
    DateTime createdAt,
    DateTime updatedAt,
    bool canReply,
    List<TicketMessage> messages,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTicket.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTicket.copyWith.fieldName(...)`
class _$TicketCWProxyImpl implements _$TicketCWProxy {
  const _$TicketCWProxyImpl(this._value);

  final Ticket _value;

  @override
  Ticket id(int id) => this(id: id);

  @override
  Ticket number(String number) => this(number: number);

  @override
  Ticket category(TicketCategoryEnum category) => this(category: category);

  @override
  Ticket status(TicketStatusEnum status) => this(status: status);

  @override
  Ticket orderId(int? orderId) => this(orderId: orderId);

  @override
  Ticket orderNumber(String? orderNumber) => this(orderNumber: orderNumber);

  @override
  Ticket taskId(int? taskId) => this(taskId: taskId);

  @override
  Ticket payoutId(int? payoutId) => this(payoutId: payoutId);

  @override
  Ticket lastMessage(String? lastMessage) => this(lastMessage: lastMessage);

  @override
  Ticket createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  Ticket updatedAt(DateTime updatedAt) => this(updatedAt: updatedAt);

  @override
  Ticket canReply(bool canReply) => this(canReply: canReply);

  @override
  Ticket messages(List<TicketMessage> messages) => this(messages: messages);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Ticket(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Ticket(...).copyWith(id: 12, name: "My name")
  /// ````
  Ticket call({
    Object? id = const $CopyWithPlaceholder(),
    Object? number = const $CopyWithPlaceholder(),
    Object? category = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? taskId = const $CopyWithPlaceholder(),
    Object? payoutId = const $CopyWithPlaceholder(),
    Object? lastMessage = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
    Object? canReply = const $CopyWithPlaceholder(),
    Object? messages = const $CopyWithPlaceholder(),
  }) {
    return Ticket(
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
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int?,
      payoutId: payoutId == const $CopyWithPlaceholder()
          ? _value.payoutId
          // ignore: cast_nullable_to_non_nullable
          : payoutId as int?,
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
      canReply: canReply == const $CopyWithPlaceholder()
          ? _value.canReply
          // ignore: cast_nullable_to_non_nullable
          : canReply as bool,
      messages: messages == const $CopyWithPlaceholder()
          ? _value.messages
          // ignore: cast_nullable_to_non_nullable
          : messages as List<TicketMessage>,
    );
  }
}

extension $TicketCopyWith on Ticket {
  /// Returns a callable class that can be used as follows: `instanceOfTicket.copyWith(...)` or like so:`instanceOfTicket.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TicketCWProxy get copyWith => _$TicketCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Ticket _$TicketFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Ticket',
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
        'task_id',
        'payout_id',
        'last_message',
        'created_at',
        'updated_at',
        'can_reply',
        'messages',
      ],
    );
    final val = Ticket(
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
      taskId: $checkedConvert('task_id', (v) => (v as num?)?.toInt()),
      payoutId: $checkedConvert('payout_id', (v) => (v as num?)?.toInt()),
      lastMessage: $checkedConvert('last_message', (v) => v as String?),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      canReply: $checkedConvert('can_reply', (v) => v as bool),
      messages: $checkedConvert(
        'messages',
        (v) => (v as List<dynamic>)
            .map((e) => TicketMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'orderId': 'order_id',
    'orderNumber': 'order_number',
    'taskId': 'task_id',
    'payoutId': 'payout_id',
    'lastMessage': 'last_message',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
    'canReply': 'can_reply',
  },
);

Map<String, dynamic> _$TicketToJson(Ticket instance) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'category': _$TicketCategoryEnumEnumMap[instance.category]!,
  'status': _$TicketStatusEnumEnumMap[instance.status]!,
  'order_id': instance.orderId,
  'order_number': instance.orderNumber,
  'task_id': instance.taskId,
  'payout_id': instance.payoutId,
  'last_message': instance.lastMessage,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'can_reply': instance.canReply,
  'messages': instance.messages.map((e) => e.toJson()).toList(),
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

const _$TicketStatusEnumEnumMap = {
  TicketStatusEnum.OPEN: 'OPEN',
  TicketStatusEnum.IN_PROGRESS: 'IN_PROGRESS',
  TicketStatusEnum.RESOLVED: 'RESOLVED',
  TicketStatusEnum.CLOSED: 'CLOSED',
  TicketStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
