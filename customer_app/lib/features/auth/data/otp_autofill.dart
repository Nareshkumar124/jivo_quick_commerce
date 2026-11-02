import 'package:flutter/foundation.dart';
import 'package:smart_auth/smart_auth.dart';

/// Reads the OTP from the incoming SMS (`03 §2.2`).
abstract interface class OtpAutofill {
  /// Waits for the OTP SMS and returns the code, or null if unavailable,
  /// cancelled or not found.
  Future<String?> listen();

  /// Stops listening.
  Future<void> cancel();
}

/// Android SMS User Consent API via smart_auth (same package as the rider
/// app). The user approves reading one SMS; no app hash is needed in the
/// DLT template. Other platforms: no-op (iOS offers the code above the
/// keyboard through `AutofillHints.oneTimeCode`).
class SmartAuthOtpAutofill implements OtpAutofill {
  SmartAuthOtpAutofill([SmartAuth? smartAuth])
    : _smartAuth = smartAuth ?? SmartAuth.instance;

  final SmartAuth _smartAuth;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> listen() async {
    if (!_supported) return null;
    try {
      final result = await _smartAuth.getSmsWithUserConsentApi();
      return result.hasData ? result.data!.code : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _smartAuth.removeUserConsentApiListener();
    } catch (_) {
      // Nothing to cancel.
    }
  }
}

/// For tests: returns [code] (or nothing).
class FakeOtpAutofill implements OtpAutofill {
  FakeOtpAutofill([this.code]);

  final String? code;
  int listens = 0;
  int cancels = 0;

  @override
  Future<String?> listen() async {
    listens++;
    return code;
  }

  @override
  Future<void> cancel() async => cancels++;
}
