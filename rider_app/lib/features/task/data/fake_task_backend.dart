import 'dart:async';
import 'dart:math' as math;

import 'package:jivo_core/jivo_core.dart';

import '../../../shared/errors/rider_error_codes.dart';
import '../../offers/domain/delivery_offer.dart';
import '../domain/rider_task.dart';
import '../domain/task_repositories.dart';
import '../domain/task_rules.dart';
import '../domain/task_status.dart';

/// TODO(api): stands in for the rider offer and task endpoints until the
/// app is bound to the generated client (slice 5.3 schema, T-515b). It
/// plays the contract's rules (geofence 422, pickup only when PACKED, 5
/// wrong pickup codes then 423 `PICKUP_CODE_LOCKED`, 5 OTP attempts then
/// 423, COD amount must equal `cod_amount_due` (400 with `amount_due`),
/// CUSTOMER_NOT_REACHABLE only after `not_reachable_after` and 2 calls,
/// `fail` straight to RETURNING, ended tasks reported as `recent_task`).
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
  static const maxPickupAttempts = 5;

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
  RecentTask? _recent;
  int _pickupAttemptsLeft = maxPickupAttempts;
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
  DeliveryOffer simulateOffer({
    bool cod = false,
    Duration? expiresIn,
    bool withoutCodAmount = false,
    bool pushed = true,
  }) {
    final now = _clock().toUtc();
    final id = _nextId++;
    final offer = DeliveryOffer(
      id: id,
      taskId: id,
      itemCount: 3,
      storeName: store.name,
      dropLocality: 'Sector 21, Noida',
      distanceKm: '2.4',
      paymentType: cod ? PaymentType.cod : PaymentType.prepaid,
      codAmount: cod && !withoutCodAmount ? codAmount : null,
      estimatedPayout: '45.00',
      expiresAt: now.add(expiresIn ?? kOfferWindow),
    );
    _offer = offer;
    _offerPayment = offer.paymentType;
    // `pushed: false` plays a lost FCM push: only polling finds it.
    if (pushed) _events.add(OfferArrived(ReceivedOffer(offer, serverNow: now)));
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
    _pickupAttemptsLeft = maxPickupAttempts;
    return _respond(_task!);
  }

  @override
  Future<void> reject(int offerId, {OfferRejectReason? reason}) async {
    await _call('reject $offerId ${reason?.wireValue ?? '-'}');
    if (_offer?.id == offerId) _offer = null;
  }

  // -------------------------------------------------------------- tasks

  /// Starts with [task] already assigned (tests, restore).
  void seedTask(RiderTask task) {
    _task = task;
    _pickupAttemptsLeft = maxPickupAttempts;
  }

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
    itemCount: 3,
    otpAttemptsRemaining: maxOtpAttempts,
  );

  /// The contract: an ended task is no longer `task`; it is reported as
  /// `recent_task` for 10 minutes. Tests set false to play a lost
  /// `recent_task` (nothing explains the end).
  bool returnsEndedTasks = true;

  @override
  Future<CurrentTask> fetchCurrentTask() async {
    await _call('fetchCurrentTask');
    final task = _task;
    if (task != null && task.status.isTerminal) {
      _task = null;
      _recent = RecentTask(
        id: task.id,
        orderNumber: task.orderNumber,
        status: task.status,
        endedAt: _clock().toUtc(),
      );
    }
    final now = _clock().toUtc();
    final recent = _recent;
    final showRecent =
        _task == null &&
        returnsEndedTasks &&
        recent != null &&
        now.difference(recent.endedAt ?? now) < const Duration(minutes: 10);
    return CurrentTask(
      task: _task,
      recentTask: showRecent ? recent : null,
      serverTime: now,
    );
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
    if (_pickupAttemptsLeft <= 0) {
      throw _riderError(
        RiderErrorCode.pickupCodeLocked,
        423,
        details: {'attempts_remaining': 0},
      );
    }
    if (task.storeProgress != StoreOrderProgress.ready) {
      // Order not PACKED yet (T9 guard).
      throw _error(
        ApiErrorCode.invalidStateTransition,
        409,
        details: {'status': 'AT_STORE', 'order_status': 'PACKING'},
      );
    }
    final parts = orderCode.toUpperCase().split(':');
    final code = parts.length == 3 && parts[0] == 'JQC1'
        ? (parts[1] == task.orderNumber.toUpperCase() ? parts[2] : '')
        : orderCode.toUpperCase();
    if (code != pickupCode) {
      _pickupAttemptsLeft -= 1;
      if (_pickupAttemptsLeft <= 0) {
        throw _riderError(
          RiderErrorCode.pickupCodeLocked,
          423,
          details: {'attempts_remaining': 0},
        );
      }
      throw _riderError(
        RiderErrorCode.pickupCodeInvalid,
        400,
        details: {'attempts_remaining': _pickupAttemptsLeft},
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
    final now = _clock().toUtc();
    return _update(
      task.copyWith(
        status: TaskStatus.atCustomer,
        arrivedCustomerAt: now,
        notReachableAfter: now.add(kNotReachableWait),
      ),
    );
  }

  @override
  Future<CodQr> createCodQr(int taskId) async {
    await _call('createCodQr');
    final task = _require(taskId, TaskStatus.atCustomer);
    if (!task.isCod) {
      throw _error(ApiErrorCode.invalidStateTransition, 409);
    }
    final existing = task.codQr;
    if (existing != null && existing.status == UpiQrStatus.pending) {
      return existing;
    }
    final qr = CodQr(
      imageUrl: null,
      amount: task.codAmountDue!,
      status: UpiQrStatus.pending,
      expiresAt: _clock().toUtc().add(const Duration(minutes: 15)),
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
    // The contract checks the COD collection before the OTP, and a
    // mismatch does not use an attempt.
    if (task.isCod) {
      if (codMode == null ||
          codAmount == null ||
          !isSameAmount(codAmount, task.codAmountDue ?? '')) {
        throw _error(
          ApiErrorCode.validationError,
          400,
          details: {
            'cod': {
              'amount': ['Collect exactly ${task.codAmountDue}.'],
            },
            'amount_due': task.codAmountDue,
          },
        );
      }
      if (codMode == CodMode.upi && task.codQr?.status != UpiQrStatus.paid) {
        throw _error(
          ApiErrorCode.validationError,
          400,
          details: {
            'cod': ['The UPI payment is not confirmed yet.'],
          },
        );
      }
    }

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
    return _update(
      task.copyWith(status: TaskStatus.delivered, earningsTotal: '45.00'),
    );
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
    if (report.reason == FailReason.other && report.note.trim().isEmpty) {
      throw _error(
        ApiErrorCode.validationError,
        400,
        details: {
          'note': ['This field is required.'],
        },
      );
    }
    if (report.reason == FailReason.notReachable) {
      if (report.callAttempts < kMinCallAttempts) {
        throw _error(
          ApiErrorCode.validationError,
          400,
          details: {
            'call_attempts': ['Call the customer at least 2 times first.'],
          },
        );
      }
      final after =
          task.notReachableAfter ??
          task.arrivedCustomerAt?.add(kNotReachableWait);
      if (after == null || _clock().toUtc().isBefore(after)) {
        throw _error(
          ApiErrorCode.invalidStateTransition,
          409,
          details: {
            'status': task.status.wireValue,
            'reason': 'WAIT_NOT_ELAPSED',
            if (after != null) 'not_reachable_after': after.toIso8601String(),
          },
        );
      }
    }
    // T13: the order DELIVERY_FAILED and the task RETURNING in one call.
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

  /// Ops: the store marked a unit unavailable after the offer (08 T8a), so
  /// the COD amount drops (RD-03). Keeps the offered amount as
  /// `codAmountChangedFrom`.
  static const changedCodAmount = '990.00';

  void changeCodAmount([String amount = changedCodAmount]) {
    final task = _task;
    if (task == null || !task.isCod) return;
    _task = task.copyWith(
      codAmountDue: amount,
      codAmountChangedFrom: task.codAmountChangedFrom ?? task.codAmountDue,
    );
  }

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

  static ApiError _riderError(
    RiderErrorCode code,
    int status, {
    Map<String, Object?> details = const {},
  }) => ApiError(
    code: ApiErrorCode.unknown,
    rawCode: code.wireValue,
    statusCode: status,
    details: details,
  );

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
