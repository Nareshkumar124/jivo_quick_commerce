import 'dart:async';
import 'dart:math' as math;

import 'package:jivo_core/jivo_core.dart';

import '../../offers/domain/delivery_offer.dart';
import '../domain/rider_task.dart';
import '../domain/task_repositories.dart';
import '../domain/task_rules.dart';
import '../domain/task_status.dart';

/// TODO(api): stands in for the rider offer and task endpoints of 06 §3
/// until the rider contract lands (end of P4). It plays the server's rules
/// from 08 (geofence, pickup only when PACKED, 5 OTP attempts then lock, COD
/// amount must match, "not reachable" after the 10-minute wait) so the app
/// can be built and tested against them. Behaviour the docs leave open is
/// marked "assumed" and listed as API questions in the run report.
///
/// Dev controls stand in for what other people do: dispatch (offers), the
/// store (packed, receive return), ops (cancel, unassign) and the customer
/// (pay the UPI QR).
class FakeTaskBackend
    implements OfferRepository, OfferEventSource, TaskRepository {
  FakeTaskBackend({
    this.delay = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration delay;
  final DateTime Function() _clock;

  /// The code printed on the bag label (and in its QR).
  static const pickupCode = '7K2P';

  /// The OTP the customer reads out.
  static const deliveryOtp = '4321';
  static const maxOtpAttempts = 5;

  /// What a COD order asks the rider to collect.
  static const codAmount = '1249.00';

  /// Where the customer's drop pin is.
  static const customerLocation = GeoPoint(28.5832, 77.3412);

  static const store = TaskStore(
    name: 'Jivo Sector 18',
    address: 'Shop 4, Sector 18 Market, Noida',
    location: GeoPoint(28.5706, 77.3261),
    phone: '+911800123456',
  );

  final _events = StreamController<OfferEvent>.broadcast();
  DeliveryOffer? _offer;
  PaymentType? _offerPayment;
  RiderTask? _task;
  int _nextId = 501;

  /// Calls made, for tests. Never contains OTPs or codes.
  final List<String> calls = [];

  /// When set, the next call fails with it (then it is cleared).
  ApiError? failNext;

  /// When set, the next action is applied on the "server" and then fails
  /// with it, like a response lost on a bad network.
  ApiError? applyThenFailNext;

  /// The next arrived-at-store / arrived-at-customer is outside the geofence.
  bool outsideGeofenceNext = false;

  /// Check arrivals against the real distance, like the server (~200 m,
  /// 04 §2.5–§2.6). Off by default; the GPX integration harness turns it on.
  bool enforceGeofence = false;
  static const geofenceRadiusM = 200;

  /// The next accept loses the race to another rider.
  bool takenNext = false;

  @override
  Stream<OfferEvent> get events => _events.stream;

  RiderTask? get task => _task;
  DeliveryOffer? get offer => _offer;

  // ------------------------------------------------------------- offers

  /// Dispatch offers an order to this rider (`offer.new`).
  DeliveryOffer simulateOffer({bool cod = false, Duration? expiresIn}) {
    final now = _clock().toUtc();
    final offer = DeliveryOffer(
      id: _nextId++,
      storeName: store.name,
      dropLocality: 'Sector 21, Noida',
      distanceKm: '2.4',
      paymentType: cod ? PaymentType.cod : PaymentType.prepaid,
      codAmount: cod ? codAmount : null,
      estimatedPayout: '45.00',
      expiresAt: now.add(expiresIn ?? kOfferWindow),
    );
    _offer = offer;
    _offerPayment = offer.paymentType;
    _events.add(OfferArrived(ReceivedOffer(offer, serverNow: now)));
    return offer;
  }

  /// The order was cancelled before anyone accepted (`offer.withdrawn`).
  void withdrawOffer() {
    final offer = _offer;
    if (offer == null) return;
    _offer = null;
    _events.add(OfferWithdrawn(offer.id));
  }

  @override
  Future<ReceivedOffer?> fetchCurrentOffer() async {
    await _call('fetchCurrentOffer');
    final offer = _offer;
    if (offer == null) return null;
    if (!_clock().toUtc().isBefore(offer.expiresAt)) {
      _offer = null;
      return null;
    }
    return ReceivedOffer(offer, serverNow: _clock().toUtc());
  }

  @override
  Future<RiderTask> accept(int offerId) async {
    await _call('accept $offerId');
    final offer = _offer;
    if (offer == null || offer.id != offerId || takenNext) {
      takenNext = false;
      throw _error(ApiErrorCode.offerTaken, 409);
    }
    _offer = null;
    if (!_clock().toUtc().isBefore(offer.expiresAt)) {
      throw _error(ApiErrorCode.offerExpired, 409);
    }
    final cod = _offerPayment == PaymentType.cod;
    _task = _newTask(offer.id, cod: cod);
    return _respond(_task!);
  }

  @override
  Future<void> reject(int offerId, {OfferRejectReason? reason}) async {
    await _call('reject $offerId ${reason?.wireValue ?? '-'}');
    if (_offer?.id == offerId) _offer = null;
  }

  // -------------------------------------------------------------- tasks

  /// Starts with [task] already assigned (tests, restore).
  void seedTask(RiderTask task) => _task = task;

  RiderTask newTask({bool cod = false, TaskStatus? status}) {
    final task = _newTask(_nextId++, cod: cod);
    return status == null ? task : task.copyWith(status: status);
  }

  RiderTask _newTask(int id, {required bool cod}) => RiderTask(
    id: id,
    status: TaskStatus.assigned,
    orderNumber: 'JQ-10$id',
    store: store,
    storeProgress: StoreOrderProgress.packing,
    paymentType: cod ? PaymentType.cod : PaymentType.prepaid,
    codAmountDue: cod ? codAmount : null,
    payout: '45.00',
    distanceKm: '2.4',
    dropLocality: 'Sector 21, Noida',
    customer: const TaskCustomer(
      name: 'Asha Verma',
      phone: '+919876512345',
      address: 'Flat 302, Tower B, Sector 21, Noida',
      landmark: 'Opposite the park gate',
      instructions: 'Ring the bell twice',
      location: customerLocation,
    ),
    items: const [
      TaskItem(name: 'Jivo Canola Oil', unit: '1 L', quantity: 2),
      TaskItem(name: 'Jivo Wheatgrass Juice', unit: '500 ml', quantity: 1),
    ],
    otpAttemptsRemaining: maxOtpAttempts,
  );

  /// Assumed (api-requests #13, undecided): `GET current` returns a task
  /// that just ended (delivered, returned, cancelled) once more, so the
  /// rider sees how it ended; after that there is no current task. Tests set
  /// false to play the other answer (ended tasks are never returned).
  bool returnsEndedTasks = true;

  @override
  Future<RiderTask?> fetchCurrentTask() async {
    await _call('fetchCurrentTask');
    final task = _task;
    if (task != null && task.status.isTerminal) {
      _task = null;
      if (!returnsEndedTasks) return null;
    }
    return task;
  }

  @override
  Future<RiderTask> arrivedAtStore(int taskId, GeoPoint at) async {
    await _call('arrivedAtStore');
    final task = _require(taskId, TaskStatus.assigned);
    _geofence(at, task.store.location);
    return _update(task.copyWith(status: TaskStatus.atStore));
  }

  @override
  Future<RiderTask> pickup(int taskId, String orderCode) async {
    await _call('pickup');
    final task = _require(taskId, TaskStatus.atStore);
    if (task.storeProgress != StoreOrderProgress.ready) {
      // Order not PACKED yet (T9 guard).
      throw _error(ApiErrorCode.invalidStateTransition, 409);
    }
    if (orderCode != pickupCode) {
      // Assumed error for a wrong code (06 does not name one).
      throw _error(
        ApiErrorCode.validationError,
        400,
        details: {
          'order_code': ['The code does not match this order.'],
        },
      );
    }
    return _update(
      task.copyWith(
        status: TaskStatus.pickedUp,
        storeProgress: StoreOrderProgress.handedOver,
      ),
    );
  }

  @override
  Future<RiderTask> arrivedAtCustomer(
    int taskId,
    GeoPoint at, {
    String? overrideReason,
  }) async {
    await _call(
      'arrivedAtCustomer${overrideReason == null ? '' : ' override'}',
    );
    final task = _require(taskId, TaskStatus.pickedUp);
    if (overrideReason == null) _geofence(at, task.customer?.location);
    return _update(
      task.copyWith(
        status: TaskStatus.atCustomer,
        arrivedCustomerAt: _clock().toUtc(),
      ),
    );
  }

  @override
  Future<CodQr> createCodQr(int taskId) async {
    await _call('createCodQr');
    final task = _require(taskId, TaskStatus.atCustomer);
    if (!task.isCod) throw _error(ApiErrorCode.codNotAvailable, 422);
    final qr = CodQr(
      imageUrl: null,
      amount: task.codAmountDue!,
      status: UpiQrStatus.pending,
    );
    _task = task.copyWith(codQr: qr);
    return qr;
  }

  @override
  Future<RiderTask> deliver(
    int taskId, {
    required String otp,
    CodMode? codMode,
    String? codAmount,
  }) async {
    await _call('deliver ${codMode?.wireValue ?? 'prepaid'} $codAmount');
    final task = _require(taskId, TaskStatus.atCustomer);
    if (task.otpLocked) throw _error(ApiErrorCode.deliveryOtpLocked, 423);
    if (otp != deliveryOtp) {
      final left = (task.otpAttemptsRemaining ?? maxOtpAttempts) - 1;
      if (left <= 0) {
        _task = task.copyWith(otpAttemptsRemaining: 0, otpLocked: true);
        throw _error(ApiErrorCode.deliveryOtpLocked, 423);
      }
      _task = task.copyWith(otpAttemptsRemaining: left);
      throw _error(
        ApiErrorCode.deliveryOtpInvalid,
        400,
        details: {'attempts_remaining': left},
      );
    }
    if (task.isCod) {
      final paidByUpi =
          codMode == CodMode.upi && task.codQr?.status == UpiQrStatus.paid;
      if (codAmount != task.codAmountDue ||
          codMode == null ||
          (codMode == CodMode.upi && !paidByUpi)) {
        throw _error(
          ApiErrorCode.validationError,
          400,
          details: {
            'cod': ['The collected amount does not match.'],
          },
        );
      }
    }
    return _update(task.copyWith(status: TaskStatus.delivered));
  }

  @override
  Future<RiderTask> fail(int taskId, FailReport report) async {
    await _call('fail ${report.reason.wireValue}');
    final task = _task;
    if (task == null ||
        task.id != taskId ||
        !TaskAction.fail.allowedIn(task.status)) {
      throw _error(ApiErrorCode.invalidStateTransition, 409);
    }
    if (report.reason == FailReason.notReachable) {
      final arrived = task.arrivedCustomerAt;
      if (arrived == null ||
          _clock().toUtc().isBefore(arrived.add(kNotReachableWait))) {
        throw _error(ApiErrorCode.validationError, 400);
      }
    }
    // T13: FAILED, and the task moves on to RETURNING.
    return _update(task.copyWith(status: TaskStatus.returning));
  }

  // ------------------------------------------------- the rest of the world

  /// The store marked the order PACKED (T8).
  void markPacked() {
    final task = _task;
    if (task != null) {
      _task = task.copyWith(storeProgress: StoreOrderProgress.ready);
    }
  }

  /// The customer paid the UPI QR (Razorpay webhook).
  void markUpiPaid() {
    final task = _task;
    final qr = task?.codQr;
    if (task != null && qr != null) {
      _task = task.copyWith(codQr: qr.withStatus(UpiQrStatus.paid));
    }
  }

  /// The UPI QR timed out before the customer paid.
  void expireUpiQr() {
    final task = _task;
    final qr = task?.codQr;
    if (task != null && qr != null) {
      _task = task.copyWith(codQr: qr.withStatus(UpiQrStatus.expired));
    }
  }

  /// The store received the returned items (T14).
  void markReturned() {
    final task = _task;
    if (task?.status == TaskStatus.returning) {
      _task = task!.copyWith(status: TaskStatus.returned);
    }
  }

  /// The order was cancelled before pickup (T11/T12).
  void cancelOrder() {
    final task = _task;
    if (task != null && task.status.canTransitionTo(TaskStatus.cancelled)) {
      _task = task.copyWith(status: TaskStatus.cancelled);
    }
  }

  /// Ops unassigned the rider (08 §3 reassignment): the task is gone.
  void unassign() => _task = null;

  // ------------------------------------------------------------ helpers

  Future<void> _call(String name) async {
    calls.add(name);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  RiderTask _require(int taskId, TaskStatus status) {
    final task = _task;
    if (task == null || task.id != taskId || task.status != status) {
      throw _error(ApiErrorCode.invalidStateTransition, 409);
    }
    return task;
  }

  void _geofence(GeoPoint at, GeoPoint? target) {
    if (outsideGeofenceNext) {
      outsideGeofenceNext = false;
      throw _error(
        ApiErrorCode.outsideGeofence,
        422,
        details: {'distance_m': 450, 'radius_m': geofenceRadiusM},
      );
    }
    if (!enforceGeofence || target == null) return;
    final distance = distanceMetres(at, target).round();
    if (distance > geofenceRadiusM) {
      throw _error(
        ApiErrorCode.outsideGeofence,
        422,
        details: {'distance_m': distance, 'radius_m': geofenceRadiusM},
      );
    }
  }

  /// Great-circle distance (haversine), for the fake geofence only.
  static double distanceMetres(GeoPoint a, GeoPoint b) {
    const earthRadiusM = 6371000.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.lat)) *
            math.cos(rad(b.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusM * math.asin(math.sqrt(h));
  }

  RiderTask _update(RiderTask task) {
    _task = task;
    return _respond(task);
  }

  RiderTask _respond(RiderTask task) {
    final lost = applyThenFailNext;
    if (lost != null) {
      applyThenFailNext = null;
      throw lost;
    }
    return task;
  }

  static ApiError _error(
    ApiErrorCode code,
    int status, {
    Map<String, Object?> details = const {},
  }) => ApiError(
    code: code,
    rawCode: code.wireValue,
    statusCode: status,
    details: details,
  );
}
