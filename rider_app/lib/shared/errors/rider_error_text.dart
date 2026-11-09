import 'package:flutter/widgets.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../l10n/app_localizations.dart';
import 'rider_error_codes.dart';

/// jivo_core's error message, with the rider's own wording where it differs.
/// The rider endpoints are throttled (P5 contract): a 429 reads calmly as
/// "Too many tries. Wait a moment, then try again." rather than an error.
/// Rider-only codes ([RiderErrorCode]) are mapped here too.
String riderApiErrorMessage(BuildContext context, ApiError error) {
  final l10n = AppLocalizations.of(context);
  switch (error.riderCode) {
    case RiderErrorCode.pickupCodeInvalid:
      final left = error.attemptsRemaining;
      return left == null
          ? l10n.pickupCodeWrong
          : l10n.pickupCodeWrongLeft(left);
    case RiderErrorCode.pickupCodeLocked:
      return l10n.pickupCodeLocked;
    case RiderErrorCode.riderOffline:
      return l10n.riderOfflineError;
    case null:
      break;
  }
  return switch (error.code) {
    ApiErrorCode.rateLimited => l10n.riderTooManyTries,
    _ => apiErrorMessage(JivoCoreLocalizations.of(context), error),
  };
}
