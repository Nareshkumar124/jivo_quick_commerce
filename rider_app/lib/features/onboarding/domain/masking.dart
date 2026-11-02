/// Masking for KYC document and bank account numbers (09 §3.3, D-14).
///
/// The app shows only masked numbers. The full number lives only in the text
/// field while the rider types it and in the upload request; it is never
/// logged, sent to analytics or kept in app state after the upload.
abstract final class Masking {
  static const maskChar = 'X';

  /// Every character except the last [visible] replaced with `X`, with
  /// spaces and dashes removed: `XXXXXXXX1234`. Values no longer than
  /// [visible] are fully masked, so a short value is never shown in full.
  static String trailing(String value, {int visible = 4}) {
    final compact = value.replaceAll(RegExp(r'[\s-]'), '');
    if (compact.isEmpty) return '';
    if (compact.length <= visible) return maskChar * compact.length;
    return maskChar * (compact.length - visible) +
        compact.substring(compact.length - visible);
  }

  /// Aadhaar in the UIDAI masked style: `XXXX XXXX 1234`.
  static String aadhaar(String value) {
    final masked = trailing(value);
    final groups = <String>[];
    for (var i = 0; i < masked.length; i += 4) {
      groups.add(masked.substring(i, (i + 4).clamp(0, masked.length)));
    }
    return groups.join(' ');
  }

  /// Bank account number: `XXXXXXXX1234`.
  static String accountNumber(String value) => trailing(value);
}
