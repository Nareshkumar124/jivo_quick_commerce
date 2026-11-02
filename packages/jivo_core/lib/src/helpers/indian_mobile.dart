/// Why a typed phone number is not usable.
enum PhoneInputError { empty, incomplete, invalid }

/// Indian mobile numbers as the API expects them: `+91` and 10 digits
/// starting with 6–9 (schema pattern `^\+91[6-9]\d{9}$`).
abstract final class IndianMobile {
  static final _e164 = RegExp(r'^\+91[6-9]\d{9}$');
  static final _national = RegExp(r'^[6-9]\d{9}$');
  static final _nonDigits = RegExp(r'\D');

  /// Whether [phone] matches the schema pattern exactly.
  static bool isValidE164(String phone) => _e164.hasMatch(phone);

  /// Whether [digits] is exactly 10 national digits starting with 6–9.
  static bool isValidNational(String digits) => _national.hasMatch(digits);

  /// The 10 national digits from what the user typed or pasted. Accepts a
  /// leading `+91`, `91` or `0`, spaces and dashes.
  static String nationalDigits(String input) {
    var digits = input.replaceAll(_nonDigits, '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Null when [input] is a valid mobile number, otherwise the reason.
  static PhoneInputError? validate(String input) {
    final digits = nationalDigits(input);
    if (digits.isEmpty) return PhoneInputError.empty;
    if (digits.length < 10) return PhoneInputError.incomplete;
    if (!isValidNational(digits)) return PhoneInputError.invalid;
    return null;
  }

  /// `+91XXXXXXXXXX`, or null when [input] is not a valid mobile number.
  static String? toE164(String input) {
    if (validate(input) != null) return null;
    return '+91${nationalDigits(input)}';
  }

  /// `+91 98765 43210`, for display. Anything that is not a valid E.164
  /// Indian mobile number is returned unchanged.
  static String format(String e164) {
    if (!isValidE164(e164)) return e164;
    final d = e164.substring(3);
    return '+91 ${d.substring(0, 5)} ${d.substring(5)}';
  }
}
