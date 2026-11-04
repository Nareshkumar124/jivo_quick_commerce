import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/features/checkout/data/fake_payment_launcher.dart';
import 'package:customer_app/features/checkout/data/payment_launcher.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

const _request = PaymentRequest(
  checkout: RazorpayCheckout(
    keyId: 'rzp_test_fake',
    orderId: 'order_fake_1',
    amountPaise: 50300,
  ),
  orderNumber: 'JQ001001',
  grandTotal: '503.00',
);

void main() {
  setUpAll(initializeFormatting);

  Future<GlobalKey<NavigatorState>> pumpApp(WidgetTester tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        theme: JivoTheme.light(),
        locale: const Locale('en', 'IN'),
        supportedLocales: const [Locale('en', 'IN')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          JivoCoreLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: SizedBox()),
      ),
    );
    return key;
  }

  testWidgets('the dev sheet shows the amount and returns the choice', (
    tester,
  ) async {
    final key = await pumpApp(tester);
    final launcher = FakePaymentLauncher(
      choose: (request) => showFakePaymentSheet(key, request),
    );

    final pending = launcher.open(_request);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-payment-sheet')), findsOneWidget);
    expect(find.text('Test payment (dev build)'), findsOneWidget);
    expect(
      find.text('No real money moves. Choose how paying ₹503 ends.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('fake-pay-succeed')));
    await tester.pumpAndSettle();
    final outcome = await pending;
    expect(outcome, isA<PaymentAuthorized>());
    final paid = outcome as PaymentAuthorized;
    expect(paid.razorpayOrderId, 'order_fake_1');
    expect(
      paid.razorpaySignature,
      fakePaymentSignature('order_fake_1', paid.razorpayPaymentId),
    );
  });

  testWidgets('dismissing the sheet counts as a cancelled payment', (
    tester,
  ) async {
    final key = await pumpApp(tester);
    final launcher = FakePaymentLauncher(
      choose: (request) => showFakePaymentSheet(key, request),
    );

    final pending = launcher.open(_request);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // the barrier
    await tester.pumpAndSettle();
    expect(
      await pending,
      isA<PaymentNotCompleted>().having(
        (o) => o.reason,
        'reason',
        PaymentFailureReason.cancelled,
      ),
    );
  });

  test('every choice maps to an outcome', () async {
    for (final (choice, matcher) in [
      (FakePaymentChoice.badSignature, isA<PaymentAuthorized>()),
      (FakePaymentChoice.fail, isA<PaymentNotCompleted>()),
      (FakePaymentChoice.externalWallet, isA<PaymentExternalWallet>()),
    ]) {
      final launcher = FakePaymentLauncher(choose: (_) async => choice);
      expect(await launcher.open(_request), matcher, reason: '$choice');
    }
  });
}
