import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/offers/domain/delivery_offer.dart';
import 'package:rider_app/features/task/data/api_task_repository.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_repositories.dart';
import 'package:rider_app/features/task/domain/task_rules.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/shared/errors/rider_error_codes.dart';

import '../../../fixtures/rider_contract_examples.dart';
import '../../../helpers/canned_http.dart';

const _current = '/api/v1/rider/tasks/current/';
const _offer = '/api/v1/rider/offers/current/';

Map<String, Object?> get _task =>
    currentTaskAtStoreExample['task']! as Map<String, Object?>;

/// The example task changed for one test.
Map<String, Object?> _taskWith(Map<String, Object?> changes) => {
  ..._task,
  ...changes,
};

void main() {
  late CannedAdapter http;
  late ApiTaskRepository repo;

  setUp(() {
    http = CannedAdapter();
    repo = ApiTaskRepository(cannedApi(http));
  });

  group('offers', () {
    test('the current offer, with the server time for the countdown', () async {
      http.answers[_offer] = const Canned(200, codOfferExample);
      final received = (await repo.fetchCurrentOffer())!;
      final offer = received.offer;
      expect(offer.id, 9001);
      expect(offer.taskId, 7001);
      expect(offer.paymentType, PaymentType.cod);
      expect(offer.codAmount, '498.00');
      expect(offer.estimatedPayout, '42.00');
      expect(offer.itemCount, 3);
      expect(offer.expiresAt, DateTime.utc(2026, 11, 10, 9, 30, 30));
      expect(received.serverNow, DateTime.utc(2026, 11, 10, 9, 30, 0, 120));
    });

    test('no offer is null; no push channel is bound', () async {
      http.answers[_offer] = const Canned(200, {
        'offer': null,
        'server_time': '2026-11-10T09:30:00Z',
      });
      expect(await repo.fetchCurrentOffer(), isNull);
      expect(await repo.events.isEmpty, isTrue);
    });

    test('accept returns the task; the race arrives as OFFER_TAKEN', () async {
      http.answers['/api/v1/rider/offers/9001/accept/'] = Canned(
        200,
        _taskWith({'status': 'ASSIGNED'}),
      );
      final task = await repo.accept(9001);
      expect(task.status, TaskStatus.assigned);

      http.answers['/api/v1/rider/offers/9002/accept/'] = Canned(
        409,
        errorBody('OFFER_TAKEN'),
      );
      await expectLater(
        repo.accept(9002),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.offerTaken,
          ),
        ),
      );
    });

    test('reject sends the reason, or none', () async {
      const path = '/api/v1/rider/offers/9001/reject/';
      http.answers[path] = const Canned(204);
      await repo.reject(9001, reason: OfferRejectReason.tooFar);
      expect(http.jsonBody(path), {'reason': 'TOO_FAR'});
      await repo.reject(9001);
      expect(http.jsonBody(path), isNot(contains('reason')));
    });
  });

  group('current task', () {
    test('restores every field the steps need from the contract', () async {
      http.answers[_current] = const Canned(200, currentTaskAtStoreExample);
      final current = await repo.fetchCurrentTask();
      final task = current.task!;

      expect(task.id, 7001);
      expect(task.status, TaskStatus.atStore);
      expect(task.storeProgress, StoreOrderProgress.ready);
      expect(task.isCod, isTrue);
      expect(task.codAmountDue, '498.00');
      expect(task.codAmountChangedFrom, isNull);
      expect(task.store.phone, '+911244001122');
      expect(task.store.location, const GeoPoint(28.4718, 77.0436));
      final customer = task.customer!;
      expect(customer.name, 'Asha Verma');
      expect(customer.phone, '+919876543210');
      expect(
        customer.address,
        'Flat 402, Tower B, Sunshine Apartments, MG Road, Sector 21, '
        'Gurugram, 122016',
      );
      expect(customer.landmark, 'Opposite City Mall');
      expect(customer.chips, [DeliveryChip.dontRingBell]);
      expect(customer.instructions, "Leave with the guard if I don't answer");
      expect(task.dropLocality, 'Sector 21, Gurugram');
      expect(task.items.first.unit, '1 L');
      expect(task.itemCount, 3);
      expect(task.payout, '42.00');
      expect(task.otpLength, 4);
      expect(task.otpAttemptsRemaining, 5);
      expect(task.otpLocked, isFalse);
      expect(task.codQr, isNull);
      expect(current.recentTask, isNull);
      expect(current.serverTime, isNotNull);
    });

    test('store progress follows order_status and ready_for_pickup', () async {
      Future<StoreOrderProgress> progress(String status, bool ready) async {
        http.answers[_current] = Canned(200, {
          ...currentTaskAtStoreExample,
          'task': _taskWith({
            'order_status': status,
            'ready_for_pickup': ready,
          }),
        });
        return (await repo.fetchCurrentTask()).task!.storeProgress;
      }

      expect(await progress('PACKING', false), StoreOrderProgress.packing);
      expect(await progress('ACCEPTED', true), StoreOrderProgress.ready);
      expect(await progress('PACKED', false), StoreOrderProgress.ready);
      expect(
        await progress('OUT_FOR_DELIVERY', false),
        StoreOrderProgress.handedOver,
      );
      expect(
        await progress('SOMETHING_NEW', false),
        StoreOrderProgress.packing,
      );
    });

    test('a just-ended task comes back as recent_task', () async {
      http.answers[_current] = const Canned(200, currentTaskCancelledExample);
      final current = await repo.fetchCurrentTask();
      expect(current.task, isNull);
      expect(current.recentTask!.status, TaskStatus.cancelled);
      expect(current.recentTask!.orderNumber, 'JV-261110-001203');
    });

    test('the UPI QR, the OTP lock and the earnings are restored', () async {
      http.answers[_current] = Canned(200, {
        ...currentTaskAtStoreExample,
        'task': _taskWith({
          'status': 'AT_CUSTOMER',
          'order_status': 'OUT_FOR_DELIVERY',
          'arrived_customer_at': '2026-11-10T09:50:00Z',
          'not_reachable_after': '2026-11-10T10:00:00Z',
          'cod_amount_previous': '549.00',
          'delivery_otp': {
            'length': 4,
            'attempts_remaining': 0,
            'locked': true,
          },
          'cod_qr': {
            'qr_id': 'qr_1',
            'image_url': 'https://rzp.example/qr.png',
            'amount': '498.00',
            'status': 'PAID',
            'expires_at': '2026-11-10T10:05:00Z',
          },
          'earnings': {'total': '42.00', 'lines': <Object>[]},
          'store': {..._task['store']! as Map<String, Object?>, 'phone': ''},
          'instructions': {
            'chips': ['LEAVE_AT_DOOR', 'NEW_CHIP'],
            'note': '  ',
          },
        }),
      });
      final task = (await repo.fetchCurrentTask()).task!;
      expect(task.status, TaskStatus.atCustomer);
      expect(task.storeProgress, StoreOrderProgress.handedOver);
      expect(task.arrivedCustomerAt, DateTime.utc(2026, 11, 10, 9, 50));
      expect(task.notReachableAfter, DateTime.utc(2026, 11, 10, 10));
      expect(task.codAmountChangedFrom, '549.00');
      expect(task.otpLocked, isTrue);
      expect(task.otpAttemptsRemaining, 0);
      expect(task.codQr!.status, UpiQrStatus.paid);
      expect(task.codQr!.imageUrl, 'https://rzp.example/qr.png');
      expect(task.earningsTotal, '42.00');
      expect(task.store.phone, isNull);
      expect(task.customer!.chips, [DeliveryChip.leaveAtDoor]);
      expect(task.customer!.instructions, isNull);
    });
  });

  group('steps', () {
    test(
      'arrived-store sends the fix; OUTSIDE_GEOFENCE keeps details',
      () async {
        const path = '/api/v1/rider/tasks/7001/arrived-store/';
        http.answers[path] = Canned(
          422,
          errorBody('OUTSIDE_GEOFENCE', {'distance_m': 640, 'radius_m': 200}),
        );
        await expectLater(
          repo.arrivedAtStore(7001, const GeoPoint(28.1, 77.2)),
          throwsA(
            isA<ApiError>()
                .having((e) => e.code, 'code', ApiErrorCode.outsideGeofence)
                .having((e) => e.details['distance_m'], 'distance', 640),
          ),
        );
        expect(http.jsonBody(path), {'lat': 28.1, 'lng': 77.2});

        http.answers[path] = Canned(200, _task);
        expect(
          (await repo.arrivedAtStore(7001, const GeoPoint(1, 2))).id,
          7001,
        );
      },
    );

    test('pickup sends the order code; a wrong one keeps attempts', () async {
      const path = '/api/v1/rider/tasks/7001/pickup/';
      http.answers[path] = Canned(
        400,
        errorBody('PICKUP_CODE_INVALID', {'attempts_remaining': 3}),
      );
      final error = await repo
          .pickup(7001, 'JQC1:JV-261110-001203:7K2P')
          .then<ApiError?>((_) => null, onError: (Object e) => e as ApiError);
      expect(http.jsonBody(path), {'order_code': 'JQC1:JV-261110-001203:7K2P'});
      expect(error!.riderCode, RiderErrorCode.pickupCodeInvalid);
      expect(error.attemptsRemaining, 3);

      http.answers[path] = Canned(200, _taskWith({'status': 'PICKED_UP'}));
      expect((await repo.pickup(7001, '7K2P')).status, TaskStatus.pickedUp);
    });

    test('arrived-customer sends the override reason when given', () async {
      const path = '/api/v1/rider/tasks/7001/arrived-customer/';
      http.answers[path] = Canned(200, _taskWith({'status': 'AT_CUSTOMER'}));
      await repo.arrivedAtCustomer(
        7001,
        const GeoPoint(28.5, 77.0),
        overrideReason: 'GPS drift',
      );
      expect(http.jsonBody(path), {
        'lat': 28.5,
        'lng': 77.0,
        'override_reason': 'GPS drift',
      });
    });

    test('cod-qr returns the QR as the server sends it', () async {
      http.answers['/api/v1/rider/tasks/7001/cod-qr/'] = const Canned(
        200,
        codQrWaitingExample,
      );
      final qr = await repo.createCodQr(7001);
      expect(qr.status, UpiQrStatus.pending);
      expect(qr.amount, codQrWaitingExample['amount']);
      expect(qr.imageUrl, startsWith('https://'));
    });

    test(
      'deliver: the OTP, and for COD the mode and the exact amount due',
      () async {
        const path = '/api/v1/rider/tasks/7001/deliver/';
        http.answers[path] = const Canned(200, deliveredTaskExample);
        final task = await repo.deliver(
          7001,
          otp: '4321',
          codMode: CodMode.cash,
          codAmount: '498.00',
        );
        expect(http.jsonBody(path), {
          'otp': '4321',
          'cod': {'mode': 'cash', 'amount': '498.00'},
        });
        expect(task.status, TaskStatus.delivered);

        await repo.deliver(7001, otp: '4321');
        expect(http.jsonBody(path), {'otp': '4321'});

        await repo.deliver(
          7001,
          otp: '4321',
          codMode: CodMode.upi,
          codAmount: '498.00',
        );
        expect(http.jsonBody(path)['cod'], {'mode': 'upi', 'amount': '498.00'});
      },
    );

    test('deliver: DELIVERY_OTP_LOCKED maps', () async {
      const path = '/api/v1/rider/tasks/7001/deliver/';
      http.answers[path] = Canned(423, errorBody('DELIVERY_OTP_LOCKED'));
      await expectLater(
        repo.deliver(7001, otp: '1111'),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.deliveryOtpLocked,
          ),
        ),
      );
    });

    test('fail is multipart with the reason, note, calls and photo', () async {
      const path = '/api/v1/rider/tasks/7001/fail/';
      http.answers[path] = Canned(200, _taskWith({'status': 'RETURNING'}));
      final task = await repo.fail(
        7001,
        const FailReport(
          reason: FailReason.notReachable,
          note: 'Gate locked',
          callAttempts: 2,
          photo: [1, 2, 3],
        ),
      );
      expect(task.status, TaskStatus.returning);
      final form = http.bodies[path]! as FormData;
      expect(
        {for (final f in form.fields) f.key: f.value},
        {
          'reason': 'CUSTOMER_NOT_REACHABLE',
          'note': 'Gate locked',
          'call_attempts': '2',
        },
      );
      expect(form.files.single.key, 'photo');
      expect(form.files.single.value.contentType.toString(), 'image/jpeg');

      for (final (reason, wire) in [
        (FailReason.refused, 'CUSTOMER_REFUSED'),
        (FailReason.wrongAddress, 'WRONG_ADDRESS'),
        (FailReason.other, 'OTHER'),
      ]) {
        await repo.fail(7001, FailReport(reason: reason));
        final sent = http.bodies[path]! as FormData;
        expect({for (final f in sent.fields) f.key: f.value}['reason'], wire);
        expect(sent.fields.map((f) => f.key), isNot(contains('note')));
        expect(sent.files, isEmpty);
      }
    });

    test('a lost connection is a network ApiError', () async {
      http.answers[_current] = const Canned.offline();
      await expectLater(
        repo.fetchCurrentTask(),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.network),
        ),
      );
    });
  });
}
