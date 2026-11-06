import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

void main() {
  group('formatRupeeAmount', () {
    test('whole rupees have no decimals', () {
      expect(formatRupeeAmount('249.00'), '₹249');
      expect(formatRupeeAmount('249'), '₹249');
      expect(formatRupeeAmount('0.00'), '₹0');
    });

    test('non-zero paise keep two decimals', () {
      expect(formatRupeeAmount('249.50'), '₹249.50');
      expect(formatRupeeAmount('249.5'), '₹249.50');
      expect(formatRupeeAmount('0.05'), '₹0.05');
    });

    test('Indian lakh grouping', () {
      expect(formatRupeeAmount('124999.00'), '₹1,24,999');
      expect(formatRupeeAmount('100000.00'), '₹1,00,000');
      expect(formatRupeeAmount('12345678.90'), '₹1,23,45,678.90');
      expect(formatRupeeAmount('999.00'), '₹999');
      expect(formatRupeeAmount('1000.00'), '₹1,000');
    });

    test('negative amounts (discounts) and negative zero', () {
      expect(formatRupeeAmount('-20.00'), '-₹20');
      expect(formatRupeeAmount('-0.00'), '₹0');
    });

    test('surrounding whitespace is ignored', () {
      expect(formatRupeeAmount(' 49.00 '), '₹49');
    });

    test('null or unparseable input returns null', () {
      for (final bad in <String?>[
        null,
        '',
        ' ',
        'abc',
        '249.001',
        '1,249.00',
        '+20.00',
        '1e3',
        '.50',
        '20.',
        '₹20',
        'NaN',
        '12345678901234567.00',
      ]) {
        expect(formatRupeeAmount(bad), isNull, reason: '$bad');
      }
    });
  });
}
