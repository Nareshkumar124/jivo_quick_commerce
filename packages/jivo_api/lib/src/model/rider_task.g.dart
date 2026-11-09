// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_task.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderTaskCWProxy {
  RiderTask id(int id);

  RiderTask status(DeliveryTaskStatusEnum status);

  RiderTask orderId(int orderId);

  RiderTask orderNumber(String orderNumber);

  RiderTask orderStatus(OrderStatusEnum orderStatus);

  RiderTask readyForPickup(bool readyForPickup);

  RiderTask paymentType(RiderPaymentTypeEnum paymentType);

  RiderTask codAmountDue(String? codAmountDue);

  RiderTask codAmountPrevious(String? codAmountPrevious);

  RiderTask store(TaskStore store);

  RiderTask customerAddress(OrderAddress customerAddress);

  RiderTask instructions(DeliveryInstructions instructions);

  RiderTask items(List<TaskItem> items);

  RiderTask itemCount(int itemCount);

  RiderTask distanceKm(String distanceKm);

  RiderTask estimatedPayout(String estimatedPayout);

  RiderTask geofence(TaskGeofence geofence);

  RiderTask deliveryOtp(DeliveryOtpState deliveryOtp);

  RiderTask pickupCode(PickupCodeState pickupCode);

  RiderTask codQr(CodQr? codQr);

  RiderTask assignedAt(DateTime assignedAt);

  RiderTask arrivedStoreAt(DateTime? arrivedStoreAt);

  RiderTask pickedUpAt(DateTime? pickedUpAt);

  RiderTask arrivedCustomerAt(DateTime? arrivedCustomerAt);

  RiderTask notReachableAfter(DateTime? notReachableAfter);

  RiderTask deliveredAt(DateTime? deliveredAt);

  RiderTask failedAt(DateTime? failedAt);

  RiderTask failReason(DeliveryFailReasonEnum? failReason);

  RiderTask returnedAt(DateTime? returnedAt);

  RiderTask earnings(TaskEarnings? earnings);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderTask(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderTask(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderTask call({
    int id,
    DeliveryTaskStatusEnum status,
    int orderId,
    String orderNumber,
    OrderStatusEnum orderStatus,
    bool readyForPickup,
    RiderPaymentTypeEnum paymentType,
    String? codAmountDue,
    String? codAmountPrevious,
    TaskStore store,
    OrderAddress customerAddress,
    DeliveryInstructions instructions,
    List<TaskItem> items,
    int itemCount,
    String distanceKm,
    String estimatedPayout,
    TaskGeofence geofence,
    DeliveryOtpState deliveryOtp,
    PickupCodeState pickupCode,
    CodQr? codQr,
    DateTime assignedAt,
    DateTime? arrivedStoreAt,
    DateTime? pickedUpAt,
    DateTime? arrivedCustomerAt,
    DateTime? notReachableAfter,
    DateTime? deliveredAt,
    DateTime? failedAt,
    DeliveryFailReasonEnum? failReason,
    DateTime? returnedAt,
    TaskEarnings? earnings,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderTask.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderTask.copyWith.fieldName(...)`
class _$RiderTaskCWProxyImpl implements _$RiderTaskCWProxy {
  const _$RiderTaskCWProxyImpl(this._value);

  final RiderTask _value;

  @override
  RiderTask id(int id) => this(id: id);

  @override
  RiderTask status(DeliveryTaskStatusEnum status) => this(status: status);

  @override
  RiderTask orderId(int orderId) => this(orderId: orderId);

  @override
  RiderTask orderNumber(String orderNumber) => this(orderNumber: orderNumber);

  @override
  RiderTask orderStatus(OrderStatusEnum orderStatus) =>
      this(orderStatus: orderStatus);

  @override
  RiderTask readyForPickup(bool readyForPickup) =>
      this(readyForPickup: readyForPickup);

  @override
  RiderTask paymentType(RiderPaymentTypeEnum paymentType) =>
      this(paymentType: paymentType);

  @override
  RiderTask codAmountDue(String? codAmountDue) =>
      this(codAmountDue: codAmountDue);

  @override
  RiderTask codAmountPrevious(String? codAmountPrevious) =>
      this(codAmountPrevious: codAmountPrevious);

  @override
  RiderTask store(TaskStore store) => this(store: store);

  @override
  RiderTask customerAddress(OrderAddress customerAddress) =>
      this(customerAddress: customerAddress);

  @override
  RiderTask instructions(DeliveryInstructions instructions) =>
      this(instructions: instructions);

  @override
  RiderTask items(List<TaskItem> items) => this(items: items);

  @override
  RiderTask itemCount(int itemCount) => this(itemCount: itemCount);

  @override
  RiderTask distanceKm(String distanceKm) => this(distanceKm: distanceKm);

  @override
  RiderTask estimatedPayout(String estimatedPayout) =>
      this(estimatedPayout: estimatedPayout);

  @override
  RiderTask geofence(TaskGeofence geofence) => this(geofence: geofence);

  @override
  RiderTask deliveryOtp(DeliveryOtpState deliveryOtp) =>
      this(deliveryOtp: deliveryOtp);

  @override
  RiderTask pickupCode(PickupCodeState pickupCode) =>
      this(pickupCode: pickupCode);

  @override
  RiderTask codQr(CodQr? codQr) => this(codQr: codQr);

  @override
  RiderTask assignedAt(DateTime assignedAt) => this(assignedAt: assignedAt);

  @override
  RiderTask arrivedStoreAt(DateTime? arrivedStoreAt) =>
      this(arrivedStoreAt: arrivedStoreAt);

  @override
  RiderTask pickedUpAt(DateTime? pickedUpAt) => this(pickedUpAt: pickedUpAt);

  @override
  RiderTask arrivedCustomerAt(DateTime? arrivedCustomerAt) =>
      this(arrivedCustomerAt: arrivedCustomerAt);

  @override
  RiderTask notReachableAfter(DateTime? notReachableAfter) =>
      this(notReachableAfter: notReachableAfter);

  @override
  RiderTask deliveredAt(DateTime? deliveredAt) =>
      this(deliveredAt: deliveredAt);

  @override
  RiderTask failedAt(DateTime? failedAt) => this(failedAt: failedAt);

  @override
  RiderTask failReason(DeliveryFailReasonEnum? failReason) =>
      this(failReason: failReason);

  @override
  RiderTask returnedAt(DateTime? returnedAt) => this(returnedAt: returnedAt);

  @override
  RiderTask earnings(TaskEarnings? earnings) => this(earnings: earnings);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderTask(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderTask(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderTask call({
    Object? id = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? orderStatus = const $CopyWithPlaceholder(),
    Object? readyForPickup = const $CopyWithPlaceholder(),
    Object? paymentType = const $CopyWithPlaceholder(),
    Object? codAmountDue = const $CopyWithPlaceholder(),
    Object? codAmountPrevious = const $CopyWithPlaceholder(),
    Object? store = const $CopyWithPlaceholder(),
    Object? customerAddress = const $CopyWithPlaceholder(),
    Object? instructions = const $CopyWithPlaceholder(),
    Object? items = const $CopyWithPlaceholder(),
    Object? itemCount = const $CopyWithPlaceholder(),
    Object? distanceKm = const $CopyWithPlaceholder(),
    Object? estimatedPayout = const $CopyWithPlaceholder(),
    Object? geofence = const $CopyWithPlaceholder(),
    Object? deliveryOtp = const $CopyWithPlaceholder(),
    Object? pickupCode = const $CopyWithPlaceholder(),
    Object? codQr = const $CopyWithPlaceholder(),
    Object? assignedAt = const $CopyWithPlaceholder(),
    Object? arrivedStoreAt = const $CopyWithPlaceholder(),
    Object? pickedUpAt = const $CopyWithPlaceholder(),
    Object? arrivedCustomerAt = const $CopyWithPlaceholder(),
    Object? notReachableAfter = const $CopyWithPlaceholder(),
    Object? deliveredAt = const $CopyWithPlaceholder(),
    Object? failedAt = const $CopyWithPlaceholder(),
    Object? failReason = const $CopyWithPlaceholder(),
    Object? returnedAt = const $CopyWithPlaceholder(),
    Object? earnings = const $CopyWithPlaceholder(),
  }) {
    return RiderTask(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as DeliveryTaskStatusEnum,
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String,
      orderStatus: orderStatus == const $CopyWithPlaceholder()
          ? _value.orderStatus
          // ignore: cast_nullable_to_non_nullable
          : orderStatus as OrderStatusEnum,
      readyForPickup: readyForPickup == const $CopyWithPlaceholder()
          ? _value.readyForPickup
          // ignore: cast_nullable_to_non_nullable
          : readyForPickup as bool,
      paymentType: paymentType == const $CopyWithPlaceholder()
          ? _value.paymentType
          // ignore: cast_nullable_to_non_nullable
          : paymentType as RiderPaymentTypeEnum,
      codAmountDue: codAmountDue == const $CopyWithPlaceholder()
          ? _value.codAmountDue
          // ignore: cast_nullable_to_non_nullable
          : codAmountDue as String?,
      codAmountPrevious: codAmountPrevious == const $CopyWithPlaceholder()
          ? _value.codAmountPrevious
          // ignore: cast_nullable_to_non_nullable
          : codAmountPrevious as String?,
      store: store == const $CopyWithPlaceholder()
          ? _value.store
          // ignore: cast_nullable_to_non_nullable
          : store as TaskStore,
      customerAddress: customerAddress == const $CopyWithPlaceholder()
          ? _value.customerAddress
          // ignore: cast_nullable_to_non_nullable
          : customerAddress as OrderAddress,
      instructions: instructions == const $CopyWithPlaceholder()
          ? _value.instructions
          // ignore: cast_nullable_to_non_nullable
          : instructions as DeliveryInstructions,
      items: items == const $CopyWithPlaceholder()
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<TaskItem>,
      itemCount: itemCount == const $CopyWithPlaceholder()
          ? _value.itemCount
          // ignore: cast_nullable_to_non_nullable
          : itemCount as int,
      distanceKm: distanceKm == const $CopyWithPlaceholder()
          ? _value.distanceKm
          // ignore: cast_nullable_to_non_nullable
          : distanceKm as String,
      estimatedPayout: estimatedPayout == const $CopyWithPlaceholder()
          ? _value.estimatedPayout
          // ignore: cast_nullable_to_non_nullable
          : estimatedPayout as String,
      geofence: geofence == const $CopyWithPlaceholder()
          ? _value.geofence
          // ignore: cast_nullable_to_non_nullable
          : geofence as TaskGeofence,
      deliveryOtp: deliveryOtp == const $CopyWithPlaceholder()
          ? _value.deliveryOtp
          // ignore: cast_nullable_to_non_nullable
          : deliveryOtp as DeliveryOtpState,
      pickupCode: pickupCode == const $CopyWithPlaceholder()
          ? _value.pickupCode
          // ignore: cast_nullable_to_non_nullable
          : pickupCode as PickupCodeState,
      codQr: codQr == const $CopyWithPlaceholder()
          ? _value.codQr
          // ignore: cast_nullable_to_non_nullable
          : codQr as CodQr?,
      assignedAt: assignedAt == const $CopyWithPlaceholder()
          ? _value.assignedAt
          // ignore: cast_nullable_to_non_nullable
          : assignedAt as DateTime,
      arrivedStoreAt: arrivedStoreAt == const $CopyWithPlaceholder()
          ? _value.arrivedStoreAt
          // ignore: cast_nullable_to_non_nullable
          : arrivedStoreAt as DateTime?,
      pickedUpAt: pickedUpAt == const $CopyWithPlaceholder()
          ? _value.pickedUpAt
          // ignore: cast_nullable_to_non_nullable
          : pickedUpAt as DateTime?,
      arrivedCustomerAt: arrivedCustomerAt == const $CopyWithPlaceholder()
          ? _value.arrivedCustomerAt
          // ignore: cast_nullable_to_non_nullable
          : arrivedCustomerAt as DateTime?,
      notReachableAfter: notReachableAfter == const $CopyWithPlaceholder()
          ? _value.notReachableAfter
          // ignore: cast_nullable_to_non_nullable
          : notReachableAfter as DateTime?,
      deliveredAt: deliveredAt == const $CopyWithPlaceholder()
          ? _value.deliveredAt
          // ignore: cast_nullable_to_non_nullable
          : deliveredAt as DateTime?,
      failedAt: failedAt == const $CopyWithPlaceholder()
          ? _value.failedAt
          // ignore: cast_nullable_to_non_nullable
          : failedAt as DateTime?,
      failReason: failReason == const $CopyWithPlaceholder()
          ? _value.failReason
          // ignore: cast_nullable_to_non_nullable
          : failReason as DeliveryFailReasonEnum?,
      returnedAt: returnedAt == const $CopyWithPlaceholder()
          ? _value.returnedAt
          // ignore: cast_nullable_to_non_nullable
          : returnedAt as DateTime?,
      earnings: earnings == const $CopyWithPlaceholder()
          ? _value.earnings
          // ignore: cast_nullable_to_non_nullable
          : earnings as TaskEarnings?,
    );
  }
}

extension $RiderTaskCopyWith on RiderTask {
  /// Returns a callable class that can be used as follows: `instanceOfRiderTask.copyWith(...)` or like so:`instanceOfRiderTask.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderTaskCWProxy get copyWith => _$RiderTaskCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderTask _$RiderTaskFromJson(Map<String, dynamic> json) => $checkedCreate(
  'RiderTask',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'status',
        'order_id',
        'order_number',
        'order_status',
        'ready_for_pickup',
        'payment_type',
        'cod_amount_due',
        'cod_amount_previous',
        'store',
        'customer_address',
        'instructions',
        'items',
        'item_count',
        'distance_km',
        'estimated_payout',
        'geofence',
        'delivery_otp',
        'pickup_code',
        'cod_qr',
        'assigned_at',
        'arrived_store_at',
        'picked_up_at',
        'arrived_customer_at',
        'not_reachable_after',
        'delivered_at',
        'failed_at',
        'fail_reason',
        'returned_at',
        'earnings',
      ],
    );
    final val = RiderTask(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$DeliveryTaskStatusEnumEnumMap,
          v,
          unknownValue: DeliveryTaskStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
      orderNumber: $checkedConvert('order_number', (v) => v as String),
      orderStatus: $checkedConvert(
        'order_status',
        (v) => $enumDecode(
          _$OrderStatusEnumEnumMap,
          v,
          unknownValue: OrderStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      readyForPickup: $checkedConvert('ready_for_pickup', (v) => v as bool),
      paymentType: $checkedConvert(
        'payment_type',
        (v) => $enumDecode(
          _$RiderPaymentTypeEnumEnumMap,
          v,
          unknownValue: RiderPaymentTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      codAmountDue: $checkedConvert('cod_amount_due', (v) => v as String?),
      codAmountPrevious: $checkedConvert(
        'cod_amount_previous',
        (v) => v as String?,
      ),
      store: $checkedConvert(
        'store',
        (v) => TaskStore.fromJson(v as Map<String, dynamic>),
      ),
      customerAddress: $checkedConvert(
        'customer_address',
        (v) => OrderAddress.fromJson(v as Map<String, dynamic>),
      ),
      instructions: $checkedConvert(
        'instructions',
        (v) => DeliveryInstructions.fromJson(v as Map<String, dynamic>),
      ),
      items: $checkedConvert(
        'items',
        (v) => (v as List<dynamic>)
            .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      itemCount: $checkedConvert('item_count', (v) => (v as num).toInt()),
      distanceKm: $checkedConvert('distance_km', (v) => v as String),
      estimatedPayout: $checkedConvert('estimated_payout', (v) => v as String),
      geofence: $checkedConvert(
        'geofence',
        (v) => TaskGeofence.fromJson(v as Map<String, dynamic>),
      ),
      deliveryOtp: $checkedConvert(
        'delivery_otp',
        (v) => DeliveryOtpState.fromJson(v as Map<String, dynamic>),
      ),
      pickupCode: $checkedConvert(
        'pickup_code',
        (v) => PickupCodeState.fromJson(v as Map<String, dynamic>),
      ),
      codQr: $checkedConvert(
        'cod_qr',
        (v) => v == null ? null : CodQr.fromJson(v as Map<String, dynamic>),
      ),
      assignedAt: $checkedConvert(
        'assigned_at',
        (v) => DateTime.parse(v as String),
      ),
      arrivedStoreAt: $checkedConvert(
        'arrived_store_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      pickedUpAt: $checkedConvert(
        'picked_up_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      arrivedCustomerAt: $checkedConvert(
        'arrived_customer_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      notReachableAfter: $checkedConvert(
        'not_reachable_after',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      deliveredAt: $checkedConvert(
        'delivered_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      failedAt: $checkedConvert(
        'failed_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      failReason: $checkedConvert(
        'fail_reason',
        (v) => $enumDecodeNullable(
          _$DeliveryFailReasonEnumEnumMap,
          v,
          unknownValue: DeliveryFailReasonEnum.unknownDefaultOpenApi,
        ),
      ),
      returnedAt: $checkedConvert(
        'returned_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      earnings: $checkedConvert(
        'earnings',
        (v) =>
            v == null ? null : TaskEarnings.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'orderId': 'order_id',
    'orderNumber': 'order_number',
    'orderStatus': 'order_status',
    'readyForPickup': 'ready_for_pickup',
    'paymentType': 'payment_type',
    'codAmountDue': 'cod_amount_due',
    'codAmountPrevious': 'cod_amount_previous',
    'customerAddress': 'customer_address',
    'itemCount': 'item_count',
    'distanceKm': 'distance_km',
    'estimatedPayout': 'estimated_payout',
    'deliveryOtp': 'delivery_otp',
    'pickupCode': 'pickup_code',
    'codQr': 'cod_qr',
    'assignedAt': 'assigned_at',
    'arrivedStoreAt': 'arrived_store_at',
    'pickedUpAt': 'picked_up_at',
    'arrivedCustomerAt': 'arrived_customer_at',
    'notReachableAfter': 'not_reachable_after',
    'deliveredAt': 'delivered_at',
    'failedAt': 'failed_at',
    'failReason': 'fail_reason',
    'returnedAt': 'returned_at',
  },
);

Map<String, dynamic> _$RiderTaskToJson(RiderTask instance) => <String, dynamic>{
  'id': instance.id,
  'status': _$DeliveryTaskStatusEnumEnumMap[instance.status]!,
  'order_id': instance.orderId,
  'order_number': instance.orderNumber,
  'order_status': _$OrderStatusEnumEnumMap[instance.orderStatus]!,
  'ready_for_pickup': instance.readyForPickup,
  'payment_type': _$RiderPaymentTypeEnumEnumMap[instance.paymentType]!,
  'cod_amount_due': instance.codAmountDue,
  'cod_amount_previous': instance.codAmountPrevious,
  'store': instance.store.toJson(),
  'customer_address': instance.customerAddress.toJson(),
  'instructions': instance.instructions.toJson(),
  'items': instance.items.map((e) => e.toJson()).toList(),
  'item_count': instance.itemCount,
  'distance_km': instance.distanceKm,
  'estimated_payout': instance.estimatedPayout,
  'geofence': instance.geofence.toJson(),
  'delivery_otp': instance.deliveryOtp.toJson(),
  'pickup_code': instance.pickupCode.toJson(),
  'cod_qr': instance.codQr?.toJson(),
  'assigned_at': instance.assignedAt.toIso8601String(),
  'arrived_store_at': instance.arrivedStoreAt?.toIso8601String(),
  'picked_up_at': instance.pickedUpAt?.toIso8601String(),
  'arrived_customer_at': instance.arrivedCustomerAt?.toIso8601String(),
  'not_reachable_after': instance.notReachableAfter?.toIso8601String(),
  'delivered_at': instance.deliveredAt?.toIso8601String(),
  'failed_at': instance.failedAt?.toIso8601String(),
  'fail_reason': _$DeliveryFailReasonEnumEnumMap[instance.failReason],
  'returned_at': instance.returnedAt?.toIso8601String(),
  'earnings': instance.earnings?.toJson(),
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

const _$RiderPaymentTypeEnumEnumMap = {
  RiderPaymentTypeEnum.PREPAID: 'PREPAID',
  RiderPaymentTypeEnum.COD: 'COD',
  RiderPaymentTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$DeliveryFailReasonEnumEnumMap = {
  DeliveryFailReasonEnum.CUSTOMER_NOT_REACHABLE: 'CUSTOMER_NOT_REACHABLE',
  DeliveryFailReasonEnum.CUSTOMER_REFUSED: 'CUSTOMER_REFUSED',
  DeliveryFailReasonEnum.WRONG_ADDRESS: 'WRONG_ADDRESS',
  DeliveryFailReasonEnum.OTHER: 'OTHER',
  DeliveryFailReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
