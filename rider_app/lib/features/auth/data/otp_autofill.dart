import 'package:flutter/foundation.dart';
import 'package:smart_auth/smart_auth.dart';

/// Reads the OTP from the incoming SMS so the rider does not have to type it.
abstract interface class OtpAutofill {
  /// Waits for the next OTP SMS and returns its code, or null if the rider
  /// declined, it timed out or it is unsupported.
  Future<String?> listenForCode();

  /// Stops listening.
  Future<void> stop();
}

/// Android SMS User Consent API via smart_auth: the system asks the rider
/// once to let the app read that one SMS. Unlike the SMS Retriever API it
/// needs no app-signature hash in the message, which suits India's
/// DLT-registered fixed SMS templates and works across flavors and signing
/// keys. No SMS permission is requested.
class SmsUserConsentAutofill implements OtpAutofill {
  const SmsUserConsentAutofill();

  @override
  Future<String?> listenForCode() async {
    final result = await SmartAuth.instance.getSmsWithUserConsentApi(
      matcher: r'\d{4,8}',
    );
    if (!result.hasData) return null;
    return result.data?.code;
  }

  @override
  Future<void> stop() async {
    try {
      await SmartAuth.instance.removeUserConsentApiListener();
    } on Object catch (error) {
      debugPrint('SmsUserConsentAutofill.stop: $error');
    }
  }
}

/// No autofill (tests, unsupported platforms).
class NoOtpAutofill implements OtpAutofill {
  const NoOtpAutofill();

  @override
  Future<String?> listenForCode() async => null;

  @override
  Future<void> stop() async {}
}
