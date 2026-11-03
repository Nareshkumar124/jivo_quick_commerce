import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import 'payment_launcher.dart';

/// Signs a fake payment the way the backend's fake gateway expects.
typedef FakePaymentSigner = String Function(
  String razorpayOrderId,
  String razorpayPaymentId,
);

/// TODO(api): the backend's dev-only fake-payment signature scheme (backend
/// P3 R1, D-01: no Razorpay test keys yet). Until the PM sends the scheme
/// at the sync point, only the app's own fake backend checks this value.
String fakePaymentSignature(String razorpayOrderId, String razorpayPaymentId) =>
    'fake_signature:$razorpayOrderId:$razorpayPaymentId';

/// How a fake payment ends.
enum FakePaymentChoice {
  succeed,

  /// The SDK reports success but the signature is wrong: the server must
  /// answer `PAYMENT_VERIFICATION_FAILED`.
  badSignature,
  fail,
  cancel,
  externalWallet,
}

/// The **dev-flavor** payment launcher while there are no Razorpay test
/// keys (D-01). No SDK and no money: [choose] decides the outcome (a sheet
/// on the phone, a fixed answer in tests), and success carries a
/// [signer]-made signature for the server's verify call.
class FakePaymentLauncher implements PaymentLauncher {
  FakePaymentLauncher({
    required this.choose,
    this.signer = fakePaymentSignature,
  });

  final Future<FakePaymentChoice?> Function(PaymentRequest request) choose;
  final FakePaymentSigner signer;
  int _sequence = 1;

  /// The requests seen (tests).
  final requests = <PaymentRequest>[];

  @override
  Future<PaymentOutcome> open(PaymentRequest request) async {
    requests.add(request);
    final choice = await choose(request) ?? FakePaymentChoice.cancel;
    final orderId = request.checkout.orderId;
    final paymentId = 'pay_fake_${_sequence++}';
    return switch (choice) {
      FakePaymentChoice.succeed => PaymentAuthorized(
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signer(orderId, paymentId),
      ),
      FakePaymentChoice.badSignature => PaymentAuthorized(
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: 'bad_signature',
      ),
      FakePaymentChoice.fail => const PaymentNotCompleted(
        PaymentFailureReason.unknown,
      ),
      FakePaymentChoice.cancel => const PaymentNotCompleted(
        PaymentFailureReason.cancelled,
      ),
      FakePaymentChoice.externalWallet => const PaymentExternalWallet(
        'fake_wallet',
      ),
    };
  }
}

/// The dev build's stand-in for Razorpay checkout: a sheet on the root
/// navigator that asks how the payment should end.
Future<FakePaymentChoice?> showFakePaymentSheet(
  GlobalKey<NavigatorState> navigatorKey,
  PaymentRequest request,
) async {
  final context = navigatorKey.currentContext;
  if (context == null) return null;
  return showModalBottomSheet<FakePaymentChoice>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      Widget option(FakePaymentChoice choice, String label, IconData icon) =>
          ListTile(
            key: ValueKey('fake-pay-${choice.name}'),
            minTileHeight: kJivoMinTouchTarget,
            leading: Icon(icon),
            title: Text(label),
            onTap: () => Navigator.pop(context, choice),
          );
      return ListView(
        key: const Key('fake-payment-sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: JivoSpacing.xl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.fakePaymentTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: JivoSpacing.xs),
                Text(
                  l10n.fakePaymentBody(formatRupees(request.grandTotal)),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: JivoSpacing.sm),
              ],
            ),
          ),
          option(
            FakePaymentChoice.succeed,
            l10n.fakePaymentSucceed,
            Icons.check_circle_outline,
          ),
          option(
            FakePaymentChoice.badSignature,
            l10n.fakePaymentBadSignature,
            Icons.gpp_bad_outlined,
          ),
          option(
            FakePaymentChoice.fail,
            l10n.fakePaymentFail,
            Icons.error_outline,
          ),
          option(
            FakePaymentChoice.externalWallet,
            l10n.fakePaymentWallet,
            Icons.account_balance_wallet_outlined,
          ),
          option(FakePaymentChoice.cancel, l10n.fakePaymentCancel, Icons.close),
        ],
      );
    },
  );
}
