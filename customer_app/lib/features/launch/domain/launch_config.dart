import 'package:flutter/foundation.dart';

/// What the app needs from `GET /api/v1/config/app/` at start-up.
@immutable
class LaunchConfig {
  const LaunchConfig({
    required this.maintenance,
    required this.termsVersion,
    required this.policies,
    this.minSupportedVersion,
    this.latestVersion,
    this.storeUrl,
    this.maintenanceMessage,
    this.otpLength = 6,
    this.resendAfterSeconds = 30,
    this.supportPhone,
  });

  final String? minSupportedVersion;
  final String? latestVersion;
  final Uri? storeUrl;
  final bool maintenance;
  final String? maintenanceMessage;

  /// Sent with `otp/verify` as the user's consent (DPDP).
  final String termsVersion;
  final PolicyLinks policies;
  final int otpLength;
  final int resendAfterSeconds;

  /// `support.phone`: "Contact support" calls it (`03 §2.10`).
  final String? supportPhone;
}

@immutable
class PolicyLinks {
  const PolicyLinks({
    required this.terms,
    required this.privacy,
    required this.refund,
  });

  final Uri terms;
  final Uri privacy;
  final Uri refund;
}
