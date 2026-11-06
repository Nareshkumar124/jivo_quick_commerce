import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' as api;
import 'package:jivo_core/jivo_core.dart';

import '../../offers/domain/delivery_offer.dart';
import '../domain/rider_task.dart';
import '../domain/task_repositories.dart';
import '../domain/task_rules.dart';
import '../domain/task_status.dart';

/// The rider offer and task endpoints through the generated client (slice
/// 5.3/5.4 contract, T-515b): offers, the delivery steps, the UPI QR and
/// `deliver` with the COD collection.
///
/// Offer events: no push channel is bound here yet (FCM `offer.new` wakes
/// the app, the WebSocket is P6), so [events] is empty and the offer
/// controller's polling of `GET /rider/offers/current/` finds offers.
class ApiTaskRepository
    implements OfferRepository, OfferEventSource, TaskRepository {
  ApiTaskRepository(this._api);

  final api.JivoApi _api;

  api.RiderApi get _rider => _api.getRiderApi();

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  // ------------------------------------------------------------- offers

  @override
  Stream<OfferEvent> get events => const Stream.empty();

  @override
  Future<ReceivedOffer?> fetchCurrentOffer() => _call(() async {
    final body = (await _rider.riderOffersCurrent()).data!;
    final offer = body.offer;
    if (offer == null) return null;
    return ReceivedOffer(offerOf(offer), serverNow: body.serverTime);
  });

  @override
  Future<RiderTask> accept(int offerId) => _call(
    () async =>
        riderTaskOf((await _rider.riderOffersAccept(id: offerId)).data!),
  );

  @override
  Future<void> reject(int offerId, {OfferRejectReason? reason}) => _call(
    () => _rider.riderOffersReject(
      id: offerId,
      offerRejectRequest: api.OfferRejectRequest(
        reason: switch (reason) {
          null => null,
          OfferRejectReason.tooFar => api.OfferRejectReasonEnum.TOO_FAR,
          OfferRejectReason.vehicleIssue =>
            api.OfferRejectReasonEnum.VEHICLE_ISSUE,
          OfferRejectReason.onBreak => api.OfferRejectReasonEnum.ON_BREAK,
          OfferRejectReason.other => api.OfferRejectReasonEnum.OTHER,
        },
      ),
    ),
  );

  // -------------------------------------------------------------- tasks

  @override
  Future<CurrentTask> fetchCurrentTask() => _call(() async {
    final body = (await _rider.riderTasksCurrent()).data!;
    final recent = body.recentTask;
    return CurrentTask(
      task: switch (body.task) {
        final task? => riderTaskOf(task),
        null => null,
      },
      recentTask: recent == null
          ? null
          : RecentTask(
              id: recent.id,
              orderNumber: recent.orderNumber,
              status: TaskStatus.fromWire(recent.status.value),
              endedAt: recent.endedAt,
            ),
      serverTime: body.serverTime,
    );
  });

  @override
  Future<RiderTask> arrivedAtStore(int taskId, GeoPoint at) => _call(
    () async => riderTaskOf(
      (await _rider.riderTasksArrivedStore(
        id: taskId,
        positionRequest: api.PositionRequest(lat: at.lat, lng: at.lng),
      )).data!,
    ),
  );

  @override
  Future<RiderTask> pickup(int taskId, String orderCode) => _call(
    () async => riderTaskOf(
      (await _rider.riderTasksPickup(
        id: taskId,
        pickupRequest: api.PickupRequest(orderCode: orderCode),
      )).data!,
    ),
  );

  @override
  Future<RiderTask> arrivedAtCustomer(
    int taskId,
    GeoPoint at, {
    String? overrideReason,
  }) => _call(
    () async => riderTaskOf(
      (await _rider.riderTasksArrivedCustomer(
        id: taskId,
        arrivedCustomerRequest: api.ArrivedCustomerRequest(
          lat: at.lat,
          lng: at.lng,
          overrideReason: overrideReason,
        ),
      )).data!,
    ),
  );

  @override
  Future<CodQr> createCodQr(int taskId) => _call(
    () async => codQrOf((await _rider.riderTasksCodQr(id: taskId)).data!),
  );

  @override
  Future<RiderTask> deliver(
    int taskId, {
    required String otp,
    CodMode? codMode,
    String? codAmount,
  }) => _call(
    () async => riderTaskOf(
      (await _rider.riderTasksDeliver(
        id: taskId,
        deliverRequest: api.DeliverRequest(
          otp: otp,
          cod: codMode == null || codAmount == null
              ? null
              : api.CodCollectionRequest(
                  mode: switch (codMode) {
                    CodMode.cash => api.CodModeEnum.cash,
                    CodMode.upi => api.CodModeEnum.upi,
                  },
                  amount: codAmount,
                ),
        ),
      )).data!,
    ),
  );

  @override
  Future<RiderTask> fail(int taskId, FailReport report) => _call(
    () async => riderTaskOf(
      (await _rider.riderTasksFail(
        id: taskId,
        reason: switch (report.reason) {
          FailReason.notReachable =>
            api.DeliveryFailReasonEnum.CUSTOMER_NOT_REACHABLE,
          FailReason.refused => api.DeliveryFailReasonEnum.CUSTOMER_REFUSED,
          FailReason.wrongAddress => api.DeliveryFailReasonEnum.WRONG_ADDRESS,
          FailReason.other => api.DeliveryFailReasonEnum.OTHER,
        },
        note: report.note.isEmpty ? null : report.note,
        callAttempts: report.callAttempts,
        photo: switch (report.photo) {
          final bytes? => MultipartFile.fromBytes(
            bytes,
            filename: 'failed-delivery.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
          null => null,
        },
      )).data!,
    ),
  );
}

// ------------------------------------------------------------- mapping

DeliveryOffer offerOf(api.RiderOffer offer) => DeliveryOffer(
  id: offer.id,
  taskId: offer.taskId,
  itemCount: offer.itemCount,
  storeName: offer.storeName,
  dropLocality: offer.dropLocality,
  distanceKm: offer.distanceKm,
  paymentType: PaymentType.fromWire(offer.paymentType.value),
  codAmount: offer.codAmount,
  estimatedPayout: offer.estimatedPayout,
  expiresAt: offer.expiresAt,
);

/// The order's state at the store, from `order_status` and
/// `ready_for_pickup`.
StoreOrderProgress storeProgressOf(api.RiderTask task) {
  switch (task.orderStatus) {
    case api.OrderStatusEnum.PACKED:
      return StoreOrderProgress.ready;
    case api.OrderStatusEnum.PAYMENT_PENDING:
    case api.OrderStatusEnum.PLACED:
    case api.OrderStatusEnum.ACCEPTED:
    case api.OrderStatusEnum.PACKING:
    case api.OrderStatusEnum.unknownDefaultOpenApi:
      return task.readyForPickup
          ? StoreOrderProgress.ready
          : StoreOrderProgress.packing;
    case api.OrderStatusEnum.OUT_FOR_DELIVERY:
    case api.OrderStatusEnum.DELIVERED:
    case api.OrderStatusEnum.CANCELLED:
    case api.OrderStatusEnum.PAYMENT_FAILED:
    case api.OrderStatusEnum.DELIVERY_FAILED:
    case api.OrderStatusEnum.RETURNED:
      return StoreOrderProgress.handedOver;
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// "Flat 12, Tower B, Sector 21, Noida, 201301" from the address parts.
String addressLineOf(api.OrderAddress address) => [
  address.house,
  address.buildingStreet,
  address.area,
  address.city,
  address.pincode,
].map((part) => part.trim()).where((part) => part.isNotEmpty).join(', ');

DeliveryChip? deliveryChipOf(
  api.DeliveryInstructionChipEnum chip,
) => switch (chip) {
  api.DeliveryInstructionChipEnum.DONT_RING_BELL => DeliveryChip.dontRingBell,
  api.DeliveryInstructionChipEnum.LEAVE_AT_DOOR => DeliveryChip.leaveAtDoor,
  api.DeliveryInstructionChipEnum.AVOID_CALLING => DeliveryChip.avoidCalling,
  _ => null,
};

TaskCustomer customerOf(api.RiderTask task) {
  final address = task.customerAddress;
  return TaskCustomer(
    name: address.receiverName,
    phone: address.receiverPhone,
    address: addressLineOf(address),
    location: GeoPoint(address.lat, address.lng),
    landmark: _blankToNull(address.landmark),
    instructions: _blankToNull(task.instructions.note),
    chips: [for (final chip in task.instructions.chips) ?deliveryChipOf(chip)],
  );
}

CodQr codQrOf(api.CodQr qr) => CodQr(
  imageUrl: qr.imageUrl,
  amount: qr.amount,
  status: UpiQrStatus.fromWire(qr.status.value),
  expiresAt: qr.expiresAt,
);

RiderTask riderTaskOf(api.RiderTask task) => RiderTask(
  id: task.id,
  status: TaskStatus.fromWire(task.status.value),
  orderNumber: task.orderNumber,
  store: TaskStore(
    name: task.store.name,
    address: task.store.address,
    location: GeoPoint(task.store.lat, task.store.lng),
    phone: _blankToNull(task.store.phone),
  ),
  storeProgress: storeProgressOf(task),
  paymentType: PaymentType.fromWire(task.paymentType.value),
  items: [
    for (final item in task.items)
      TaskItem(
        name: item.name,
        unit: _blankToNull(item.variant),
        quantity: item.quantity,
      ),
  ],
  customer: customerOf(task),
  dropLocality: _blankToNull(
    [
      task.customerAddress.area,
      task.customerAddress.city,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(', '),
  ),
  codAmountDue: task.codAmountDue,
  codAmountChangedFrom: task.codAmountPrevious,
  payout: task.estimatedPayout,
  distanceKm: task.distanceKm,
  arrivedCustomerAt: task.arrivedCustomerAt,
  notReachableAfter: task.notReachableAfter,
  itemCount: task.itemCount,
  earningsTotal: task.earnings?.total,
  otpLength: task.deliveryOtp.length,
  otpAttemptsRemaining: task.deliveryOtp.attemptsRemaining,
  otpLocked: task.deliveryOtp.locked,
  codQr: switch (task.codQr) {
    final qr? => codQrOf(qr),
    null => null,
  },
);
