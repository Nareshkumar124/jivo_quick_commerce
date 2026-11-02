import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/auth/domain/indian_mobile.dart';

void main() {
  group('IndianMobile', () {
    test('matches the schema pattern ^\\+91[6-9]\\d{9}\$', () {
      expect(IndianMobile.isValidE164('+919876543210'), isTrue);
      expect(IndianMobile.isValidE164('+916000000000'), isTrue);
      expect(IndianMobile.isValidE164('+915876543210'), isFalse);
      expect(IndianMobile.isValidE164('+91987654321'), isFalse);
      expect(IndianMobile.isValidE164('9876543210'), isFalse);
    });

    test('validate explains what is wrong', () {
      expect(IndianMobile.validate(''), PhoneInputError.empty);
      expect(IndianMobile.validate('98765'), PhoneInputError.incomplete);
      expect(IndianMobile.validate('5876543210'), PhoneInputError.invalid);
      expect(IndianMobile.validate('9876543210'), isNull);
    });

    test('accepts pasted +91, 91 and 0 prefixes, spaces and dashes', () {
      expect(IndianMobile.toE164('9876543210'), '+919876543210');
      expect(IndianMobile.toE164('+91 98765-43210'), '+919876543210');
      expect(IndianMobile.toE164('919876543210'), '+919876543210');
      expect(IndianMobile.toE164('09876543210'), '+919876543210');
      expect(IndianMobile.toE164('12345'), isNull);
    });

    test('formats for display', () {
      expect(IndianMobile.format('+919876543210'), '+91 98765 43210');
    });
  });
}
