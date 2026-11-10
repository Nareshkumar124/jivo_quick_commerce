// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/delivery_otp_state.dart';
import 'package:jivo_api/src/model/task_geofence.dart';
import 'package:jivo_api/src/model/delivery_task_status_enum.dart';
import 'package:jivo_api/src/model/order_status_enum.dart';
import 'package:jivo_api/src/model/rider_payment_type_enum.dart';
import 'package:jivo_api/src/model/task_earnings.dart';
import 'package:jivo_api/src/model/cod_qr.dart';
import 'package:jivo_api/src/model/order_address.dart';
import 'package:jivo_api/src/model/task_item.dart';
import 'package:jivo_api/src/model/pickup_code_state.dart';
import 'package:jivo_api/src/model/task_store.dart';
import 'package:jivo_api/src/model/delivery_instructions.dart';
import 'package:jivo_api/src/model/delivery_fail_reason_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_task.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderTask {
  /// Returns a new [RiderTask] instance.
  RiderTask({
    required this.id,

    required this.status,

    required this.orderId,

    required this.orderNumber,

    required this.orderStatus,

    required this.readyForPickup,

    required this.paymentType,

    required this.codAmountDue,

    required this.codAmountPrevious,

    required this.store,

    required this.customerAddress,

    required this.instructions,

    required this.items,

    required this.itemCount,

    required this.distanceKm,

    required this.estimatedPayout,

    required this.geofence,

    required this.deliveryOtp,

    required this.pickupCode,

    required this.codQr,

    required this.assignedAt,

    required this.arrivedStoreAt,

    required this.pickedUpAt,

    required this.arrivedCustomerAt,

    required this.notReachableAfter,

    required this.deliveredAt,

    required this.failedAt,

    required this.failReason,

    required this.returnedAt,

    required this.earnings,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DeliveryTaskStatusEnum.unknownDefaultOpenApi,
  )
  final DeliveryTaskStatusEnum status;

  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

  /// ACCEPTED/PACKING: show \"Packing…\"; PACKED: \"Ready for pickup\".  * `PAYMENT_PENDING` - Completing payment… * `PLACED` - Order placed * `ACCEPTED` - Order confirmed * `PACKING` - Packing your order * `PACKED` - Packed, rider on the way to store * `OUT_FOR_DELIVERY` - On the way * `DELIVERED` - Delivered * `CANCELLED` - Cancelled * `PAYMENT_FAILED` - Payment failed * `DELIVERY_FAILED` - Delivery unsuccessful * `RETURNED` - Delivery unsuccessful
  @JsonKey(
    name: r'order_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderStatusEnum.unknownDefaultOpenApi,
  )
  final OrderStatusEnum orderStatus;

  /// True once the order is PACKED.
  @JsonKey(name: r'ready_for_pickup', required: true, includeIfNull: false)
  final bool readyForPickup;

  @JsonKey(
    name: r'payment_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderPaymentTypeEnum.unknownDefaultOpenApi,
  )
  final RiderPaymentTypeEnum paymentType;

  /// COD: exactly what to collect (it can drop if the store removed items); null if prepaid.
  @JsonKey(name: r'cod_amount_due', required: true, includeIfNull: true)
  final String? codAmountDue;

  /// COD: the amount before the last change since the offer (store removed items, 08 T8a), for \"Collect ₹X (was ₹Y)\"; null when unchanged or prepaid. The rider also gets a push when it changes.
  @JsonKey(name: r'cod_amount_previous', required: true, includeIfNull: true)
  final String? codAmountPrevious;

  @JsonKey(name: r'store', required: true, includeIfNull: false)
  final TaskStore store;

  /// The drop address (receiver name and phone included), revealed on accept.
  @JsonKey(name: r'customer_address', required: true, includeIfNull: false)
  final OrderAddress customerAddress;

  @JsonKey(name: r'instructions', required: true, includeIfNull: false)
  final DeliveryInstructions instructions;

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<TaskItem> items;

  /// Units in the bag.
  @JsonKey(name: r'item_count', required: true, includeIfNull: false)
  final int itemCount;

  /// Store to drop (road estimate).
  @JsonKey(name: r'distance_km', required: true, includeIfNull: false)
  final String distanceKm;

  /// Base + distance pay for this order (tips come on delivery).
  @JsonKey(name: r'estimated_payout', required: true, includeIfNull: false)
  final String estimatedPayout;

  @JsonKey(name: r'geofence', required: true, includeIfNull: false)
  final TaskGeofence geofence;

  @JsonKey(name: r'delivery_otp', required: true, includeIfNull: false)
  final DeliveryOtpState deliveryOtp;

  /// The order-code check at pickup (T9).
  @JsonKey(name: r'pickup_code', required: true, includeIfNull: false)
  final PickupCodeState pickupCode;

  /// The UPI QR, once generated.
  @JsonKey(name: r'cod_qr', required: true, includeIfNull: true)
  final CodQr? codQr;

  @JsonKey(name: r'assigned_at', required: true, includeIfNull: false)
  final DateTime assignedAt;

  @JsonKey(name: r'arrived_store_at', required: true, includeIfNull: true)
  final DateTime? arrivedStoreAt;

  @JsonKey(name: r'picked_up_at', required: true, includeIfNull: true)
  final DateTime? pickedUpAt;

  @JsonKey(name: r'arrived_customer_at', required: true, includeIfNull: true)
  final DateTime? arrivedCustomerAt;

  /// `arrived_customer_at` + 10 minutes: from then on CUSTOMER_NOT_REACHABLE is accepted. Null before arriving.
  @JsonKey(name: r'not_reachable_after', required: true, includeIfNull: true)
  final DateTime? notReachableAfter;

  @JsonKey(name: r'delivered_at', required: true, includeIfNull: true)
  final DateTime? deliveredAt;

  @JsonKey(name: r'failed_at', required: true, includeIfNull: true)
  final DateTime? failedAt;

  @JsonKey(
    name: r'fail_reason',
    required: true,
    includeIfNull: true,
    unknownEnumValue: DeliveryFailReasonEnum.unknownDefaultOpenApi,
  )
  final DeliveryFailReasonEnum? failReason;

  @JsonKey(name: r'returned_at', required: true, includeIfNull: true)
  final DateTime? returnedAt;

  /// The pay for this task: base + distance from pickup (DL-61: paid even if the delivery then fails), plus the tip once DELIVERED. Null before pickup.
  @JsonKey(name: r'earnings', required: true, includeIfNull: true)
  final TaskEarnings? earnings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderTask &&
          other.id == id &&
          other.status == status &&
          other.orderId == orderId &&
          other.orderNumber == orderNumber &&
          other.orderStatus == orderStatus &&
          other.readyForPickup == readyForPickup &&
          other.paymentType == paymentType &&
          other.codAmountDue == codAmountDue &&
          other.codAmountPrevious == codAmountPrevious &&
          other.store == store &&
          other.customerAddress == customerAddress &&
          other.instructions == instructions &&
          other.items == items &&
          other.itemCount == itemCount &&
          other.distanceKm == distanceKm &&
          other.estimatedPayout == estimatedPayout &&
          other.geofence == geofence &&
          other.deliveryOtp == deliveryOtp &&
          other.pickupCode == pickupCode &&
          other.codQr == codQr &&
          other.assignedAt == assignedAt &&
          other.arrivedStoreAt == arrivedStoreAt &&
          other.pickedUpAt == pickedUpAt &&
          other.arrivedCustomerAt == arrivedCustomerAt &&
          other.notReachableAfter == notReachableAfter &&
          other.deliveredAt == deliveredAt &&
          other.failedAt == failedAt &&
          other.failReason == failReason &&
          other.returnedAt == returnedAt &&
          other.earnings == earnings;

  @override
  int get hashCode =>
      id.hashCode +
      status.hashCode +
      orderId.hashCode +
      orderNumber.hashCode +
      orderStatus.hashCode +
      readyForPickup.hashCode +
      paymentType.hashCode +
      (codAmountDue == null ? 0 : codAmountDue.hashCode) +
      (codAmountPrevious == null ? 0 : codAmountPrevious.hashCode) +
      store.hashCode +
      customerAddress.hashCode +
      instructions.hashCode +
      items.hashCode +
      itemCount.hashCode +
      distanceKm.hashCode +
      estimatedPayout.hashCode +
      geofence.hashCode +
      deliveryOtp.hashCode +
      pickupCode.hashCode +
      (codQr == null ? 0 : codQr.hashCode) +
      assignedAt.hashCode +
      (arrivedStoreAt == null ? 0 : arrivedStoreAt.hashCode) +
      (pickedUpAt == null ? 0 : pickedUpAt.hashCode) +
      (arrivedCustomerAt == null ? 0 : arrivedCustomerAt.hashCode) +
      (notReachableAfter == null ? 0 : notReachableAfter.hashCode) +
      (deliveredAt == null ? 0 : deliveredAt.hashCode) +
      (failedAt == null ? 0 : failedAt.hashCode) +
      (failReason == null ? 0 : failReason.hashCode) +
      (returnedAt == null ? 0 : returnedAt.hashCode) +
      (earnings == null ? 0 : earnings.hashCode);

  factory RiderTask.fromJson(Map<String, dynamic> json) =>
      _$RiderTaskFromJson(json);

  Map<String, dynamic> toJson() => _$RiderTaskToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
