import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_repositories.dart';
import 'package:rider_app/features/task/domain/task_rules.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/features/task/presentation/task_block.dart';
import 'package:rider_app/features/task/presentation/task_flow_controller.dart';
import 'package:rider_app/shared/errors/rider_error_codes.dart';

import '../../../helpers/rider_app_harness.dart';

const activePhone = '+919811122231';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RiderTestHarness h;
  late ProviderContainer c;

  TaskFlowState state() => c.read(taskFlowControllerProvider);
  TaskFlowController flow() => c.read(taskFlowControllerProvider.notifier);
  FakeTaskBackend server() => h.tasks;

  /// An ACTIVE rider, signed in, the task controller loaded.
  Future<void> start({RiderTask? seeded}) async {
    h = RiderTestHarness();
    if (seeded != null) h.tasks.seedTask(seeded);
    await h.signedInBefore(activePhone);
    c = await h.container();
    c.listen(taskFlowControllerProvider, (_, _) {});
    await c.read(riderAccountControllerProvider.notifier).load();
    await flow().load();
  }

  RiderTask task(TaskStatus status, {bool cod = false}) {
    final t = FakeTaskBackend(delay: Duration.zero)
        .newTask(cod: cod, status: status);
    return status == TaskStatus.atCustomer
        ? t.copyWith(arrivedCustomerAt: DateTime.utc(2026, 11, 2, 6))
        : t;
  }

  group('restore from GET /rider/tasks/current/', () {
    test('no task: idle, nothing blocks going offline', () async {
      await start();
      expect(state().loaded, isTrue);
      expect(state().task, isNull);
      expect(c.read(taskBlocksGoingOfflineProvider), isFalse);
    });

    test('every rider-visible state is restored exactly', () async {
      for (final status in [
        TaskStatus.assigned,
        TaskStatus.atStore,
        TaskStatus.pickedUp,
        TaskStatus.atCustomer,
        TaskStatus.failed,
        TaskStatus.returning,
      ]) {
        await start(seeded: task(status));
        expect(state().task?.status, status, reason: '$status');
        expect(
          c.read(taskBlocksGoingOfflineProvider),
          status.blocksGoingOffline,
          reason: '$status blocks going offline',
        );
      }
    });

    test(
      'an ended task is only `recent_task`: a fresh start shows none',
      () async {
        for (final status in [
          TaskStatus.delivered,
          TaskStatus.returned,
          TaskStatus.cancelled,
        ]) {
          await start(seeded: task(status));
          expect(state().task, isNull, reason: '$status');
          expect(c.read(taskBlocksGoingOfflineProvider), isFalse);
        }
      },
    );

    test('dispatch-only states are not shown to the rider', () async {
      await start(seeded: task(TaskStatus.searching));
      expect(state().task, isNull);
    });

    test('server-anchored values survive a restart: OTP attempts, lock, '
        'arrival time, UPI status', () async {
      final seeded = task(TaskStatus.atCustomer, cod: true).copyWith(
        otpAttemptsRemaining: 2,
        codQr: const CodQr(
          imageUrl: null,
          amount: '1249.00',
          status: UpiQrStatus.paid,
        ),
      );
      await start(seeded: seeded);
      final restored = state().task!;
      expect(restored.otpAttemptsRemaining, 2);
      expect(restored.arrivedCustomerAt, DateTime.utc(2026, 11, 2, 6));
      expect(restored.codQr?.status, UpiQrStatus.paid);
    });
  });

  group('actions (each only from its 08 §3 state)', () {
    test('ASSIGNED → AT_STORE sends the GPS fix', () async {
      await start(seeded: task(TaskStatus.assigned));
      expect(await flow().arrivedAtStore(), isTrue);
      expect(state().task!.status, TaskStatus.atStore);
      expect(h.locationReader.reads, 1);
      expect(server().calls.last, 'arrivedAtStore');
    });

    test('AT_STORE → PICKED_UP with the code, only once PACKED', () async {
      await start(seeded: task(TaskStatus.atStore));
      expect(await flow().pickup('7k2p'), isFalse);
      expect(state().error?.code, ApiErrorCode.invalidStateTransition);
      expect(state().task!.status, TaskStatus.atStore);

      server().markPacked();
      expect(await flow().pickup('AAAA'), isFalse);
      expect(state().error?.riderCode, RiderErrorCode.pickupCodeInvalid);
      expect(state().pickupAttemptsRemaining, 4);
      expect(state().task!.status, TaskStatus.atStore);

      expect(await flow().pickup('7k2p'), isTrue);
      expect(state().task!.status, TaskStatus.pickedUp);
    });

    test('a scanned bag QR is sent whole; a label for another order is not '
        'sent', () async {
      final seeded = task(TaskStatus.atStore);
      await start(seeded: seeded);
      server().markPacked();
      final calls = server().calls.length;
      expect(await flow().pickup('JQC1:JV-OTHER:7K2P'), isFalse);
      expect(state().localError, TaskLocalError.invalidPickupCode);
      expect(server().calls.length, calls, reason: 'no call made');

      expect(await flow().pickup('JQC1:${seeded.orderNumber}:7k2p'), isTrue);
      expect(state().task!.status, TaskStatus.pickedUp);
    });

    test('5 wrong codes: PICKUP_CODE_LOCKED (423), no more tries', () async {
      await start(seeded: task(TaskStatus.atStore));
      server().markPacked();
      for (var left = 4; left >= 1; left--) {
        expect(await flow().pickup('AAAA'), isFalse);
        expect(state().pickupAttemptsRemaining, left);
        expect(state().pickupLocked, isFalse);
      }
      expect(await flow().pickup('AAAA'), isFalse);
      expect(state().error?.riderCode, RiderErrorCode.pickupCodeLocked);
      expect(state().error?.statusCode, 423);
      expect(state().pickupLocked, isTrue);
      expect(state().pickupAttemptsRemaining, 0);

      final calls = server().calls.length;
      expect(await flow().pickup('7K2P'), isFalse);
      expect(state().localError, TaskLocalError.pickupLocked);
      expect(server().calls.length, calls, reason: 'locked: no call');
      // The rider codes are certain answers: no reconcile fetch.
      expect(server().calls.where((c) => c == 'fetchCurrentTask').length, 1);
    });

    test('PICKED_UP → AT_CUSTOMER, with the server\'s arrival time', () async {
      await start(seeded: task(TaskStatus.pickedUp));
      expect(await flow().arrivedAtCustomer(), isTrue);
      expect(state().task!.status, TaskStatus.atCustomer);
      expect(state().task!.arrivedCustomerAt, isNotNull);
    });

    test('AT_CUSTOMER → DELIVERED (prepaid)', () async {
      await start(seeded: task(TaskStatus.atCustomer));
      expect(await flow().deliver(otp: FakeTaskBackend.deliveryOtp), isTrue);
      expect(state().task!.status, TaskStatus.delivered);
      expect(c.read(taskBlocksGoingOfflineProvider), isFalse);
    });

    test('AT_CUSTOMER → DELIVERED (COD cash): the server\'s amount, '
        'unchanged', () async {
      await start(seeded: task(TaskStatus.atCustomer, cod: true));
      expect(
        await flow().deliver(otp: FakeTaskBackend.deliveryOtp),
        isFalse,
        reason: 'no collection',
      );
      expect(state().localError, TaskLocalError.codIncomplete);
      expect(server().calls, isNot(contains(startsWith('deliver'))));

      expect(
        await flow().deliver(
          otp: FakeTaskBackend.deliveryOtp,
          collection: const CodCollection.cash(cashConfirmed: true),
        ),
        isTrue,
      );
      expect(server().calls.last, 'deliver cash 1249.00');
    });

    test('COD UPI: QR, then deliver only after the server confirms', () async {
      await start(seeded: task(TaskStatus.atCustomer, cod: true));
      expect(await flow().createCodQr(), isTrue);
      expect(state().task!.codQr!.status, UpiQrStatus.pending);
      expect(
        await flow().deliver(
          otp: FakeTaskBackend.deliveryOtp,
          collection: const CodCollection.upi(),
        ),
        isFalse,
      );

      server().markUpiPaid();
      await flow().load();
      expect(state().task!.codQr!.status, UpiQrStatus.paid);
      expect(
        await flow().deliver(
          otp: FakeTaskBackend.deliveryOtp,
          collection: const CodCollection.upi(),
        ),
        isTrue,
      );
      expect(server().calls.last, 'deliver upi 1249.00');
    });

    test('PICKED_UP / AT_CUSTOMER → FAILED → RETURNING → RETURNED', () async {
      await start(seeded: task(TaskStatus.pickedUp));
      expect(
        await flow().fail(const FailReport(reason: FailReason.wrongAddress)),
        isTrue,
      );
      expect(state().task!.status, TaskStatus.returning);
      expect(c.read(taskBlocksGoingOfflineProvider), isTrue);

      server().markReturned();
      await flow().load();
      expect(state().task!.status, TaskStatus.returned);
      expect(c.read(taskBlocksGoingOfflineProvider), isFalse);

      flow().finish();
      expect(state().task, isNull);
    });

    test(
      'ASSIGNED / AT_STORE → CANCELLED (order cancelled before pickup)',
      () async {
        await start(seeded: task(TaskStatus.atStore));
        server().cancelOrder();
        await flow().load();
        expect(state().task!.status, TaskStatus.cancelled);
        flow().finish();
        expect(state().hasTask, isFalse);
      },
    );

    test(
      'slice 5.3: a lost answer explained by recent_task (delivered)',
      () async {
        await start(seeded: task(TaskStatus.atCustomer));
        server().applyThenFailNext = const ApiError(code: ApiErrorCode.network);
        expect(await flow().deliver(otp: FakeTaskBackend.deliveryOtp), isFalse);
        // The reconcile saw task: null, recent_task: DELIVERED for this id.
        expect(state().task!.status, TaskStatus.delivered);
        expect(state().notice, isNull);
        expect(state().error, isNull);
      },
    );

    test(
      'fail sends call_attempts; CUSTOMER_NOT_REACHABLE needs 2 calls',
      () async {
        final seeded = task(TaskStatus.atCustomer).copyWith(
          arrivedCustomerAt: h.now.subtract(const Duration(minutes: 11)),
          notReachableAfter: h.now.subtract(const Duration(minutes: 1)),
        );
        await start(seeded: seeded);
        await flow().callCustomer();
        await flow().callCustomer();
        expect(
          await flow().fail(const FailReport(reason: FailReason.notReachable)),
          isTrue,
        );
        expect(state().task!.status, TaskStatus.returning);
      },
    );

    test('409 WAIT_NOT_ELAPSED: the server wait wins, no reconcile', () async {
      final seeded = task(TaskStatus.atCustomer).copyWith(
        arrivedCustomerAt: h.now.subtract(const Duration(minutes: 11)),
        notReachableAfter: h.now.subtract(const Duration(minutes: 1)),
      );
      await start(seeded: seeded);
      // The server's clock says 2 more minutes.
      final serverAfter = h.now.add(const Duration(minutes: 2));
      server().seedTask(seeded.copyWith(notReachableAfter: serverAfter));
      await flow().callCustomer();
      await flow().callCustomer();
      final fetches = server().calls.where((c) => c == 'fetchCurrentTask');
      final before = fetches.length;

      expect(
        await flow().fail(const FailReport(reason: FailReason.notReachable)),
        isFalse,
      );
      expect(state().error?.isWaitNotElapsed, isTrue);
      expect(state().task!.notReachableAfter, serverAfter);
      expect(state().task!.status, TaskStatus.atCustomer);
      expect(
        server().calls.where((c) => c == 'fetchCurrentTask').length,
        before,
      );
      expect(
        notReachableWaitLeft(state().task!, h.now),
        const Duration(minutes: 2),
      );
    });

    test('deliver 400 with amount_due: the server amount is shown, the '
        'error kept', () async {
      await start(seeded: task(TaskStatus.atCustomer, cod: true));
      server().changeCodAmount();
      expect(
        await flow().deliver(
          otp: FakeTaskBackend.deliveryOtp,
          collection: const CodCollection.cash(cashConfirmed: true),
        ),
        isFalse,
      );
      expect(state().error?.codAmountDueNow, FakeTaskBackend.changedCodAmount);
      expect(state().task!.codAmountDue, FakeTaskBackend.changedCodAmount);
      expect(state().task!.otpAttemptsRemaining, 5, reason: 'no OTP used');

      expect(
        await flow().deliver(
          otp: FakeTaskBackend.deliveryOtp,
          collection: const CodCollection.cash(cashConfirmed: true),
        ),
        isTrue,
      );
      expect(server().calls.last, 'deliver cash 990.00');
    });

    test('UPI before the server saw the payment: 400, not delivered', () async {
      await start(seeded: task(TaskStatus.atCustomer, cod: true));
      expect(await flow().createCodQr(), isTrue);
      // The phone thinks it is paid; the server does not.
      final local = state().task!;
      flow().assigned(
        local.copyWith(codQr: local.codQr!.withStatus(UpiQrStatus.paid)),
      );
      expect(
        await flow().deliver(
          otp: FakeTaskBackend.deliveryOtp,
          collection: const CodCollection.upi(),
        ),
        isFalse,
      );
      expect(state().error?.isUpiNotPaid, isTrue);
      expect(state().task!.status, TaskStatus.atCustomer);
    });

    test('a repeated cod-qr returns the same open QR', () async {
      await start(seeded: task(TaskStatus.atCustomer, cod: true));
      expect(await flow().createCodQr(), isTrue);
      final first = state().task!.codQr!;
      expect(first.expiresAt, isNotNull);
      expect(await flow().createCodQr(), isTrue);
      expect(identical(state().task!.codQr, first), isTrue);
    });

    test('illegal actions make no API call', () async {
      await start(seeded: task(TaskStatus.assigned));
      final before = List.of(server().calls);

      expect(await flow().pickup('7K2P'), isFalse);
      expect(await flow().arrivedAtCustomer(), isFalse);
      expect(await flow().deliver(otp: '4321'), isFalse);
      expect(
        await flow().fail(const FailReport(reason: FailReason.refused)),
        isFalse,
      );
      expect(await flow().createCodQr(), isFalse);

      expect(server().calls, before);
      expect(state().localError, TaskLocalError.notAllowed);
      expect(h.locationReader.reads, 0);
    });

    test('finish does nothing while the task is still active', () async {
      await start(seeded: task(TaskStatus.pickedUp));
      flow().finish();
      expect(state().task!.status, TaskStatus.pickedUp);
    });
  });

  group('errors', () {
    test('OUTSIDE_GEOFENCE keeps the step and the error', () async {
      await start(seeded: task(TaskStatus.assigned));
      server().outsideGeofenceNext = true;
      expect(await flow().arrivedAtStore(), isFalse);
      expect(state().error?.code, ApiErrorCode.outsideGeofence);
      expect(state().error?.details['distance_m'], 450);
      expect(state().task!.status, TaskStatus.assigned);
    });

    test('arrived at customer with an override reason after the geofence '
        'refused it', () async {
      await start(seeded: task(TaskStatus.pickedUp));
      server().outsideGeofenceNext = true;
      expect(await flow().arrivedAtCustomer(), isFalse);
      expect(
        await flow().arrivedAtCustomer(overrideReason: 'PIN_WRONG'),
        isTrue,
      );
      expect(server().calls.last, 'arrivedAtCustomer override');
    });

    test('no GPS fix: nothing is sent', () async {
      await start(seeded: task(TaskStatus.assigned));
      h.locationReader.unavailable = true;
      expect(await flow().arrivedAtStore(), isFalse);
      expect(state().localError, TaskLocalError.locationUnavailable);
      expect(server().calls, isNot(contains('arrivedAtStore')));
    });

    test('wrong OTP: attempts left from the server, then the lock', () async {
      await start(seeded: task(TaskStatus.atCustomer));
      for (var left = 4; left >= 1; left--) {
        expect(await flow().deliver(otp: '0000'), isFalse);
        expect(state().error?.code, ApiErrorCode.deliveryOtpInvalid);
        expect(state().task!.otpAttemptsRemaining, left);
      }
      expect(await flow().deliver(otp: '0000'), isFalse);
      expect(state().error?.code, ApiErrorCode.deliveryOtpLocked);
      expect(state().task!.otpLocked, isTrue);

      // A restart restores the lock from the server.
      await flow().load();
      expect(state().task!.otpLocked, isTrue);
    });

    test('a lost response: the action went through, the screen follows the '
        'server', () async {
      await start(seeded: task(TaskStatus.assigned));
      server().applyThenFailNext = const ApiError(code: ApiErrorCode.network);

      expect(await flow().arrivedAtStore(), isFalse);

      expect(state().task!.status, TaskStatus.atStore);
      expect(state().error, isNull, reason: 'the task moved on');
    });

    test('a failure that did not go through keeps the error', () async {
      await start(seeded: task(TaskStatus.assigned));
      server().failNext = const ApiError(code: ApiErrorCode.timeout);

      expect(await flow().arrivedAtStore(), isFalse);

      expect(state().task!.status, TaskStatus.assigned);
      expect(state().error?.code, ApiErrorCode.timeout);
    });

    test('a lost deliver whose task is no longer listed: "couldn\'t confirm", '
        'never "reassigned"', () async {
      await start(seeded: task(TaskStatus.atCustomer));
      // The server delivered it, the answer was lost, and GET current does
      // not return ended tasks (api-requests #13 undecided).
      server().returnsEndedTasks = false;
      server().applyThenFailNext = const ApiError(code: ApiErrorCode.network);

      expect(await flow().deliver(otp: FakeTaskBackend.deliveryOtp), isFalse);

      expect(state().task, isNull);
      expect(state().notice, TaskNotice.unconfirmed);
      expect(state().hasTask, isTrue, reason: 'the notice is shown');
      expect(c.read(taskBlocksGoingOfflineProvider), isFalse);

      flow().finish();
      expect(state().hasTask, isFalse);
    });

    test(
      'a lost answer, then the task shows up again: the notice clears',
      () async {
        await start(seeded: task(TaskStatus.atCustomer));
        server().returnsEndedTasks = false;
        server().applyThenFailNext = const ApiError(code: ApiErrorCode.timeout);
        await flow().fail(const FailReport(reason: FailReason.refused));
        // fail → RETURNING is still listed, so the reconcile shows it.
        expect(state().notice, isNull);
        expect(state().task!.status, TaskStatus.returning);

        // A pickup whose answer was lost and whose task vanished, then
        // reappears on the next check.
        await start(seeded: task(TaskStatus.atStore));
        server()
          ..markPacked()
          ..applyThenFailNext = const ApiError(code: ApiErrorCode.network);
        final picked = server().task!;
        server().unassign();
        await flow().pickup('7K2P');
        expect(state().notice, TaskNotice.unconfirmed);

        server().seedTask(picked.copyWith(status: TaskStatus.pickedUp));
        await flow().load();
        expect(state().notice, isNull);
        expect(state().task!.status, TaskStatus.pickedUp);
      },
    );

    test('ops unassigned the task: a notice, then idle', () async {
      await start(seeded: task(TaskStatus.atStore));
      server().unassign();
      await flow().load();
      expect(state().task, isNull);
      expect(state().notice, TaskNotice.unassigned);
      expect(state().hasTask, isTrue, reason: 'the notice is shown');
      expect(c.read(taskBlocksGoingOfflineProvider), isFalse);

      flow().finish();
      expect(state().hasTask, isFalse);
    });

    test('426 on an action goes to the update screen, not inline', () async {
      await start(seeded: task(TaskStatus.assigned));
      server().failNext = const ApiError(
        code: ApiErrorCode.appUpdateRequired,
        statusCode: 426,
      );
      await flow().arrivedAtStore();
      expect(state().error, isNull);
      expect(h.signals.current, isA<AppUpdateRequired>());
    });
  });

  test(
    'double tap on "Arrived": one call, even while the GPS fix is slow',
    () async {
      await start(seeded: task(TaskStatus.assigned));
      final hold = Completer<void>();
      h.locationReader.hold = hold;

      final first = flow().arrivedAtStore();
      final second = flow().arrivedAtStore();
      await Future<void>.delayed(Duration.zero);
      hold.complete();
      final results = await Future.wait([first, second]);

      expect(results, [true, false]);
      expect(server().calls.where((c) => c == 'arrivedAtStore'), hasLength(1));
      expect(h.locationReader.reads, 1);
    },
  );

  group('blocks', () {
    test('logout is refused during an active task', () async {
      await start(seeded: task(TaskStatus.pickedUp));
      expect(
        await c.read(riderAccountControllerProvider.notifier).logout(),
        LogoutResult.blockedDuringTask,
      );
      expect(h.session.isSignedIn, isTrue);
    });

    test('logout works again once the task is finished', () async {
      await start(seeded: task(TaskStatus.atCustomer));
      await flow().deliver(otp: FakeTaskBackend.deliveryOtp);
      expect(
        await c.read(riderAccountControllerProvider.notifier).logout(),
        LogoutResult.done,
      );
    });
  });

  test('non-ACTIVE riders never load tasks', () async {
    h = RiderTestHarness();
    h.tasks.seedTask(task(TaskStatus.assigned));
    await h.signedInBefore('+919811122232'); // PENDING_KYC
    c = await h.container();
    c.listen(taskFlowControllerProvider, (_, _) {});
    await c.read(riderAccountControllerProvider.notifier).load();
    await flow().load();

    expect(state().task, isNull);
    expect(h.tasks.calls, isEmpty);
  });

  group('pickup_code restores the pickup lock after a restart', () {
    RiderTask atStore() =>
        task(TaskStatus.atStore)
            .copyWith(storeProgress: StoreOrderProgress.ready);

    test('locked on the server: no more tries from the phone', () async {
      h = RiderTestHarness();
      h.tasks
        ..seedTask(atStore())
        ..pickupAttemptsLeft = 0;
      await h.signedInBefore(activePhone);
      c = await h.container();
      c.listen(taskFlowControllerProvider, (_, _) {});
      await c.read(riderAccountControllerProvider.notifier).load();
      await flow().load();

      expect(state().task!.status, TaskStatus.atStore);
      expect(state().task!.pickupLocked, isTrue);
      expect(state().pickupLocked, isTrue);
      expect(state().pickupAttemptsRemaining, 0);
      final calls = server().calls.length;
      expect(await flow().pickup('7K2P'), isFalse);
      expect(state().localError, TaskLocalError.pickupLocked);
      expect(server().calls.length, calls, reason: 'locked: no call');
    });

    test('attempts left come back; an ops unlock clears the lock', () async {
      h = RiderTestHarness();
      h.tasks
        ..seedTask(atStore())
        ..pickupAttemptsLeft = 2;
      await h.signedInBefore(activePhone);
      c = await h.container();
      c.listen(taskFlowControllerProvider, (_, _) {});
      await c.read(riderAccountControllerProvider.notifier).load();
      await flow().load();
      expect(state().pickupAttemptsRemaining, 2);
      expect(state().pickupLocked, isFalse);

      server().pickupAttemptsLeft = 0;
      await flow().load();
      expect(state().pickupLocked, isTrue);

      server().pickupAttemptsLeft = FakeTaskBackend.maxPickupAttempts;
      await flow().load();
      expect(state().pickupLocked, isFalse);
      expect(await flow().pickup('7K2P'), isTrue);
      expect(state().task!.status, TaskStatus.pickedUp);
    });
  });
}
