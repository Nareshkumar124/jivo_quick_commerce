import 'package:intl/intl.dart';

import 'rider_task.dart';

/// At most 15 rupee digits (far above any order), so `int.parse` can never
/// overflow on a malformed server value; longer is "not a money amount".
final _moneyPattern = RegExp(r'^(-)?(\d{1,15})(?:\.(\d{1,2}))?$');

/// Formats an API money string for display, with the customer app's rule
/// (03 §4, UX audit RD-02): ₹, `en_IN` grouping, and paise only when they
/// are not zero. `"249.00"` → `₹249`, `"249.50"` → `₹249.50`,
/// `"100000.00"` → `₹1,00,000`, `"-20.00"` → `-₹20`.
///
/// Parsed as integers, never as a double; display only, nothing is
/// computed. Returns null for a missing or malformed amount, so callers can
/// show "can't load the amount" instead of a bare "₹".
///
/// TODO(jivo_core): switch to the shared `en_IN` formatter the customer
/// agent is moving into jivo_core, once it merges. Same behaviour.
String? tryFormatRupees(String? amount) {
  if (amount == null) return null;
  final match = _moneyPattern.firstMatch(amount.trim());
  if (match == null) return null;
  final rupees = int.parse(match.group(2)!);
  final paise = int.parse((match.group(3) ?? '0').padRight(2, '0'));
  final negative = match.group(1) != null && (rupees != 0 || paise != 0);
  final grouped = NumberFormat.decimalPattern('en_IN').format(rupees);
  final fraction = paise == 0 ? '' : '.${paise.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}₹$grouped$fraction';
}

/// [tryFormatRupees] for amounts the API always sends (records, payouts).
/// A malformed value is shown as sent, never with a bare "₹".
String formatRupees(String amount) => tryFormatRupees(amount) ?? amount.trim();

/// Whether two API money strings are the same amount (`"20"` and
/// `"20.00"`). A comparison of server values for display, not arithmetic.
/// False when either is malformed.
bool isSameAmount(String a, String b) {
  final left = _moneyPattern.firstMatch(a.trim());
  final right = _moneyPattern.firstMatch(b.trim());
  if (left == null || right == null) return false;
  String normalised(RegExpMatch m) =>
      '${m.group(1) ?? ''}${int.parse(m.group(2)!)}.'
      '${(m.group(3) ?? '0').padRight(2, '0')}';
  return normalised(left) == normalised(right);
}

/// The COD amount to collect, formatted, or null when a COD task has no
/// usable amount: then no cash or UPI action may be offered (RD-02).
String? codAmountText(RiderTask task) =>
    task.isCod ? tryFormatRupees(task.codAmountDue) : null;

/// The amount offered before the store changed the order, formatted, when
/// it differs from the amount due now (RD-03); else null.
String? codAmountWasText(RiderTask task) {
  final was = task.codAmountChangedFrom;
  final now = task.codAmountDue;
  if (!task.isCod || was == null || now == null) return null;
  if (isSameAmount(was, now)) return null;
  return tryFormatRupees(was);
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
