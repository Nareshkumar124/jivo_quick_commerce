import 'package:flutter/widgets.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/task_status.dart';
import 'task_flow_controller.dart';
import '../../../shared/errors/rider_error_codes.dart';
import '../../../shared/errors/rider_error_text.dart';
import '../domain/task_rules.dart';

/// User-facing text for an offer or task error (one place, agent rule 10).
/// Server messages are never shown; codes and details decide the text.
String taskErrorText(
  BuildContext context,
  ApiError error, {
  TaskAction? action,
}) {
  final l10n = AppLocalizations.of(context);
  if (error.riderCode != null) return riderApiErrorMessage(context, error);
  if (error.isWaitNotElapsed) return l10n.failWaitNotElapsed;
  final dueNow = error.codAmountDueNow;
  if (dueNow != null && action == TaskAction.deliver) {
    final formatted = tryFormatRupees(dueNow);
    return formatted == null
        ? l10n.codAmountMismatch
        : l10n.codAmountChangedCollect(formatted);
  }
  if (error.isUpiNotPaid && action == TaskAction.deliver) {
    return l10n.codUpiNotConfirmed;
  }
  switch (error.code) {
    case ApiErrorCode.outsideGeofence:
      final distance = error.details['distance_m'];
      return distance is num
          ? l10n.taskOutsideGeofenceDistance(distance.round())
          : l10n.taskOutsideGeofence;
    case ApiErrorCode.validationError when action == TaskAction.pickup:
      return l10n.pickupCodeWrong;
    case ApiErrorCode.validationError
        when action == TaskAction.fail &&
            error.fieldErrors.containsKey('call_attempts'):
      return l10n.failNeedsCalls;
    case ApiErrorCode.validationError when action == TaskAction.deliver:
      return l10n.codAmountMismatch;
    case ApiErrorCode.invalidStateTransition when error.isNotPacked:
      return l10n.pickupNotPacked;
    case ApiErrorCode.invalidStateTransition:
      return l10n.taskStateChanged;
    case ApiErrorCode.deliveryOtpInvalid:
      final left = error.attemptsRemaining;
      return left == null
          ? l10n.deliveryOtpWrong
          : l10n.deliveryOtpWrongLeft(left);
    case ApiErrorCode.deliveryOtpLocked:
      return l10n.deliveryOtpLocked;
    case ApiErrorCode.cashLimitExceeded:
      return l10n.cashLimitExceeded;
    case ApiErrorCode.offerExpired:
      return l10n.offerExpiredBody;
    case ApiErrorCode.offerTaken:
      return l10n.offerTakenBody;
    default:
      return riderApiErrorMessage(context, error);
  }
}

String taskLocalErrorText(AppLocalizations l10n, TaskLocalError error) =>
    switch (error) {
      TaskLocalError.notAllowed => l10n.taskStateChanged,
      TaskLocalError.locationUnavailable => l10n.taskLocationUnavailable,
      TaskLocalError.invalidPickupCode => l10n.pickupCodeFormat,
      TaskLocalError.pickupLocked => l10n.pickupCodeLocked,
      TaskLocalError.codIncomplete => l10n.codConfirmFirst,
      TaskLocalError.failNotAllowedYet => l10n.failNotYet,
    };

/// `2.4 km`.
String distanceText(AppLocalizations l10n, String? km) =>
    km == null ? '' : l10n.distanceKm(km);
