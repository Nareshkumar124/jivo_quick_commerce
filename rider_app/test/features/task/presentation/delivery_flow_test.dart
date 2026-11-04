import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_status.dart';

import '../../../helpers/rider_app_harness.dart';

Finder byKey(String key) => find.byKey(Key(key));

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  /// The app starts with this task already on the server: a restart in the
  /// middle of a delivery resumes the exact step.
  Future<RiderTask> resume(
    WidgetTester tester,
    TaskStatus status, {
    bool cod = false,
    RiderTask Function(RiderTask task)? edit,
    bool settle = true,
  }) async {
    var task = h.tasks.newTask(cod: cod, status: status);
    if (edit != null) task = edit(task);
    h.tasks.seedTask(task);
    await h.signedInBefore('+919811122231');
    await h.pump(tester, settle: settle);
    return task;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(byKey(key));
    await tester.pumpAndSettle();
  }

  String? barError(WidgetTester tester) =>
      byKey('task-error').evaluate().isEmpty
      ? null
      : tester.widget<Text>(byKey('task-error')).data;

  group('go to the store', () {
    testWidgets('restored on start; navigate opens a geo: intent', (
      tester,
    ) async {
      await resume(tester, TaskStatus.assigned);

      expect(find.text('Go to the store'), findsOneWidget);
      expect(byKey('home-flavor'), findsNothing);
      expect(find.text('Packing…'), findsOneWidget);

      await tap(tester, 'navigate-store');
      expect(h.urls.opened.single.scheme, 'geo');
      expect(h.urls.opened.single.toString(), contains('28.5706,77.3261'));
    });

    testWidgets('outside the geofence: the distance from the server, then '
        'arrived', (tester) async {
      await resume(tester, TaskStatus.assigned);
      h.tasks.outsideGeofenceNext = true;
      await tap(tester, 'task-arrived-store');
      expect(barError(tester), "You're 450 m away. Move closer and try again.");

      await tap(tester, 'task-arrived-store');
      expect(find.text('Pick up the order'), findsOneWidget);
      expect(
        tester.getSize(byKey('task-pickup')).height,
        greaterThanOrEqualTo(56),
      );
    });
  });

  group('pickup', () {
    testWidgets('not packed, wrong code, a foreign QR, then the bag QR', (
      tester,
    ) async {
      await resume(tester, TaskStatus.atStore);
      expect(find.text('Jivo Canola Oil'), findsOneWidget);
      expect(find.text('2 ×'), findsOneWidget);

      await tester.enterText(byKey('pickup-code'), '7k2p');
      await tap(tester, 'task-pickup');
      expect(
        barError(tester),
        "The order isn't packed yet. Wait until the store marks it ready.",
      );

      h.tasks.markPacked();
      await tester.enterText(byKey('pickup-code'), 'AAAA');
      await tap(tester, 'task-pickup');
      expect(
        barError(tester),
        "That code doesn't match this order. Check the bag and try again.",
      );

      await tap(tester, 'pickup-scan');
      await tap(tester, 'fake-scan-HELLO-WORLD');
      expect(find.text("This QR isn't a Jivo order code."), findsOneWidget);
      await tap(tester, 'fake-scan-7K2P');

      expect(find.text('Deliver to the customer'), findsOneWidget);
    });

    testWidgets('a short code is caught on the phone', (tester) async {
      await resume(tester, TaskStatus.atStore);
      await tester.enterText(byKey('pickup-code'), '7K');
      await tap(tester, 'task-pickup');
      expect(barError(tester), 'Enter the 4-character code from the bag.');
      expect(h.tasks.calls, isNot(contains('pickup')));
    });
  });

  group('to the customer', () {
    testWidgets('address revealed, COD banner, call, arrived', (tester) async {
      await resume(tester, TaskStatus.pickedUp, cod: true);

      expect(find.text('Asha Verma'), findsOneWidget);
      expect(find.text('Landmark: Opposite the park gate'), findsOneWidget);
      expect(find.text('Collect ₹1,249 in cash'), findsOneWidget);

      await tap(tester, 'call-customer');
      expect(h.urls.opened.last, Uri(scheme: 'tel', path: '+919876512345'));

      await tap(tester, 'task-arrived-customer');
      expect(find.text('Enter the delivery code'), findsOneWidget);
    });

    testWidgets('wrong pin: arrive with an override reason', (tester) async {
      await resume(tester, TaskStatus.pickedUp);
      h.tasks.outsideGeofenceNext = true;
      await tap(tester, 'task-arrived-customer');
      expect(byKey('arrived-override'), findsOneWidget);

      await tap(tester, 'arrived-override');
      await tap(tester, 'override-PIN_WRONG');
      expect(find.text('Enter the delivery code'), findsOneWidget);
      expect(h.tasks.calls.last, 'arrivedAtCustomer override');
    });
  });

  group('delivery OTP', () {
    testWidgets('prepaid: wrong code shows attempts left, right code '
        'delivers', (tester) async {
      await resume(tester, TaskStatus.atCustomer);
      expect(
        tester.widget<FilledButton>(byKey('task-deliver')).onPressed,
        isNull,
        reason: 'needs 4 digits',
      );

      await tester.enterText(byKey('delivery-otp'), '0000');
      await tester.pump();
      await tap(tester, 'task-deliver');
      expect(barError(tester), 'Wrong code. 4 attempts left.');
      expect(find.text('4 attempts left'), findsOneWidget);

      await tester.enterText(
        byKey('delivery-otp'),
        FakeTaskBackend.deliveryOtp,
      );
      await tester.pump();
      await tap(tester, 'task-deliver');
      expect(find.text('Delivered!'), findsOneWidget);
      expect(find.text('You earned ₹45 for this order.'), findsOneWidget);

      await tap(tester, 'task-done');
      expect(byKey('home-flavor'), findsOneWidget);
    });

    testWidgets('locked after 5 wrong codes: call support', (tester) async {
      await resume(
        tester,
        TaskStatus.atCustomer,
        edit: (t) => t.copyWith(otpLocked: true, otpAttemptsRemaining: 0),
      );
      expect(find.text('Delivery code locked'), findsOneWidget);
      expect(byKey('delivery-otp'), findsNothing);

      await tap(tester, 'call-support');
      expect(h.urls.opened.last, Uri(scheme: 'tel', path: '+911800123456'));
    });
  });

  group('COD', () {
    Future<void> toCollect(WidgetTester tester, String otp) async {
      await tester.enterText(byKey('delivery-otp'), otp);
      await tester.pump();
      await tap(tester, 'otp-continue');
    }

    testWidgets('cash: the exact amount, explicit confirmation, deliver', (
      tester,
    ) async {
      await resume(tester, TaskStatus.atCustomer, cod: true);
      await toCollect(tester, FakeTaskBackend.deliveryOtp);

      expect(find.text('Collect payment'), findsOneWidget);
      expect(tester.widget<Text>(byKey('cod-amount')).data, '₹1,249');

      await tap(tester, 'cod-cash');
      expect(find.text('Collected ₹1,249?'), findsOneWidget);
      await tap(tester, 'cod-cash-cancel');
      expect(h.tasks.calls, isNot(contains(startsWith('deliver'))));

      await tap(tester, 'cod-cash');
      await tap(tester, 'cod-cash-confirm');
      expect(h.tasks.calls.last, 'deliver cash 1249.00');
      expect(find.text('Delivered!'), findsOneWidget);
    });

    testWidgets('the confirmation repeats the amount on Yes; '
        'focus starts on "Not yet" (cod.md §4)', (tester) async {
      await resume(tester, TaskStatus.atCustomer, cod: true);
      await toCollect(tester, FakeTaskBackend.deliveryOtp);
      await tap(tester, 'cod-cash');
      expect(find.text('Yes, ₹1,249 collected'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget);
      final notYet = tester.widget<TextButton>(byKey('cod-cash-cancel'));
      expect(notYet.autofocus, isTrue);
    });

    testWidgets('a COD task without an amount: no cash or UPI action, only '
        'Refresh, never a bare ₹ (RD-02)', (tester) async {
      await resume(
        tester,
        TaskStatus.atCustomer,
        cod: true,
        edit: (t) => RiderTask(
          id: t.id,
          status: t.status,
          orderNumber: t.orderNumber,
          store: t.store,
          storeProgress: t.storeProgress,
          paymentType: t.paymentType,
          items: t.items,
          customer: t.customer,
          arrivedCustomerAt: t.arrivedCustomerAt,
        ),
      );
      await toCollect(tester, FakeTaskBackend.deliveryOtp);

      expect(byKey('cod-amount-missing'), findsOneWidget);
      expect(byKey('cod-cash'), findsNothing);
      expect(byKey('cod-upi'), findsNothing);
      expect(byKey('cod-refresh'), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(matches(RegExp(r'₹(\s|$)'))));
      }
    });

    testWidgets('the amount changed after the offer: notice on the way and '
        'at collection, old amount struck through (RD-03)', (tester) async {
      await resume(
        tester,
        TaskStatus.pickedUp,
        cod: true,
        edit: (t) =>
            t.copyWith(codAmountDue: '990.00', codAmountChangedFrom: '1249.00'),
      );
      expect(find.text('Amount changed: collect ₹990'), findsOneWidget);
      expect(
        find.text("Was ₹1,249. The store couldn't supply some items."),
        findsOneWidget,
      );
      expect(find.text('Collect ₹990 in cash'), findsOneWidget);
    });

    testWidgets('changed amount on the COD step', (tester) async {
      await resume(
        tester,
        TaskStatus.atCustomer,
        cod: true,
        edit: (t) =>
            t.copyWith(codAmountDue: '990.00', codAmountChangedFrom: '1249.00'),
      );
      await toCollect(tester, FakeTaskBackend.deliveryOtp);
      expect(byKey('cod-amount-changed'), findsOneWidget);
      expect(tester.widget<Text>(byKey('cod-amount')).data, '₹990');
      final was = tester.widget<Text>(byKey('cod-amount-was'));
      expect(was.data, '₹1,249');
      expect(was.style?.decoration, TextDecoration.lineThrough);
      expect(tester.getSize(byKey('cod-amount')).height, greaterThan(48));
    });

    testWidgets('a wrong OTP after collecting cash keeps the collection', (
      tester,
    ) async {
      await resume(tester, TaskStatus.atCustomer, cod: true);
      await toCollect(tester, '0000');
      await tap(tester, 'cod-cash');
      await tap(tester, 'cod-cash-confirm');

      expect(find.text('Enter the delivery code'), findsOneWidget);
      expect(barError(tester), 'Wrong code. 4 attempts left.');

      await toCollect(tester, FakeTaskBackend.deliveryOtp);
      expect(byKey('cod-cash-done'), findsOneWidget);
      await tap(tester, 'cod-cash');
      expect(find.text('Delivered!'), findsOneWidget);
    });

    testWidgets('UPI: QR, waiting, server confirms, deliver', (tester) async {
      await resume(tester, TaskStatus.atCustomer, cod: true);
      await toCollect(tester, FakeTaskBackend.deliveryOtp);

      await tap(tester, 'cod-upi');
      expect(
        tester.widget<Text>(byKey('cod-upi-status')).data,
        'Waiting for the payment…',
      );
      expect(
        tester.widget<FilledButton>(byKey('cod-upi-deliver')).onPressed,
        isNull,
      );

      h.tasks.markUpiPaid();
      await tap(tester, 'cod-upi-check');
      expect(
        tester.widget<Text>(byKey('cod-upi-status')).data,
        'Payment received',
      );

      await tap(tester, 'cod-upi-deliver');
      expect(h.tasks.calls.last, 'deliver upi 1249.00');
      expect(find.text('Delivered!'), findsOneWidget);
    });
  });

  group('COD fallbacks', () {
    Future<void> toQr(WidgetTester tester) async {
      await tester.enterText(
        byKey('delivery-otp'),
        FakeTaskBackend.deliveryOtp,
      );
      await tester.pump();
      await tap(tester, 'otp-continue');
      await tap(tester, 'cod-upi');
    }

    testWidgets('UPI fails: the customer pays cash instead', (tester) async {
      await resume(tester, TaskStatus.atCustomer, cod: true);
      await toQr(tester);

      await tap(tester, 'cod-take-cash');
      await tap(tester, 'cod-cash');
      await tap(tester, 'cod-cash-confirm');

      expect(h.tasks.calls.last, 'deliver cash 1249.00');
      expect(find.text('Delivered!'), findsOneWidget);
    });

    testWidgets('an expired QR can be shown again', (tester) async {
      await resume(tester, TaskStatus.atCustomer, cod: true);
      await toQr(tester);

      h.tasks.expireUpiQr();
      await tap(tester, 'cod-upi-check');
      expect(
        tester.widget<Text>(byKey('cod-upi-status')).data,
        'The QR expired. Show a new one.',
      );

      await tap(tester, 'cod-upi-again');
      expect(
        tester.widget<Text>(byKey('cod-upi-status')).data,
        'Waiting for the payment…',
      );
      expect(h.tasks.calls.where((c) => c == 'createCodQr'), hasLength(2));
    });
  });

  group('failed delivery', () {
    testWidgets('not reachable needs 2 calls and the 10-minute wait; photo; '
        'then return to store until the store receives it', (tester) async {
      await resume(
        tester,
        TaskStatus.atCustomer,
        edit: (t) => t.copyWith(
          arrivedCustomerAt: h.now.subtract(const Duration(minutes: 3)),
        ),
      );
      await tap(tester, 'task-cant-deliver');
      expect(find.text("Can't deliver"), findsWidgets);

      await tester.tap(byKey('fail-CUSTOMER_NOT_REACHABLE'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(
        find.text('Call the customer at least 2 times (0 done)'),
        findsOneWidget,
      );
      expect(find.text('Wait at the address: 07:00 left'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('fail-submit')).onPressed,
        isNull,
      );

      await tester.tap(byKey('fail-call'));
      await tester.tap(byKey('fail-call'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(
        find.text('Call the customer at least 2 times (2 done)'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(byKey('fail-submit')).onPressed,
        isNull,
        reason: 'still waiting',
      );

      h.now = h.now.add(const Duration(minutes: 7));
      await pumpFor(tester, const Duration(milliseconds: 1100));
      expect(find.text('You waited 10 minutes at the address'), findsOneWidget);

      await tester.tap(byKey('fail-photo'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(byKey('fail-photo-added'), findsOneWidget);
      expect(h.picker.discarded, hasLength(1), reason: 'original deleted');
      expect(await h.pendingCapture.read(), isNull, reason: 'not a KYC photo');

      await tester.tap(byKey('fail-submit'));
      await tester.pumpAndSettle();
      expect(h.tasks.calls.last, 'fail CUSTOMER_NOT_REACHABLE');
      expect(find.text('Return to store'), findsOneWidget);

      await tap(tester, 'task-check');
      expect(find.text('Return to store'), findsOneWidget);

      h.tasks.markReturned();
      await tap(tester, 'task-check');
      expect(find.text('Items returned'), findsOneWidget);
      await tap(tester, 'task-done');
      expect(byKey('home-flavor'), findsOneWidget);
    });

    testWidgets('other reason needs a note; refused goes straight through', (
      tester,
    ) async {
      await resume(tester, TaskStatus.pickedUp);
      await tap(tester, 'task-cant-deliver');

      await tester.tap(byKey('fail-OTHER'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(
        tester.widget<FilledButton>(byKey('fail-submit')).onPressed,
        isNull,
      );
      await tester.enterText(byKey('fail-note'), 'Gate locked, no answer');
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(
        tester.widget<FilledButton>(byKey('fail-submit')).onPressed,
        isNotNull,
      );

      await tester.tap(byKey('fail-CUSTOMER_REFUSED'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(byKey('fail-submit'));
      await tester.pumpAndSettle();
      expect(find.text('Return to store'), findsOneWidget);
    });
  });

  group('review fixes', () {
    testWidgets('a lost deliver that the server no longer lists: "couldn\'t '
        'confirm", check or call support, back to orders', (tester) async {
      await resume(tester, TaskStatus.atCustomer);
      h.tasks
        ..returnsEndedTasks = false
        ..applyThenFailNext = const ApiError(code: ApiErrorCode.network);
      await tester.enterText(
        byKey('delivery-otp'),
        FakeTaskBackend.deliveryOtp,
      );
      await tester.pump();
      await tap(tester, 'task-deliver');

      expect(find.text("Couldn't confirm the last step"), findsOneWidget);
      expect(find.text('Order reassigned'), findsNothing);
      expect(byKey('call-support'), findsOneWidget);

      await tap(tester, 'task-check');
      expect(find.text("Couldn't confirm the last step"), findsOneWidget);

      await tap(tester, 'task-done');
      expect(byKey('home-flavor'), findsOneWidget);
    });

    testWidgets('restored with a pending UPI QR: it keeps polling', (
      tester,
    ) async {
      await resume(
        tester,
        TaskStatus.atCustomer,
        cod: true,
        edit: (t) => t.copyWith(
          codQr: const CodQr(
            imageUrl: null,
            amount: '1249.00',
            status: UpiQrStatus.pending,
          ),
        ),
      );
      final before = h.tasks.calls.where((c) => c == 'fetchCurrentTask').length;
      h.tasks.markUpiPaid();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(
        h.tasks.calls.where((c) => c == 'fetchCurrentTask').length,
        greaterThan(before),
      );
    });

    testWidgets('a QR image URL that is not https is never loaded', (
      tester,
    ) async {
      await resume(
        tester,
        TaskStatus.atCustomer,
        cod: true,
        edit: (t) => t.copyWith(
          codQr: const CodQr(
            imageUrl: 'http://qr.example.test/pay.png',
            amount: '1249.00',
            status: UpiQrStatus.pending,
          ),
        ),
      );
      await tester.enterText(
        byKey('delivery-otp'),
        FakeTaskBackend.deliveryOtp,
      );
      await tester.pump();
      await tap(tester, 'otp-continue');

      expect(byKey('cod-qr-unavailable'), findsOneWidget);
      expect(byKey('cod-qr-image'), findsNothing);
      // Cash is still possible.
      expect(byKey('cod-take-cash'), findsOneWidget);
    });
  });

  group('ended by someone else', () {
    testWidgets('cancelled before pickup', (tester) async {
      await resume(tester, TaskStatus.assigned);
      h.tasks.cancelOrder();
      await tap(tester, 'task-refresh');

      expect(find.text('Order cancelled'), findsOneWidget);
      await tap(tester, 'task-done');
      expect(byKey('home-flavor'), findsOneWidget);
    });

    testWidgets('reassigned by ops', (tester) async {
      await resume(tester, TaskStatus.atStore);
      h.tasks.unassign();
      await tap(tester, 'task-refresh');

      expect(find.text('Order reassigned'), findsOneWidget);
      await tap(tester, 'task-done');
      expect(byKey('home-flavor'), findsOneWidget);
    });
  });
}
