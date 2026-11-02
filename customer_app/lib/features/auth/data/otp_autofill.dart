import 'package:flutter/foundation.dart';
import 'package:jivo_core/helpers.dart';
import 'package:smart_auth/smart_auth.dart';

/// Android SMS User Consent API via smart_auth (same package as the rider
/// app). The user approves reading one SMS; no app hash is needed in the
/// DLT template. Other platforms: no-op (iOS offers the code above the
/// keyboard through `AutofillHints.oneTimeCode`). The [OtpAutofill]
/// interface and its test doubles live in jivo_core.
class SmartAuthOtpAutofill implements OtpAutofill {
  SmartAuthOtpAutofill([SmartAuth? smartAuth])
    : _smartAuth = smartAuth ?? SmartAuth.instance;

  final SmartAuth _smartAuth;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> listenForCode() async {
    if (!_supported) return null;
    try {
      final result = await _smartAuth.getSmsWithUserConsentApi();
      return result.hasData ? result.data!.code : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> stop() async {
    if (!_supported) return;
    try {
      await _smartAuth.removeUserConsentApiListener();
    } catch (_) {
      // Nothing to stop.
    }
  }
}
