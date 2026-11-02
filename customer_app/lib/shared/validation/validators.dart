/// Client-side checks that mirror the backend patterns, so users see
/// mistakes before a round trip. The server still validates everything.
abstract final class Validators {
  static final _mobile = RegExp(r'^[6-9]\d{9}$');
  static final _e164 = RegExp(r'^\+91[6-9]\d{9}$');
  static final _pincode = RegExp(r'^[1-9]\d{5}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// A 10-digit Indian mobile number without the country code.
  static bool isMobile(String digits) => _mobile.hasMatch(digits.trim());

  /// `+91XXXXXXXXXX`, the form the API uses.
  static bool isE164Mobile(String phone) => _e164.hasMatch(phone.trim());

  /// The API form of a 10-digit mobile number.
  static String toE164(String digits) => '+91${digits.trim()}';

  /// The 10 digits of a `+91…` number, or the input unchanged.
  static String localDigits(String phone) =>
      phone.startsWith('+91') ? phone.substring(3) : phone;

  static bool isPincode(String value) => _pincode.hasMatch(value.trim());

  static bool isEmail(String value) => _email.hasMatch(value.trim());
}
