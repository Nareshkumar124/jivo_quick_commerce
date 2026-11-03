import 'dart:async';

import 'package:customer_app/features/checkout/data/payment_launcher.dart';
import 'package:customer_app/features/checkout/data/razorpay_payment_launcher.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

const _request = PaymentRequest(
  checkout: RazorpayCheckout(
    keyId: 'rzp_test_public',
    orderId: 'order_abc',
    amountPaise: 50300,
    name: 'Jivo',
    description: 'JV-261103-000123',
    prefillContact: '+919000000001',
    timeoutSeconds: 840,
  ),
  orderNumber: 'JQ001001',
  grandTotal: '503.00',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('razorpay_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers the plugin's `open` with [result] (Razorpay's native shape).
  void nativeAnswers(Map<String, Object?> result) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'open' => result,
        _ => null, // resync: nothing lost
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  test('options carry the server values unchanged, without nulls', () {
    final options = RazorpayPaymentLauncher.optionsFor(_request);
    expect(options['key'], 'rzp_test_public');
    expect(options['order_id'], 'order_abc');
    expect(options['amount'], 50300);
    expect(options['currency'], 'INR');
    expect(options['name'], 'Jivo');
    expect(options['description'], 'JV-261103-000123');
    expect(options['timeout'], 840);
    expect(options['prefill'], {'contact': '+919000000001'});
  });

  test('SDK error codes map to reasons', () {
    expect(
      RazorpayPaymentLauncher.reasonFor(Razorpay.PAYMENT_CANCELLED),
      PaymentFailureReason.cancelled,
    );
    expect(
      RazorpayPaymentLauncher.reasonFor(Razorpay.NETWORK_ERROR),
      PaymentFailureReason.network,
    );
    expect(
      RazorpayPaymentLauncher.reasonFor(Razorpay.INVALID_OPTIONS),
      PaymentFailureReason.invalidOptions,
    );
    expect(
      RazorpayPaymentLauncher.reasonFor(null),
      PaymentFailureReason.unknown,
    );
  });

  test('a success without a signature is not treated as paid', () {
    final outcome = RazorpayPaymentLauncher.successOutcome(
      PaymentSuccessResponse('pay_1', 'order_abc', null, const {}),
    );
    expect(outcome, isA<PaymentNotCompleted>());
  });

  test('open returns the ids and signature for the verify call', () async {
    nativeAnswers({
      'type': 0,
      'data': {
        'razorpay_payment_id': 'pay_1',
        'razorpay_order_id': 'order_abc',
        'razorpay_signature': 'sig',
      },
    });
    final outcome = await RazorpayPaymentLauncher().open(_request);
    expect(
      outcome,
      isA<PaymentAuthorized>()
          .having((o) => o.razorpayPaymentId, 'payment', 'pay_1')
          .having((o) => o.razorpayOrderId, 'order', 'order_abc')
          .having((o) => o.razorpaySignature, 'signature', 'sig'),
    );
  });

  test('a cancelled checkout is reported as cancelled', () async {
    nativeAnswers({
      'type': 1,
      'data': {'code': Razorpay.PAYMENT_CANCELLED, 'message': 'cancelled'},
    });
    final outcome = await RazorpayPaymentLauncher().open(_request);
    expect(
      outcome,
      isA<PaymentNotCompleted>().having(
        (o) => o.reason,
        'reason',
        PaymentFailureReason.cancelled,
      ),
    );
  });

  test('a result kept from a killed checkout does not end this one', () async {
    // The plugin replays a failure it kept from an earlier, killed checkout
    // on the first resync; it is drained before listening.
    var resyncs = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'resync' when resyncs++ == 0 => {
          'type': 1,
          'data': {'code': Razorpay.NETWORK_ERROR, 'message': 'old'},
        },
        'open' => {
          'type': 0,
          'data': {
            'razorpay_payment_id': 'pay_2',
            'razorpay_order_id': 'order_abc',
            'razorpay_signature': 'sig',
          },
        },
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final outcome = await RazorpayPaymentLauncher().open(_request);
    expect(
      outcome,
      isA<PaymentAuthorized>().having(
        (o) => o.razorpayPaymentId,
        'payment',
        'pay_2',
      ),
    );
  });

  test('a late success for another Razorpay order is ignored', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'resync' => {
          'type': 0,
          'data': {
            'razorpay_payment_id': 'pay_old',
            'razorpay_order_id': 'order_OLD',
            'razorpay_signature': 'sig',
          },
        },
        'open' => {
          'type': 1,
          'data': {'code': Razorpay.PAYMENT_CANCELLED, 'message': 'closed'},
        },
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    // Without the drain, so the replay reaches the listeners.
    final outcome = await RazorpayPaymentLauncher(dropStaleResult: () async {})
        .open(_request);
    expect(
      outcome,
      isA<PaymentNotCompleted>().having(
        (o) => o.reason,
        'reason',
        PaymentFailureReason.cancelled,
      ),
    );
  });

  test('a late error for another Razorpay order is ignored', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        // A failure Razorpay tied to an older order (metadata.order_id).
        'resync' => {
          'type': 1,
          'data': {
            'code': Razorpay.NETWORK_ERROR,
            'message': 'old',
            'responseBody': {
              'metadata': {'order_id': 'order_OLD', 'payment_id': 'pay_old'},
            },
          },
        },
        'open' => {
          'type': 0,
          'data': {
            'razorpay_payment_id': 'pay_3',
            'razorpay_order_id': 'order_abc',
            'razorpay_signature': 'sig',
          },
        },
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final outcome = await RazorpayPaymentLauncher(dropStaleResult: () async {})
        .open(_request);
    expect(outcome, isA<PaymentAuthorized>());
  });

  test('no event at all gives up after the safety timeout', () async {
    // `open` never answers (a dropped reply).
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'open') await Completer<void>().future;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final launcher = RazorpayPaymentLauncher(
      safetyTimeout: (_) => const Duration(milliseconds: 50),
    );
    final outcome = await launcher.open(_request);
    expect(
      outcome,
      isA<PaymentNotCompleted>().having(
        (o) => o.reason,
        'reason',
        PaymentFailureReason.unknown,
      ),
    );
    // The window plus 2 minutes, capped at 30.
    expect(
      RazorpayPaymentLauncher.defaultSafetyTimeout(_request),
      const Duration(seconds: 840 + 120),
    );
  });

  test('an external wallet hands over to the server', () async {
    nativeAnswers({
      'type': 2,
      'data': {'external_wallet': 'paytm'},
    });
    final outcome = await RazorpayPaymentLauncher().open(_request);
    expect(
      outcome,
      isA<PaymentExternalWallet>().having((o) => o.walletName, 'w', 'paytm'),
    );
  });
}
