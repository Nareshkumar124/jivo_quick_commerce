import 'package:flutter/widgets.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/app_localizations.dart';
import 'login_controllers.dart';

/// User-facing text for a login error. Adds the details the rider needs
/// (attempts left, wait time) to the OTP errors; everything else goes through
/// jivo_core's [apiErrorMessage]. Server messages are never shown.
String authErrorText(BuildContext context, ApiError error) {
  final l10n = AppLocalizations.of(context);
  switch (error.code) {
    case ApiErrorCode.otpInvalid:
      final remaining = error.details['attempts_remaining'];
      if (remaining is num) return l10n.otpWrongCode(remaining.toInt());
    case ApiErrorCode.otpExpired:
      return l10n.otpExpired;
    case ApiErrorCode.otpRateLimited:
      final seconds = retryAfterSeconds(error);
      if (seconds != null) {
        return l10n.authRateLimited((seconds / 60).ceil().clamp(1, 1440));
      }
    default:
      break;
  }
  return apiErrorMessage(JivoCoreLocalizations.of(context), error);
}
