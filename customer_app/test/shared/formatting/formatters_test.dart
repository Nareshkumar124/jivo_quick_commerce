import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/shared/formatting/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart' show formatRupeeAmount;

void main() {
  setUpAll(initializeFormatting);

  group('formatRupees', () {
    test('drops zero paise', () {
      expect(formatRupees('249.00'), '₹249');
      expect(formatRupees('0.00'), '₹0');
      expect(formatRupees('249'), '₹249');
    });

    test('keeps non-zero paise with two digits', () {
      expect(formatRupees('249.50'), '₹249.50');
      expect(formatRupees('249.5'), '₹249.50');
      expect(formatRupees('0.05'), '₹0.05');
    });

    test('uses Indian digit grouping', () {
      expect(formatRupees('1000.00'), '₹1,000');
      expect(formatRupees('100000.00'), '₹1,00,000');
      expect(formatRupees('12345678.90'), '₹1,23,45,678.90');
    });

    test('negative amounts (discounts) put the sign before ₹', () {
      expect(formatRupees('-20.00'), '-₹20');
      expect(formatRupees('-0.00'), '₹0');
    });

    test('rejects anything that is not a decimal money string', () {
      for (final bad in ['', 'abc', '1.234', '₹20', '1,000.00', '12.']) {
        expect(() => formatRupees(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('IST date formatting', () {
    // 2026-11-02T10:15:00Z is 15:45 in IST.
    final instant = DateTime.utc(2026, 11, 2, 10, 15);

    test('converts UTC to IST', () {
      final ist = toIst(instant);
      expect((ist.hour, ist.minute), (15, 45));
    });

    test('formats date, time and both', () {
      expect(formatDate(instant), '2 Nov 2026');
      expect(formatTime(instant).toLowerCase(), '3:45 pm');
      expect(formatDateTime(instant).toLowerCase(), '2 nov 2026, 3:45 pm');
    });

    test('rolls over to the next IST day', () {
      expect(formatDate(DateTime.utc(2026, 11, 2, 20, 0)), '3 Nov 2026');
    });

    test('a local DateTime is treated as the instant it represents', () {
      final local = instant.toLocal();
      expect(formatTime(local), formatTime(instant));
    });
  });

  test('isSameAmount compares the server strings, not floats', () {
    expect(isSameAmount('20', '20.00'), isTrue);
    expect(isSameAmount('20.5', '20.50'), isTrue);
    expect(isSameAmount('20.00', '20.01'), isFalse);
    expect(isSameAmount('020.00', '20.00'), isTrue);
    expect(isSameAmount('abc', '20.00'), isFalse);
  });

  test('formatRupeesOrNull: jivo_core formatting, null when unusable', () {
    expect(formatRupeesOrNull('124999.00'), '₹1,24,999');
    expect(formatRupeesOrNull('249.50'), '₹249.50');
    expect(formatRupeesOrNull(null), isNull);
    expect(formatRupeesOrNull('12.345'), isNull);
    expect(formatRupees('124999.00'), formatRupeeAmount('124999.00'));
  });
}
