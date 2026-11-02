import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/helpers.dart';

void main() {
  group('IndianMobile', () {
    test('accepts 10 digits starting with 6-9, with or without a prefix', () {
      for (final input in [
        '9876543210',
        '+919876543210',
        '919876543210',
        '09876543210',
        '+91 98765-43210',
        ' 6000000000 ',
      ]) {
        expect(IndianMobile.validate(input), isNull, reason: input);
      }
      expect(IndianMobile.toE164('+91 98765 43210'), '+919876543210');
      expect(IndianMobile.toE164('098765 43210'), '+919876543210');
    });

    test('reports why a number is unusable', () {
      expect(IndianMobile.validate(''), PhoneInputError.empty);
      expect(IndianMobile.validate('abc'), PhoneInputError.empty);
      expect(IndianMobile.validate('98765'), PhoneInputError.incomplete);
      expect(IndianMobile.validate('5876543210'), PhoneInputError.invalid);
      expect(IndianMobile.validate('98765432101'), PhoneInputError.invalid);
      expect(IndianMobile.toE164('5876543210'), isNull);
    });

    test('nationalDigits strips only a real prefix', () {
      expect(IndianMobile.nationalDigits('+91-98765-43210'), '9876543210');
      expect(IndianMobile.nationalDigits('919876543210'), '9876543210');
      expect(IndianMobile.nationalDigits('09876543210'), '9876543210');
      // 10 digits starting with 91 are a national number, not a prefix.
      expect(IndianMobile.nationalDigits('9198765432'), '9198765432');
    });

    test('matches the schema pattern and formats for display', () {
      expect(IndianMobile.isValidE164('+919876543210'), isTrue);
      expect(IndianMobile.isValidE164('+915876543210'), isFalse);
      expect(IndianMobile.isValidE164('9876543210'), isFalse);
      expect(IndianMobile.isValidNational('9876543210'), isTrue);
      expect(IndianMobile.isValidNational('987654321'), isFalse);
      expect(IndianMobile.format('+919876543210'), '+91 98765 43210');
      expect(IndianMobile.format('12345'), '12345');
    });
  });

  test('noAutomaticRetry never schedules a retry', () {
    expect(noAutomaticRetry(0, Exception('x')), isNull);
    expect(noAutomaticRetry(5, StateError('x')), isNull);
  });

  test(
    'FakeUrlOpener records URLs and returns the configured result',
    () async {
      final opener = FakeUrlOpener();
      expect(await opener.open(Uri.parse('https://jivo.in')), isTrue);
      opener.result = false;
      expect(await opener.open(Uri.parse('tel:123')), isFalse);
      expect(opener.opened.map((u) => u.toString()), [
        'https://jivo.in',
        'tel:123',
      ]);
    },
  );

  test('OTP autofill doubles', () async {
    const none = NoOtpAutofill();
    expect(await none.listenForCode(), isNull);
    await none.stop();

    final fake = FakeOtpAutofill('123456');
    expect(await fake.listenForCode(), '123456');
    await fake.stop();
    fake.code = null;
    expect(await fake.listenForCode(), isNull);
    expect((fake.listens, fake.stops), (2, 1));
  });
}
