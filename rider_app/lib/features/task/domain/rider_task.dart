import 'task_status.dart';

/// Prepaid or cash on delivery (`RiderPaymentTypeEnum`).
enum PaymentType {
  prepaid('PREPAID'),
  cod('COD');

  const PaymentType(this.wireValue);

  final String wireValue;

  static PaymentType fromWire(String? value) =>
      value == cod.wireValue ? cod : prepaid;
}

/// The order's progress at the store, so the rider sees "Packing…" or
/// "Ready for pickup" (04 §2.5). Order states from 08 §1.
enum StoreOrderProgress {
  /// PLACED / ACCEPTED / PACKING.
  packing,

  /// PACKED.
  ready,

  /// OUT_FOR_DELIVERY or later.
  handedOver,
}

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint';
}

class TaskStore {
  const TaskStore({
    required this.name,
    required this.address,
    required this.location,
    this.phone,
  });

  final String name;
  final String address;
  final GeoPoint location;
  final String? phone;
}

/// The customer's delivery chips (`DeliveryInstructionChipEnum`).
enum DeliveryChip { dontRingBell, leaveAtDoor, avoidCalling }

/// The drop: revealed after the rider accepts (04 §2.4), hidden again by
/// the server 1 h after completion (09 §3.2).
class TaskCustomer {
  const TaskCustomer({
    required this.name,
    required this.phone,
    required this.address,
    required this.location,
    this.landmark,
    this.instructions,
    this.chips = const [],
  });

  final String name;

  /// E.164, dialled with `tel:` (masked calling is v2).
  final String phone;
  final String address;
  final GeoPoint location;
  final String? landmark;
  final String? instructions;

  /// "Don't ring the bell", "Leave at door", "Avoid calling".
  final List<DeliveryChip> chips;

  @override
  String toString() => 'TaskCustomer';
}

class TaskItem {
  const TaskItem({required this.name, required this.quantity, this.unit});

  final String name;

  /// Pack size, e.g. `1 L`.
  final String? unit;
  final int quantity;
}

/// Server state of the UPI QR for a COD order (`CodQrStatusEnum`).
enum UpiQrStatus {
  pending('PENDING'),
  paid('PAID'),
  expired('EXPIRED'),

  /// Closed because the rider took cash instead.
  cancelled('CANCELLED');

  const UpiQrStatus(this.wireValue);

  final String wireValue;

  static UpiQrStatus fromWire(String? value) => values.firstWhere(
    (status) => status.wireValue == value,
    orElse: () => pending,
  );
}

class CodQr {
  const CodQr({
    required this.imageUrl,
    required this.amount,
    required this.status,
    this.expiresAt,
  });

  /// The QR image (Razorpay QR, https PNG). Null in the fake.
  final String? imageUrl;

  /// The amount the QR collects, exactly as the server sends it.
  final String amount;
  final UpiQrStatus status;

  /// When the QR stops accepting payments (server time).
  final DateTime? expiresAt;

  CodQr withStatus(UpiQrStatus next) => CodQr(
    imageUrl: imageUrl,
    amount: amount,
    status: next,
    expiresAt: expiresAt,
  );
}

/// The rider's active task, as `GET /rider/tasks/current/` returns it (06 §3
/// "active task with full details"; 07 §2.8 `DeliveryTask`).
///
/// Everything a restart must restore comes from here (agent rule 7): the
/// step ([status]), the OTP attempts left and lock, the UPI QR state and
/// [arrivedCustomerAt] (the start of the 10-minute wait).
///
/// Mirrors the `RiderTask` schema of the slice 5.3 contract; the API
/// repository maps the generated type onto this (binding step).
class RiderTask {
  const RiderTask({
    required this.id,
    required this.status,
    required this.orderNumber,
    required this.store,
    required this.storeProgress,
    required this.paymentType,
    required this.items,
    this.customer,
    this.dropLocality,
    this.codAmountDue,
    this.codAmountChangedFrom,
    this.payout,
    this.distanceKm,
    this.arrivedCustomerAt,
    this.notReachableAfter,
    this.itemCount,
    this.earningsTotal,
    this.otpLength = 4,
    this.otpAttemptsRemaining,
    this.otpLocked = false,
    this.codQr,
    this.pickupAttemptsRemaining,
    this.pickupLocked = false,
  });

  final int id;
  final TaskStatus status;
  final String orderNumber;
  final TaskStore store;
  final StoreOrderProgress storeProgress;
  final PaymentType paymentType;
  final List<TaskItem> items;
  final TaskCustomer? customer;

  /// Locality only, for screens before the address is revealed.
  final String? dropLocality;

  /// COD: the exact amount to collect (`"249.00"`). Never computed here.
  final String? codAmountDue;

  /// COD: the amount the rider was offered, when the store changed the
  /// order afterwards (an item unavailable, 08 T8a). Shown as "Amount
  /// changed: collect ₹X (was ₹Y)" (UX audit RD-03). Both values are the
  /// server's; the app only compares the strings for display.
  ///
  /// Wire name `cod_amount_previous`.
  final String? codAmountChangedFrom;

  /// The rider's pay for this order (estimate before delivery, earned after).
  final String? payout;
  final String? distanceKm;

  /// Server time the rider arrived at the customer: the 10-minute
  /// "not reachable" wait counts from here.
  final DateTime? arrivedCustomerAt;

  /// `not_reachable_after`: from then on the server accepts
  /// CUSTOMER_NOT_REACHABLE. Null before arriving (or in an older fake).
  final DateTime? notReachableAfter;

  /// Units in the bag (`item_count`).
  final int? itemCount;

  /// `earnings.total`, set once DELIVERED.
  final String? earningsTotal;
  final int otpLength;
  final int? otpAttemptsRemaining;

  /// DELIVERY_OTP_LOCKED: 5 wrong codes, ops alerted (04 §2.6).
  final bool otpLocked;
  final CodQr? codQr;

  /// `pickup_code.attempts_remaining`: wrong order codes left before the
  /// pickup locks. Null when the server did not send it (older fakes).
  final int? pickupAttemptsRemaining;

  /// `pickup_code.locked`: too many wrong codes; the store or ops hand the
  /// order over (or ops unlock it). Restored after a restart.
  final bool pickupLocked;

  bool get isCod => paymentType == PaymentType.cod;

  RiderTask copyWith({
    TaskStatus? status,
    StoreOrderProgress? storeProgress,
    DateTime? arrivedCustomerAt,
    DateTime? notReachableAfter,
    String? earningsTotal,
    int? otpAttemptsRemaining,
    bool? otpLocked,
    CodQr? codQr,
    String? codAmountDue,
    String? codAmountChangedFrom,
    int? pickupAttemptsRemaining,
    bool? pickupLocked,
  }) => RiderTask(
    id: id,
    status: status ?? this.status,
    orderNumber: orderNumber,
    store: store,
    storeProgress: storeProgress ?? this.storeProgress,
    paymentType: paymentType,
    items: items,
    customer: customer,
    dropLocality: dropLocality,
    codAmountDue: codAmountDue ?? this.codAmountDue,
    codAmountChangedFrom: codAmountChangedFrom ?? this.codAmountChangedFrom,
    payout: payout,
    distanceKm: distanceKm,
    arrivedCustomerAt: arrivedCustomerAt ?? this.arrivedCustomerAt,
    notReachableAfter: notReachableAfter ?? this.notReachableAfter,
    itemCount: itemCount,
    earningsTotal: earningsTotal ?? this.earningsTotal,
    otpLength: otpLength,
    otpAttemptsRemaining: otpAttemptsRemaining ?? this.otpAttemptsRemaining,
    otpLocked: otpLocked ?? this.otpLocked,
    codQr: codQr ?? this.codQr,
    pickupAttemptsRemaining:
        pickupAttemptsRemaining ?? this.pickupAttemptsRemaining,
    pickupLocked: pickupLocked ?? this.pickupLocked,
  );

  @override
  String toString() => 'RiderTask($id, ${status.wireValue})';
}

/// A task that ended in the last 10 minutes (`recent_task`): explains a
/// lost answer (delivered, returned, cancelled) when `task` is null.
class RecentTask {
  const RecentTask({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.endedAt,
  });

  final int id;
  final String orderNumber;
  final TaskStatus status;
  final DateTime? endedAt;
}

/// `GET /rider/tasks/current/`: the active task (also RETURNING, until the
/// store receives the items) or null, plus the task that just ended.
class CurrentTask {
  const CurrentTask({this.task, this.recentTask, this.serverTime});

  static const none = CurrentTask();

  final RiderTask? task;
  final RecentTask? recentTask;
  final DateTime? serverTime;
}
