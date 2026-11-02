import 'package:flutter/widgets.dart';

import '../l10n/generated/jivo_core_localizations.dart';
import 'api_error.dart';

/// The one place that turns an [ApiError] into text a user may see.
///
/// The switch is exhaustive, so adding an [ApiErrorCode] without a message is
/// a compile error. Server messages and exception text are never shown.
String apiErrorMessage(JivoCoreLocalizations l10n, ApiError error) =>
    switch (error.code) {
      ApiErrorCode.validationError => l10n.errorValidation,
      ApiErrorCode.otpInvalid => l10n.errorOtpInvalid,
      ApiErrorCode.otpExpired => l10n.errorOtpExpired,
      ApiErrorCode.otpRateLimited => l10n.errorOtpRateLimited,
      ApiErrorCode.authRequired => l10n.errorAuthRequired,
      ApiErrorCode.tokenInvalid => l10n.errorTokenInvalid,
      ApiErrorCode.permissionDenied => l10n.errorPermissionDenied,
      ApiErrorCode.notFound => l10n.errorNotFound,
      ApiErrorCode.appUpdateRequired => l10n.errorAppUpdateRequired,
      ApiErrorCode.notServiceable => l10n.errorNotServiceable,
      ApiErrorCode.storeClosed => l10n.errorStoreClosed,
      ApiErrorCode.stockUnavailable => l10n.errorStockUnavailable,
      ApiErrorCode.maxQtyExceeded => l10n.errorMaxQtyExceeded,
      ApiErrorCode.minOrderNotMet => l10n.errorMinOrderNotMet,
      ApiErrorCode.couponInvalid => l10n.errorCouponInvalid,
      ApiErrorCode.couponExpired => l10n.errorCouponExpired,
      ApiErrorCode.couponNotEligible => l10n.errorCouponNotEligible,
      ApiErrorCode.couponUsageExceeded => l10n.errorCouponUsageExceeded,
      ApiErrorCode.codNotAvailable => l10n.errorCodNotAvailable,
      ApiErrorCode.priceChanged => l10n.errorPriceChanged,
      ApiErrorCode.paymentVerificationFailed =>
        l10n.errorPaymentVerificationFailed,
      ApiErrorCode.invalidStateTransition => l10n.errorInvalidStateTransition,
      ApiErrorCode.offerExpired => l10n.errorOfferExpired,
      ApiErrorCode.offerTaken => l10n.errorOfferTaken,
      ApiErrorCode.outsideGeofence => l10n.errorOutsideGeofence,
      ApiErrorCode.deliveryOtpInvalid => l10n.errorDeliveryOtpInvalid,
      ApiErrorCode.deliveryOtpLocked => l10n.errorDeliveryOtpLocked,
      ApiErrorCode.cashLimitExceeded => l10n.errorCashLimitExceeded,
      ApiErrorCode.maintenance => l10n.errorMaintenance,
      ApiErrorCode.rateLimited => l10n.errorRateLimited,
      ApiErrorCode.serviceUnavailable => l10n.errorServiceUnavailable,
      // Protocol errors are app bugs the user can't act on.
      ApiErrorCode.methodNotAllowed ||
      ApiErrorCode.notAcceptable ||
      ApiErrorCode.unsupportedMediaType => l10n.errorGeneric,
      ApiErrorCode.network => l10n.errorNetwork,
      ApiErrorCode.timeout => l10n.errorTimeout,
      ApiErrorCode.cancelled => l10n.errorCancelled,
      ApiErrorCode.serverError => l10n.errorServer,
      ApiErrorCode.unknown => l10n.errorGeneric,
    };

/// Like [apiErrorMessage], but uses the error `details` where they help:
/// the attempts left for `OTP_INVALID` and the wait for `OTP_RATE_LIMITED` /
/// `RATE_LIMITED`. Falls back to [apiErrorMessage] otherwise.
String apiErrorMessageWithDetails(JivoCoreLocalizations l10n, ApiError error) {
  final attempts = error.attemptsRemaining;
  final retryAfter = error.retryAfterSeconds;
  return switch (error.code) {
    ApiErrorCode.otpInvalid when attempts != null =>
      l10n.errorOtpInvalidAttempts(attempts),
    ApiErrorCode.otpRateLimited || ApiErrorCode.rateLimited
        when retryAfter != null && retryAfter > 0 =>
      l10n.errorTryAgainInMinutes((retryAfter / 60).ceil()),
    _ => apiErrorMessage(l10n, error),
  };
}

/// [describeError] with [apiErrorMessageWithDetails].
String describeErrorWithDetails(BuildContext context, Object error) =>
    apiErrorMessageWithDetails(
      JivoCoreLocalizations.of(context),
      ApiError.from(error),
    );

/// Convenience for widgets: the user-facing message for any [error] thrown
/// by a repository call. Requires [JivoCoreLocalizations.delegate] in the
/// app's `localizationsDelegates`.
String describeError(BuildContext context, Object error) =>
    apiErrorMessage(JivoCoreLocalizations.of(context), ApiError.from(error));
