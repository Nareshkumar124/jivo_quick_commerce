import 'package:flutter/foundation.dart';
import 'package:jivo_core/helpers.dart';
import 'package:smart_auth/smart_auth.dart';

/// Android SMS User Consent API via smart_auth: the system asks the rider
/// once to let the app read that one SMS. Unlike the SMS Retriever API it
/// needs no app-signature hash in the message, which suits India's
/// DLT-registered fixed SMS templates and works across flavors and signing
/// keys. No SMS permission is requested.
///
/// The [OtpAutofill] interface and its test doubles ([NoOtpAutofill],
/// `FakeOtpAutofill`) live in jivo_core.
class SmsUserConsentAutofill implements OtpAutofill {
  const SmsUserConsentAutofill();

  @override
  Future<String?> listenForCode() async {
    // jivo_core's contract: never throws.
    try {
      final result = await SmartAuth.instance.getSmsWithUserConsentApi(
        matcher: r'\d{4,8}',
      );
      if (!result.hasData) return null;
      return result.data?.code;
    } on Object catch (error) {
      debugPrint('SmsUserConsentAutofill.listenForCode: $error');
      return null;
    }
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
