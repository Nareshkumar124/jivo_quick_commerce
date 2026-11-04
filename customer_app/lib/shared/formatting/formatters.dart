import 'package:intl/intl.dart';

/// Display locale for currency and dates (`09 §6`).
const kDisplayLocale = 'en_IN';

const _istOffset = Duration(hours: 5, minutes: 30);
final _moneyPattern = RegExp(r'^(-)?(\d+)(?:\.(\d{1,2}))?$');

/// Formats an API money string (a decimal string such as `"249.00"`,
/// `02 §5`) for display, following `03 §4`: always ₹, and no decimals unless
/// the paise are non-zero.
///
/// `"249.00"` → `₹249`, `"249.50"` → `₹249.50`, `"100000.00"` → `₹1,00,000`,
/// `"-20.00"` → `-₹20`.
///
/// The amount is parsed as integers, never as a double. Display only: never
/// compute totals in the app. Throws [FormatException] for anything that is
/// not a decimal string with at most two decimal places.
String formatRupees(String amount) {
  final match = _moneyPattern.firstMatch(amount.trim());
  if (match == null) {
    throw FormatException('Not a money amount', amount);
  }
  final rupees = int.parse(match.group(2)!);
  final paise = int.parse((match.group(3) ?? '0').padRight(2, '0'));
  final isNegative = match.group(1) != null && (rupees != 0 || paise != 0);

  final grouped = NumberFormat.decimalPattern(kDisplayLocale).format(rupees);
  final fraction = paise == 0 ? '' : '.${paise.toString().padLeft(2, '0')}';
  return '${isNegative ? '-' : ''}₹$grouped$fraction';
}

/// Whether an API money string is zero (`"0.00"`, `"0"`), e.g. to hide
/// "You save ₹0". A check on the server's value, not arithmetic.
bool isZeroAmount(String amount) {
  final match = _moneyPattern.firstMatch(amount.trim());
  if (match == null) return false;
  return int.parse(match.group(2)!) == 0 &&
      int.parse((match.group(3) ?? '0').padRight(2, '0')) == 0;
}

/// Whether two API money strings are the same amount (`"20"` and
/// `"20.00"`), e.g. to mark the selected tip chip. A comparison of the
/// server's values, not arithmetic. False when either is malformed.
bool isSameAmount(String a, String b) {
  final left = _moneyPattern.firstMatch(a.trim());
  final right = _moneyPattern.firstMatch(b.trim());
  if (left == null || right == null) return false;
  String normalised(RegExpMatch m) =>
      '${m.group(1) ?? ''}${int.parse(m.group(2)!)}.'
      '${(m.group(3) ?? '0').padRight(2, '0')}';
  return normalised(left) == normalised(right);
}

/// The IST wall-clock time of [instant], for formatting only. The API sends
/// UTC (`02 §5`); India has no daylight saving, so a fixed offset is exact.
DateTime toIst(DateTime instant) => instant.toUtc().add(_istOffset);

/// `2 Nov 2026`, in IST.
String formatDate(DateTime instant) =>
    DateFormat('d MMM yyyy', kDisplayLocale).format(toIst(instant));

/// `3:45 pm`, in IST.
String formatTime(DateTime instant) =>
    DateFormat('h:mm a', kDisplayLocale).format(toIst(instant));

/// `2 Nov 2026, 3:45 pm`, in IST.
String formatDateTime(DateTime instant) =>
    '${formatDate(instant)}, ${formatTime(instant)}';
