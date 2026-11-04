import 'dart:developer' as developer;

import 'package:jivo_core/jivo_core.dart' show Flavor;

import 'payment_launcher.dart';

/// Picks the checkout for the key the server sent (`06 §2.6`):
/// - `rzp_fake_…` in the **dev** flavor: the server's local fake gateway,
///   paid with [fake] (no Razorpay, no money);
/// - `rzp_fake_…` in staging or prod: an error. It is never paid, and the
///   fake is never opened (deployed servers refuse the fake gateway, so this
///   means a misconfigured server);
/// - any other key: real Razorpay checkout ([real]), in every flavor.
class GatewayPaymentLauncher implements PaymentLauncher {
  GatewayPaymentLauncher({required this.flavor, required this.real, this.fake})
    : assert(
        fake == null || flavor == Flavor.dev,
        'the fake gateway is dev-only',
      );

  final Flavor flavor;
  final PaymentLauncher real;

  /// Dev flavor only.
  final PaymentLauncher? fake;

  @override
  Future<PaymentOutcome> open(PaymentRequest request) async {
    if (!request.checkout.isFakeGateway) return real.open(request);
    final fakeLauncher = fake;
    if (flavor == Flavor.dev && fakeLauncher != null) {
      return fakeLauncher.open(request);
    }
    developer.log(
      'Refusing a fake-gateway checkout in the ${flavor.name} flavor',
      name: 'payments',
    );
    return const PaymentNotCompleted(PaymentFailureReason.invalidOptions);
  }
}
