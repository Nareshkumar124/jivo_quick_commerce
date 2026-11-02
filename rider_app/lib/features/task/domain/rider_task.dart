import 'task_status.dart';

/// Prepaid or cash on delivery.
///
/// TODO(api): wire values assumed (`PREPAID`/`COD`).
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
  });

  final String name;

  /// E.164, dialled with `tel:` (masked calling is v2).
  final String phone;
  final String address;
  final GeoPoint location;
  final String? landmark;
  final String? instructions;

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

/// Server state of the UPI QR for a COD order (`POST .../cod-qr/`).
enum UpiQrStatus { pending, paid, expired }

class CodQr {
  const CodQr({
    required this.imageUrl,
    required this.amount,
    required this.status,
  });

  /// The QR image (Razorpay QR). Null in the fake.
  final String? imageUrl;

  /// The amount the QR collects, exactly as the server sends it.
  final String amount;
  final UpiQrStatus status;

  CodQr withStatus(UpiQrStatus next) =>
      CodQr(imageUrl: imageUrl, amount: amount, status: next);
}

/// The rider's active task, as `GET /rider/tasks/current/` returns it (06 §3
/// "active task with full details"; 07 §2.8 `DeliveryTask`).
///
/// Everything a restart must restore comes from here (agent rule 7): the
/// step ([status]), the OTP attempts left and lock, the UPI QR state and
/// [arrivedCustomerAt] (the start of the 10-minute wait).
///
/// TODO(api): hand-written until the rider contract lands (end of P4).
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
    this.payout,
    this.distanceKm,
    this.arrivedCustomerAt,
    this.otpLength = 4,
    this.otpAttemptsRemaining,
    this.otpLocked = false,
    this.codQr,
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

  /// The rider's pay for this order (estimate before delivery, earned after).
  final String? payout;
  final String? distanceKm;

  /// Server time the rider arrived at the customer: the 10-minute
  /// "not reachable" wait counts from here.
  final DateTime? arrivedCustomerAt;
  final int otpLength;
  final int? otpAttemptsRemaining;

  /// DELIVERY_OTP_LOCKED: 5 wrong codes, ops alerted (04 §2.6).
  final bool otpLocked;
  final CodQr? codQr;

  bool get isCod => paymentType == PaymentType.cod;

  RiderTask copyWith({
    TaskStatus? status,
    StoreOrderProgress? storeProgress,
    DateTime? arrivedCustomerAt,
    int? otpAttemptsRemaining,
    bool? otpLocked,
    CodQr? codQr,
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
    codAmountDue: codAmountDue,
    payout: payout,
    distanceKm: distanceKm,
    arrivedCustomerAt: arrivedCustomerAt ?? this.arrivedCustomerAt,
    otpLength: otpLength,
    otpAttemptsRemaining: otpAttemptsRemaining ?? this.otpAttemptsRemaining,
    otpLocked: otpLocked ?? this.otpLocked,
    codQr: codQr ?? this.codQr,
  );

  @override
  String toString() => 'RiderTask($id, ${status.wireValue})';
}
