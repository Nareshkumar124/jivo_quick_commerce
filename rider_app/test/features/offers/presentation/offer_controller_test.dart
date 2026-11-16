import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/offers/domain/delivery_offer.dart';
import 'package:rider_app/features/offers/presentation/offer_controller.dart';
import 'package:rider_app/features/shift/presentation/shift_controller.dart';
import 'package:rider_app/features/task/domain/task_repositories.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/features/task/presentation/task_flow_controller.dart';

import '../../../helpers/rider_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RiderTestHarness h;
  late ProviderContainer c;

  OfferState state() => c.read(offerControllerProvider);
  OfferController offers() => c.read(offerControllerProvider.notifier);

  setUp(() async {
    h = RiderTestHarness();
    await h.signedInBefore('+919811122231'); // ACTIVE
    c = await h.container();
    c
      ..listen(offerControllerProvider, (_, _) {})
      ..listen(taskFlowControllerProvider, (_, _) {});
    await c.read(riderAccountControllerProvider.notifier).load();
    await c.read(taskFlowControllerProvider.notifier).load();
    await Future<void>.delayed(Duration.zero);
  });

  /// Dispatch offers an order; the push arrives.
  Future<DeliveryOffer> offer({bool cod = false}) async {
    final o = h.tasks.simulateOffer(cod: cod);
    await Future<void>.delayed(Duration.zero);
    return o;
  }

  test('a pushed offer is shown with a 30 s countdown', () async {
    final o = await offer(cod: true);
    expect(state().phase, OfferPhase.showing);
    expect(state().offer?.id, o.id);
    expect(state().countdown!.secondsLeft(h.now), 30);
  });

  test('the countdown runs out: expired, the alert stops', () async {
    await offer();
    h.now = h.now.add(const Duration(seconds: 29));
    offers().tick();
    expect(state().phase, OfferPhase.showing);

    h.now = h.now.add(const Duration(seconds: 1));
    offers().tick();
    expect(state().phase, OfferPhase.expired);
    expect(h.alerter.stops, greaterThan(0));

    offers().acknowledge();
    expect(state().phase, OfferPhase.none);
  });

  test('accept: the task starts (ASSIGNED) and the offer closes', () async {
    final o = await offer();
    await offers().accept();
    expect(state().phase, OfferPhase.none);
    expect(
      c.read(taskFlowControllerProvider).task?.status,
      TaskStatus.assigned,
    );
    expect(h.tasks.calls, contains('accept ${o.id}'));
  });

  test('OFFER_TAKEN: another rider was faster', () async {
    await offer();
    h.tasks.takenNext = true;
    await offers().accept();
    expect(state().phase, OfferPhase.taken);
    expect(c.read(taskFlowControllerProvider).task, isNull);
  });

  test('OFFER_EXPIRED from the server while the phone still counts', () async {
    final o = await offer();
    // The phone shows time left; the server says the offer is gone.
    expect(state().countdown!.secondsLeft(h.now), 30);
    h.tasks.failNext = const ApiError(
      code: ApiErrorCode.offerExpired,
      statusCode: 409,
    );

    await offers().accept();

    expect(h.tasks.calls, contains('accept ${o.id}'));
    expect(state().phase, OfferPhase.expired);
    expect(c.read(taskFlowControllerProvider).task, isNull);
    expect(h.alerter.stops, greaterThan(0));
  });

  test('the phone countdown already ran out: no accept is sent', () async {
    final o = await offer();
    h.now = h.now.add(const Duration(seconds: 31));
    await offers().accept();
    expect(state().phase, OfferPhase.expired);
    expect(h.tasks.calls, isNot(contains('accept ${o.id}')));
  });

  test('offer.withdrawn: "Order cancelled"', () async {
    await offer();
    h.tasks.withdrawOffer();
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, OfferPhase.withdrawn);
  });

  test('reject with a reason closes the offer', () async {
    final o = await offer();
    await offers().reject(reason: OfferRejectReason.tooFar);
    expect(state().phase, OfferPhase.none);
    expect(h.tasks.calls.last, 'reject ${o.id} TOO_FAR');
  });

  test(
    'reject without network still closes it (the server times it out)',
    () async {
      await offer();
      h.tasks.failNext = const ApiError(code: ApiErrorCode.network);
      await offers().reject();
      expect(state().phase, OfferPhase.none);
    },
  );

  // P8: the server still lists the offer (the reject never arrived), so the
  // next poll used to show it again, ringing, after the rider said no.
  test('an offer the rider rejected is not shown again by the poll', () async {
    final o = await offer();
    h.tasks.failNext = const ApiError(code: ApiErrorCode.network);
    await offers().reject();
    expect(h.tasks.offer?.id, o.id, reason: 'still pending on the server');

    await offers().refresh();
    expect(state().phase, OfferPhase.none);

    // A new offer still shows.
    final next = await offer();
    expect(state().offer?.id, next.id);
  });

  test('an expired offer acknowledged is not shown again', () async {
    await offer();
    h.now = h.now.add(const Duration(seconds: 30));
    offers().tick();
    offers().acknowledge();
    // The server's clock is a little behind: it still lists the offer.
    h.now = h.now.subtract(const Duration(seconds: 2));
    await offers().refresh();
    expect(state().phase, OfferPhase.none);
  });

  test('accept with the response lost: the task assigned on the server is '
      'picked up', () async {
    await offer();
    h.tasks.applyThenFailNext = const ApiError(code: ApiErrorCode.timeout);
    await offers().accept();
    expect(state().phase, OfferPhase.none);
    expect(
      c.read(taskFlowControllerProvider).task?.status,
      TaskStatus.assigned,
    );
  });

  test('accept failed before reaching the server: the offer stays, with the '
      'error, while time is left', () async {
    await offer();
    h.tasks.failNext = const ApiError(code: ApiErrorCode.network);
    await offers().accept();
    expect(state().phase, OfferPhase.showing);
    expect(state().error?.code, ApiErrorCode.network);

    await offers().accept();
    expect(c.read(taskFlowControllerProvider).task, isNotNull);
  });

  test('no offers while a task is active (one order at a time)', () async {
    await offer();
    await offers().accept();
    await offer();
    expect(state().phase, OfferPhase.none);
  });

  test(
    'polling fallback: GET /rider/offers/current/ shows a pending offer',
    () async {
      h.tasks.simulateOffer();
      // As if the push was missed: forget it on the phone.
      offers().acknowledge();
      c.invalidate(offerControllerProvider);
      c.listen(offerControllerProvider, (_, _) {});
      await offers().refresh();
      expect(state().phase, OfferPhase.showing);
      expect(h.tasks.calls, contains('fetchCurrentOffer'));
    },
  );

  // P8 hardening: the server set the rider offline (auto-offline, ops)
  // while the phone still showed them online.
  group('RIDER_OFFLINE', () {
    /// Online on the phone and on the server, then the server ends it.
    Future<void> onlineThenSetOfflineByServer() async {
      h.location.running = true;
      h.shift.online = true;
      c.listen(shiftControllerProvider, (_, _) {});
      await pumpEventQueue();
      expect(c.read(shiftControllerProvider).isOnline, isTrue);
      h.shift.autoOffline();
    }

    test('accept answered 409 RIDER_OFFLINE: the offer closes, tracking '
        'stops and home says why (not kept open with an error)', () async {
      await onlineThenSetOfflineByServer();
      final o = await offer();
      h.tasks.failNext = const ApiError(
        code: ApiErrorCode.unknown,
        rawCode: 'RIDER_OFFLINE',
        statusCode: 409,
      );
      await offers().accept();
      await pumpEventQueue();

      expect(state().phase, OfferPhase.none);
      expect(h.tasks.calls, contains('accept ${o.id}'));
      expect(h.location.running, isFalse);
      final shift = c.read(shiftControllerProvider);
      expect(shift.phase, ShiftPhase.offline);
      expect(shift.problem, ShiftProblem.autoOffline);
    });

    test('offer.withdrawn RIDER_OFFLINE is not "Order cancelled": the offer '
        'closes and the shift check runs', () async {
      await onlineThenSetOfflineByServer();
      final o = await offer();
      offers().withdrawn(o.id, reason: OfferEndReason.riderOffline);
      await pumpEventQueue();

      expect(state().phase, OfferPhase.none);
      expect(h.location.running, isFalse);
      expect(c.read(shiftControllerProvider).problem, ShiftProblem.autoOffline);
    });

    test('the socket reason maps to riderOffline', () {
      expect(
        OfferEndReason.fromWire('RIDER_OFFLINE'),
        OfferEndReason.riderOffline,
      );
      expect(
        OfferEndReason.fromWire('ORDER_CANCELLED'),
        OfferEndReason.cancelled,
      );
    });
  });

  // P8 hardening: ops assign the rider an order directly (task.updated
  // ASSIGNED) while an offer is open or its end message is unread.
  group('a task that starts closes the offer screen', () {
    test(
      'an unread "Order cancelled" does not come back after the task',
      () async {
        await offer();
        h.tasks.withdrawOffer();
        await Future<void>.delayed(Duration.zero);
        expect(state().phase, OfferPhase.withdrawn);

        h.tasks.seedTask(h.tasks.newTask());
        await c.read(taskFlowControllerProvider.notifier).load();
        expect(c.read(taskFlowControllerProvider).hasTask, isTrue);
        expect(state().isOpen, isFalse, reason: 'nothing left to show later');
      },
    );

    test('an offer still showing stops ringing and closes', () async {
      await offer();
      final stopsBefore = h.alerter.stops;
      h.tasks.seedTask(h.tasks.newTask());
      await c.read(taskFlowControllerProvider.notifier).load();

      expect(state().phase, OfferPhase.none);
      expect(h.alerter.stops, greaterThan(stopsBefore));
    });
  });
}
