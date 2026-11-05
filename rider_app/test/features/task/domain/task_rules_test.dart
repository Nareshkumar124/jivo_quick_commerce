import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_rules.dart';
import 'package:rider_app/features/task/domain/task_status.dart';

void main() {
  final backend = FakeTaskBackend(delay: Duration.zero);
  final cod = backend.newTask(cod: true, status: TaskStatus.atCustomer);
  final prepaid = backend.newTask(status: TaskStatus.atCustomer);

  group('formatRupees (03 §4 rule, RD-02; display only)', () {
    test('en_IN grouping, paise only when not zero', () {
      expect(formatRupees('249.00'), '₹249');
      expect(formatRupees('1249.00'), '₹1,249');
      expect(formatRupees('12345.50'), '₹12,345.50');
      expect(formatRupees('1234567.00'), '₹12,34,567');
      expect(formatRupees('0.5'), '₹0.50');
      expect(formatRupees('45'), '₹45');
      expect(formatRupees('-20.00'), '-₹20');
    });

    test('a malformed amount is never shown with a bare ₹', () {
      expect(formatRupees('abc'), 'abc');
      expect(formatRupees(''), '');
      expect(tryFormatRupees(null), isNull);
      expect(tryFormatRupees(''), isNull);
      expect(tryFormatRupees('12.345'), isNull);
      // 20 digits from a broken server value: null, never an overflow.
      expect(tryFormatRupees('12345678901234567890.00'), isNull);
      expect(isSameAmount('12345678901234567890', '1'), isFalse);
      expect(tryFormatRupees('100000000000000.00'), '₹10,00,00,00,00,00,000');
    });

    test('isSameAmount compares server strings', () {
      expect(isSameAmount('20', '20.00'), isTrue);
      expect(isSameAmount('20.5', '20.50'), isTrue);
      expect(isSameAmount('20.00', '19.99'), isFalse);
      expect(isSameAmount('x', 'x'), isFalse);
    });
  });

  group('COD amount display (RD-02, RD-03)', () {
    test('codAmountText: the due amount, or null when it is missing', () {
      expect(codAmountText(cod), formatRupees(FakeTaskBackend.codAmount));
      expect(codAmountText(prepaid), isNull);
      final missing = backend.newTask(cod: true, status: TaskStatus.atCustomer);
      expect(
        codAmountText(_withoutAmount(missing)),
        isNull,
        reason: 'never a bare ₹',
      );
    });

    test('codAmountWasText only when the amount really changed', () {
      expect(codAmountWasText(cod), isNull);
      final changed = cod.copyWith(
        codAmountDue: '990.00',
        codAmountChangedFrom: '1240.00',
      );
      expect(codAmountWasText(changed), '₹1,240');
      expect(codAmountText(changed), '₹990');
      final same = cod.copyWith(
        codAmountDue: '990.00',
        codAmountChangedFrom: '990',
      );
      expect(codAmountWasText(same), isNull);
    });
  });

  group('COD before deliver (rule 6, T10)', () {
    test('prepaid needs no collection', () {
      expect(validateCodForDeliver(prepaid, null), isNull);
      expect(
        validateCodForDeliver(
          prepaid,
          const CodCollection.cash(cashConfirmed: true),
        ),
        CodProblem.notCod,
      );
    });

    test('COD cash needs the explicit confirmation', () {
      expect(validateCodForDeliver(cod, null), CodProblem.collectionMissing);
      expect(
        validateCodForDeliver(
          cod,
          const CodCollection.cash(cashConfirmed: false),
        ),
        CodProblem.cashNotConfirmed,
      );
      expect(
        validateCodForDeliver(
          cod,
          const CodCollection.cash(cashConfirmed: true),
        ),
        isNull,
      );
    });

    test('COD UPI needs the server to confirm the payment', () {
      expect(
        validateCodForDeliver(cod, const CodCollection.upi()),
        CodProblem.upiNotPaid,
      );
      final pending = cod.copyWith(
        codQr: const CodQr(
          imageUrl: null,
          amount: '1249.00',
          status: UpiQrStatus.pending,
        ),
      );
      expect(
        validateCodForDeliver(pending, const CodCollection.upi()),
        CodProblem.upiNotPaid,
      );
      final paid = pending.copyWith(
        codQr: pending.codQr!.withStatus(UpiQrStatus.paid),
      );
      expect(validateCodForDeliver(paid, const CodCollection.upi()), isNull);
    });
  });

  group('pickup code', () {
    test('4 letters or digits, upper-cased', () {
      expect(normalisePickupCode('7k2p'), '7K2P');
      expect(normalisePickupCode(' 7K2P '), '7K2P');
      expect(normalisePickupCode('7K2'), isNull);
      expect(normalisePickupCode('7K2PX'), isNull);
      expect(normalisePickupCode('7K-P'), isNull);
    });

    test('bag QR JQC1:<order>:<code> is sent whole (api-requests #15)', () {
      final scanned = parseScannedPickup(
        'jqc1:JV-261110-001203:k7qx',
        orderNumber: 'JV-261110-001203',
      );
      expect(scanned, isA<ScannedCode>());
      expect((scanned as ScannedCode).orderCode, 'JQC1:JV-261110-001203:K7QX');
      expect(pickupCodeFromPayload(scanned.orderCode), 'K7QX');
    });

    test('a bare 4-character QR is the code', () {
      final scanned = parseScannedPickup(' 7k2p ', orderNumber: 'JQ-1');
      expect((scanned as ScannedCode).orderCode, '7K2P');
      expect(pickupCodeFromPayload('7K2P'), '7K2P');
    });

    test('a label for another order is caught without a call', () {
      final scanned = parseScannedPickup(
        'JQC1:JV-OTHER:K7QX',
        orderNumber: 'JV-261110-001203',
      );
      expect((scanned as ScannedOtherOrder).orderNumber, 'JV-OTHER');
    });

    test('anything else is unreadable', () {
      for (final raw in [
        null,
        'https://example.com/7K2P',
        'JQC1:JV-1:K7',
        'JQC1::K7QX',
        'JQC2:JV-1:K7QX',
      ]) {
        expect(
          parseScannedPickup(raw, orderNumber: 'JV-1'),
          isA<ScannedUnreadable>(),
          reason: '$raw',
        );
      }
    });
  });

  group('taskPollInterval (polling fallback)', () {
    test('no task, or an ended one: no polling', () {
      expect(taskPollInterval(null), isNull);
      expect(
        taskPollInterval(prepaid.copyWith(status: TaskStatus.delivered)),
        isNull,
      );
    });

    test('3 s while a UPI QR is open, as the contract says', () {
      final qr = cod.copyWith(
        codQr: const CodQr(
          imageUrl: null,
          amount: '1249.00',
          status: UpiQrStatus.pending,
        ),
      );
      expect(taskPollInterval(qr), const Duration(seconds: 3));
      expect(
        taskPollInterval(
          qr.copyWith(codQr: qr.codQr!.withStatus(UpiQrStatus.paid)),
        ),
        const Duration(seconds: 15),
      );
    });

    test('5 s at the store while packing, 10 s returning, else 15 s', () {
      final atStore = prepaid.copyWith(status: TaskStatus.atStore);
      expect(taskPollInterval(atStore), const Duration(seconds: 5));
      expect(
        taskPollInterval(
          atStore.copyWith(storeProgress: StoreOrderProgress.ready),
        ),
        const Duration(seconds: 15),
      );
      expect(
        taskPollInterval(prepaid.copyWith(status: TaskStatus.returning)),
        const Duration(seconds: 10),
      );
      expect(
        taskPollInterval(prepaid.copyWith(status: TaskStatus.assigned)),
        const Duration(seconds: 15),
      );
    });
  });

  group('failed delivery', () {
    final arrived = DateTime.utc(2026, 11, 2, 6);
    final atDrop = prepaid.copyWith(arrivedCustomerAt: arrived);

    FailBlock? block(
      FailReason reason, {
      RiderTask? task,
      int calls = 2,
      Duration after = const Duration(minutes: 10),
      String note = '',
    }) => failReasonBlock(
      reason: reason,
      task: task ?? atDrop,
      callAttempts: calls,
      now: arrived.add(after),
      note: note,
    );

    test('not reachable: arrived, enough calls, and the 10-minute wait', () {
      expect(
        block(
          FailReason.notReachable,
          task: backend.newTask(status: TaskStatus.pickedUp),
        ),
        FailBlock.notArrived,
      );
      expect(block(FailReason.notReachable, calls: 1), FailBlock.needsCalls);
      expect(
        block(
          FailReason.notReachable,
          after: const Duration(minutes: 9, seconds: 59),
        ),
        FailBlock.waitRunning,
      );
      expect(block(FailReason.notReachable), isNull);
    });

    test('the wait counts from the server\'s arrival time', () {
      expect(
        notReachableWaitLeft(atDrop, arrived.add(const Duration(minutes: 3))),
        const Duration(minutes: 7),
      );
      expect(
        notReachableWaitLeft(atDrop, arrived.add(const Duration(minutes: 30))),
        Duration.zero,
      );
      expect(notReachableWaitLeft(prepaid, arrived), isNull);
    });

    test('the server not_reachable_after wins over the local 10 min', () {
      final later = atDrop.copyWith(
        notReachableAfter: arrived.add(const Duration(minutes: 12)),
      );
      expect(
        notReachableWaitLeft(later, arrived.add(const Duration(minutes: 10))),
        const Duration(minutes: 2),
      );
    });

    test('other needs a note; refused and wrong address need nothing', () {
      expect(block(FailReason.other), FailBlock.noteRequired);
      expect(block(FailReason.other, note: 'Gate locked'), isNull);
      expect(block(FailReason.refused, calls: 0, after: Duration.zero), isNull);
      expect(
        block(FailReason.wrongAddress, calls: 0, after: Duration.zero),
        isNull,
      );
    });
  });
}

RiderTask _withoutAmount(RiderTask t) => RiderTask(
  id: t.id,
  status: t.status,
  orderNumber: t.orderNumber,
  store: t.store,
  storeProgress: t.storeProgress,
  paymentType: t.paymentType,
  items: t.items,
  customer: t.customer,
);
