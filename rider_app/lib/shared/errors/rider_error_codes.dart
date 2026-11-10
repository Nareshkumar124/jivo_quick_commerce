import 'package:jivo_core/jivo_core.dart';

/// Rider error codes of the slice 5.3 contract that jivo_core's
/// [ApiErrorCode] does not list yet (it maps them to `unknown` and keeps
/// the wire string in [ApiError.rawCode]).
///
/// TODO(jivo_core): propose adding `PICKUP_CODE_INVALID`,
/// `PICKUP_CODE_LOCKED` and `RIDER_OFFLINE` to `ApiErrorCode` (additive);
/// kept here so the customer app's exhaustive switches are not disturbed
/// mid-phase.
enum RiderErrorCode {
  pickupCodeInvalid('PICKUP_CODE_INVALID'),
  pickupCodeLocked('PICKUP_CODE_LOCKED'),
  riderOffline('RIDER_OFFLINE');

  const RiderErrorCode(this.wireValue);

  final String wireValue;
}

extension RiderApiError on ApiError {
  /// The rider-only code, or null.
  RiderErrorCode? get riderCode {
    for (final code in RiderErrorCode.values) {
      if (rawCode == code.wireValue) return code;
    }
    return null;
  }

  /// `fail` before `not_reachable_after`: 409 INVALID_STATE_TRANSITION with
  /// `details.reason` = `WAIT_NOT_ELAPSED`.
  bool get isWaitNotElapsed =>
      code == ApiErrorCode.invalidStateTransition &&
      details['reason'] == 'WAIT_NOT_ELAPSED';

  /// `details.not_reachable_after` of [isWaitNotElapsed], parsed.
  DateTime? get notReachableAfter {
    final raw = details['not_reachable_after'];
    return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  }

  /// `pickup` before PACKED: 409 with `details.order_status`.
  bool get isNotPacked =>
      code == ApiErrorCode.invalidStateTransition &&
      details['order_status'] is String &&
      details['order_status'] != 'PACKED';

  /// `deliver` with a COD amount that is no longer due: 400 with
  /// `details.amount_due` (the server's amount now).
  String? get codAmountDueNow {
    if (code != ApiErrorCode.validationError) return null;
    final due = details['amount_due'];
    return due is String ? due : null;
  }

  /// `deliver` with `cod.mode` = upi before the server saw the payment.
  bool get isUpiNotPaid =>
      code == ApiErrorCode.validationError &&
      codAmountDueNow == null &&
      details['cod'] is List;
}
