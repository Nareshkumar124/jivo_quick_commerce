import 'package:intl/intl.dart';

final _amountPattern = RegExp(r'^(-)?(\d{1,15})(?:\.(\d{1,2}))?$');

/// Formats a server money amount (a 2-decimal string such as `"249.00"`,
/// `02 §5`) for display in `en_IN`, following `03 §4`: always ₹, no
/// decimals unless the paise are non-zero, Indian (lakh) digit grouping.
///
/// `"249.00"` → `₹249`, `"249.50"` → `₹249.50`, `"124999.00"` →
/// `₹1,24,999`, `"-20.00"` → `-₹20`.
///
/// Returns null for a null, empty or unparseable input (more than two
/// decimals, a sign other than `-`, grouping commas, exponents, …), so the
/// caller can hide the amount and block the action that depends on it.
///
/// Display only: the string is split into whole rupees and paise as
/// integers (never a `double`) and nothing is computed. Totals always come
/// from the server.
String? formatRupeeAmount(String? amount) {
  if (amount == null) return null;
  final match = _amountPattern.firstMatch(amount.trim());
  if (match == null) return null;
  final rupees = int.parse(match.group(2)!);
  final paise = int.parse((match.group(3) ?? '0').padRight(2, '0'));
  final negative = match.group(1) != null && (rupees != 0 || paise != 0);
  final grouped = NumberFormat.decimalPattern('en_IN').format(rupees);
  final fraction = paise == 0 ? '' : '.${paise.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}₹$grouped$fraction';
}
