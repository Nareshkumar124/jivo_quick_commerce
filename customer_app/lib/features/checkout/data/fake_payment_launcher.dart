import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

/// The fake gateway's published key secret (`06 §2.6`, local development
/// only). Deliberately public, not a secret: it works only with the
/// server's fake gateway, which staging and production refuse.
const fakeGatewayKeySecret = 'jivo-fake-razorpay-key-secret-local-only';

/// The fake gateway's payment signature (`06 §2.6`): Razorpay's own
/// algorithm, lowercase hex HMAC-SHA256 of `"<order_id>|<payment_id>"`,
/// keyed with [fakeGatewayKeySecret]. The server's verify runs the same
/// code as for real payments.
String fakePaymentSignature(String razorpayOrderId, String razorpayPaymentId) =>
    Hmac(
      sha256,
      utf8.encode(fakeGatewayKeySecret),
    ).convert(utf8.encode('$razorpayOrderId|$razorpayPaymentId')).toString();

const _alphanumerics =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

/// A made-up payment id: `"pay_"` + 14 letters/digits (`06 §2.6`).
String newFakePaymentId([Random? random]) {
  final rng = random ?? Random.secure();
  final suffix = String.fromCharCodes([
    for (var i = 0; i < 14; i++)
      _alphanumerics.codeUnitAt(rng.nextInt(_alphanumerics.length)),
  ]);
  return 'pay_$suffix';
}

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

/// The **dev-flavor** stand-in for Razorpay checkout when the server uses
/// its local fake gateway (`razorpay.key_id` starts with `rzp_fake_`,
/// `06 §2.6`): no SDK and no money. [choose] decides the outcome (a sheet
/// on the phone, a fixed answer in tests); success carries a made-up
/// payment id and the [signer]'s signature for the server's verify call.
/// Only `GatewayPaymentLauncher` in the dev flavor ever opens it.
class FakePaymentLauncher implements PaymentLauncher {
  FakePaymentLauncher({
    required this.choose,
    this.signer = fakePaymentSignature,
    String Function()? newPaymentId,
  }) : _newPaymentId = newPaymentId ?? newFakePaymentId;

  final Future<FakePaymentChoice?> Function(PaymentRequest request) choose;
  final FakePaymentSigner signer;
  final String Function() _newPaymentId;

  /// The requests seen (tests).
  final requests = <PaymentRequest>[];

  @override
  Future<PaymentOutcome> open(PaymentRequest request) async {
    requests.add(request);
    final choice = await choose(request) ?? FakePaymentChoice.cancel;
    final orderId = request.checkout.orderId;
    final paymentId = _newPaymentId();
    return switch (choice) {
      FakePaymentChoice.succeed => PaymentAuthorized(
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signer(orderId, paymentId),
      ),
      FakePaymentChoice.badSignature => PaymentAuthorized(
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signer(orderId, '${paymentId}x'),
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
