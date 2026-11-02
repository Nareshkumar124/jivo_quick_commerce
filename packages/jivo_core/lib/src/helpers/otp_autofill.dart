/// Reads the OTP from the incoming SMS so the user does not have to type it
/// (`03 §2.2`, `04 §2.1`).
///
/// The apps implement it with smart_auth's SMS User Consent API on Android
/// (no SMS permission, no app hash in the DLT template). iOS offers the code
/// above the keyboard through `AutofillHints.oneTimeCode`, so the iOS
/// implementation is [NoOtpAutofill].
abstract interface class OtpAutofill {
  /// Waits for the next OTP SMS and returns its code, or null when the user
  /// declined, it timed out, or it is unsupported. Never throws.
  Future<String?> listenForCode();

  /// Stops listening. Safe to call when not listening.
  Future<void> stop();
}

/// No autofill: unsupported platforms and tests that don't need it.
class NoOtpAutofill implements OtpAutofill {
  const NoOtpAutofill();

  @override
  Future<String?> listenForCode() async => null;

  @override
  Future<void> stop() async {}
}

/// For tests: returns [code] (null means nothing arrived) and counts calls.
class FakeOtpAutofill implements OtpAutofill {
  FakeOtpAutofill([this.code]);

  /// What [listenForCode] returns.
  String? code;

  /// How often [listenForCode] and [stop] were called.
  int listens = 0;
  int stops = 0;

  @override
  Future<String?> listenForCode() async {
    listens++;
    return code;
  }

  @override
  Future<void> stop() async => stops++;
}
