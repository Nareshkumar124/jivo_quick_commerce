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
    this.supportEmail,
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

  /// `support.email`: Help's "Email us" row opens it (`03 §2.11`).
  final String? supportEmail;
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

  /// The web page for a policy slug: the `config/app` URL for terms,
  /// privacy and `refund-policy`; for the other launch pages
  /// (`delivery-policy`, `contact`, `delete-account`) the sibling of the
  /// terms URL when it is a `/legal/<slug>/` page (the server's
  /// `load_legal_pages` layout, e.g. https://quick.jivo.in/legal/terms/).
  /// Null when there is no such page.
  Uri? forSlug(String slug) {
    switch (slug) {
      case 'terms':
        return terms;
      case 'privacy':
        return privacy;
      case 'refund-policy':
        return refund;
    }
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(slug)) return null;
    final segments = terms.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2 || segments[segments.length - 2] != 'legal') {
      return null;
    }
    return Uri(
      scheme: terms.scheme,
      host: terms.host,
      port: terms.hasPort ? terms.port : null,
      pathSegments: [...segments.take(segments.length - 1), slug, ''],
    );
  }
}
