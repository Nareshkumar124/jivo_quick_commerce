import 'dart:io';

import 'package:customer_app/features/checkout/data/fake_payment_launcher.dart';
import 'package:customer_app/features/checkout/data/gateway_payment_launcher.dart';
import 'package:customer_app/features/checkout/data/payment_launcher.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

/// Answers with a fixed outcome and records what it was asked.
class _Recording implements PaymentLauncher {
  _Recording(this.outcome);

  final PaymentOutcome outcome;
  final opened = <PaymentRequest>[];

  @override
  Future<PaymentOutcome> open(PaymentRequest request) async {
    opened.add(request);
    return outcome;
  }
}

PaymentRequest _request(String keyId) => PaymentRequest(
  checkout: RazorpayCheckout(
    keyId: keyId,
    orderId: 'order_Nq3uVxY7kL9pQe',
    amountPaise: 75300,
  ),
  orderNumber: 'JV-261103-000123',
  grandTotal: '753.00',
);

void main() {
  group('fake gateway scheme (06 §2.6)', () {
    test('the worked example signs to the published signature', () {
      expect(
        fakePaymentSignature('order_Nq3uVxY7kL9pQe', 'pay_Nq3vA1bC2dE3fG'),
        'bc4bcc84a495aaddc2f52819146edd4d26728c1221e5621f23995c106721c977',
      );
    });

    test('payment ids are "pay_" + 14 letters or digits', () {
      final ids = {for (var i = 0; i < 50; i++) newFakePaymentId()};
      expect(ids, hasLength(50));
      for (final id in ids) {
        expect(id, matches(RegExp(r'^pay_[A-Za-z0-9]{14}$')));
      }
    });

    test('success signs the made-up payment id', () async {
      final launcher = FakePaymentLauncher(
        choose: (_) async => FakePaymentChoice.succeed,
        newPaymentId: () => 'pay_Nq3vA1bC2dE3fG',
      );
      final outcome = await launcher.open(
        _request('rzp_fake_jivo_local'),
      ) as PaymentAuthorized;
      expect(outcome.razorpayPaymentId, 'pay_Nq3vA1bC2dE3fG');
      expect(
        outcome.razorpaySignature,
        'bc4bcc84a495aaddc2f52819146edd4d26728c1221e5621f23995c106721c977',
      );
    });
  });

  group('which checkout opens', () {
    late _Recording real;
    late _Recording fake;

    setUp(() {
      real = _Recording(
        const PaymentNotCompleted(PaymentFailureReason.cancelled),
      );
      fake = _Recording(const PaymentExternalWallet('fake'));
    });

    test('dev + rzp_fake_ key: the fake, never Razorpay', () async {
      final launcher = GatewayPaymentLauncher(
        flavor: Flavor.dev,
        real: real,
        fake: fake,
      );
      await launcher.open(_request('rzp_fake_jivo_local'));
      expect(fake.opened, hasLength(1));
      expect(real.opened, isEmpty);
    });

    test('dev + a real test key: real Razorpay', () async {
      final launcher = GatewayPaymentLauncher(
        flavor: Flavor.dev,
        real: real,
        fake: fake,
      );
      await launcher.open(_request('rzp_test_AbCdEf123'));
      expect(real.opened, hasLength(1));
      expect(fake.opened, isEmpty);
    });

    for (final flavor in [Flavor.staging, Flavor.prod]) {
      test('${flavor.name} + rzp_fake_ key: refused, nothing opens', () async {
        final launcher = GatewayPaymentLauncher(flavor: flavor, real: real);
        final outcome = await launcher.open(_request('rzp_fake_jivo_local'));
        expect(
          outcome,
          isA<PaymentNotCompleted>().having(
            (o) => o.reason,
            'reason',
            PaymentFailureReason.invalidOptions,
          ),
        );
        expect(real.opened, isEmpty);
      });

      test('${flavor.name} + a live key: real Razorpay', () async {
        final launcher = GatewayPaymentLauncher(flavor: flavor, real: real);
        await launcher.open(_request('rzp_live_XyZ'));
        expect(real.opened, hasLength(1));
      });
    }
  });

  test('razorpay_flutter is pinned exactly (its channel internals)', () {
    // RazorpayPaymentLauncher drains the plugin's `resync` on its own
    // channel; an upgrade must be a deliberate edit that re-checks it.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains(RegExp(r'^\s+razorpay_flutter: 1\.4\.7$', multiLine: true)),
    );
  });
}
