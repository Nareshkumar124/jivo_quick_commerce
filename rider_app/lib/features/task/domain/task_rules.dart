import 'rider_task.dart';

/// `"1249.00"` → `₹1,249.00` (Indian digit grouping). Formatting only: the
/// amount string from the server is never parsed into a number, so nothing
/// is rounded or computed in the app.
String formatRupees(String amount) {
  final trimmed = amount.trim();
  final match = RegExp(r'^(-?)(\d+)(\.\d+)?$').firstMatch(trimmed);
  if (match == null) return '₹$trimmed';
  final sign = match.group(1)!;
  final whole = match.group(2)!;
  final fraction = match.group(3) ?? '';
  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return '$sign₹$grouped$fraction';
}

// ------------------------------------------------------------------ COD

/// How the rider collected a COD amount (06 §3 `deliver` `cod.mode`).
enum CodMode {
  cash('cash'),
  upi('upi');

  const CodMode(this.wireValue);

  final String wireValue;
}

/// The rider's COD choice before `deliver`: cash with an explicit
/// confirmation, or UPI confirmed by the server.
class CodCollection {
  const CodCollection.cash({required this.cashConfirmed}) : mode = CodMode.cash;

  const CodCollection.upi() : mode = CodMode.upi, cashConfirmed = false;

  final CodMode mode;

  /// The rider tapped "Cash collected ₹X" and confirmed it.
  final bool cashConfirmed;
}

enum CodProblem {
  /// A COD order needs a collection choice.
  collectionMissing,

  /// Cash: the rider has not confirmed the exact amount.
  cashNotConfirmed,

  /// UPI: the server has not confirmed the payment yet.
  upiNotPaid,

  /// Prepaid orders collect nothing.
  notCod,
}

/// Whether `deliver` may be sent for [task] with [collection] (agent rule 6,
/// T10 guard). The amount sent is always [RiderTask.codAmountDue] unchanged.
CodProblem? validateCodForDeliver(RiderTask task, CodCollection? collection) {
  if (!task.isCod) return collection == null ? null : CodProblem.notCod;
  if (collection == null) return CodProblem.collectionMissing;
  return switch (collection.mode) {
    CodMode.cash when !collection.cashConfirmed => CodProblem.cashNotConfirmed,
    CodMode.cash => null,
    CodMode.upi when task.codQr?.status != UpiQrStatus.paid =>
      CodProblem.upiNotPaid,
    CodMode.upi => null,
  };
}

// --------------------------------------------------------------- pickup

/// Pickup codes are 4 letters or digits (04 §2.5). Typed codes are
/// upper-cased; ambiguous characters are not mapped, the server decides.
const kPickupCodeLength = 4;

String? normalisePickupCode(String input) {
  final code = input.trim().toUpperCase();
  return RegExp(r'^[A-Z0-9]{4}$').hasMatch(code) ? code : null;
}

/// The pickup code from a scanned QR. Conservative: only a QR that is
/// exactly the 4-character code is accepted.
///
/// TODO(api): the label's QR content is not specified (API question).
String? pickupCodeFromQr(String? raw) =>
    raw == null ? null : normalisePickupCode(raw);

// ------------------------------------------------------- failed delivery

/// Failed-delivery reasons (04 §2.6).
///
/// TODO(api): wire values assumed.
enum FailReason {
  notReachable('CUSTOMER_NOT_REACHABLE'),
  refused('CUSTOMER_REFUSED'),
  wrongAddress('WRONG_ADDRESS'),
  other('OTHER');

  const FailReason(this.wireValue);

  final String wireValue;
}

/// "Not reachable" needs call attempts and a 10-minute wait at the drop
/// (04 §2.6, T13). Open questions for Jivo: how many calls, and whether the
/// wait starts at arrival (used here) or at the first call.
const kNotReachableWait = Duration(minutes: 10);
const kMinCallAttempts = 2;

/// Time left before "not reachable" can be chosen, or zero when it can.
/// Counts from the server's `arrived_customer_at`, so a restart does not
/// reset it. Null when the rider has not arrived (not allowed at all).
Duration? notReachableWaitLeft(RiderTask task, DateTime now) {
  final arrived = task.arrivedCustomerAt;
  if (arrived == null) return null;
  final left = arrived.add(kNotReachableWait).difference(now.toUtc());
  return left.isNegative ? Duration.zero : left;
}

/// Why a fail reason cannot be submitted yet, or null when it can.
enum FailBlock { notArrived, needsCalls, waitRunning, noteRequired }

FailBlock? failReasonBlock({
  required FailReason reason,
  required RiderTask task,
  required int callAttempts,
  required DateTime now,
  required String note,
}) {
  switch (reason) {
    case FailReason.notReachable:
      final left = notReachableWaitLeft(task, now);
      if (left == null) return FailBlock.notArrived;
      if (callAttempts < kMinCallAttempts) return FailBlock.needsCalls;
      if (left > Duration.zero) return FailBlock.waitRunning;
      return null;
    case FailReason.other:
      return note.trim().isEmpty ? FailBlock.noteRequired : null;
    case FailReason.refused:
    case FailReason.wrongAddress:
      return null;
  }
}
