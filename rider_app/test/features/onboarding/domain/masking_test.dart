import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/onboarding/domain/kyc_document.dart';
import 'package:rider_app/features/onboarding/domain/masking.dart';
import 'package:rider_app/features/onboarding/domain/onboarding_inputs.dart';

void main() {
  group('masking (09 §3.3, D-14)', () {
    test('Aadhaar in the UIDAI style', () {
      expect(Masking.aadhaar('234567890124'), 'XXXX XXXX 0124');
      expect(Masking.aadhaar('2345 6789 0124'), 'XXXX XXXX 0124');
    });

    test('everything except the last 4, spaces and dashes removed', () {
      expect(Masking.trailing('ABCDE1234F'), 'XXXXXX234F');
      expect(Masking.trailing('DL-0420110149646'), 'XXXXXXXXXXX9646');
      expect(Masking.accountNumber('123456789012'), 'XXXXXXXX9012');
    });

    test('short values are fully masked, never shown', () {
      expect(Masking.trailing('1234'), 'XXXX');
      expect(Masking.trailing('12'), 'XX');
      expect(Masking.trailing(''), '');
    });

    test('request objects never print full numbers (logs, Sentry)', () {
      const bank = BankAccountInput(
        holderName: 'Ravi Kumar',
        accountNumber: '123456789012',
        ifsc: 'HDFC0001234',
      );
      expect(bank.toString(), isNot(contains('123456789012')));
      expect(bank.toString(), contains('XXXXXXXX9012'));

      final upload = DocumentUpload(
        type: KycDocumentType.aadhaarFront,
        image: Uint8List(10),
        number: '234567890124',
      );
      expect(upload.toString(), isNot(contains('234567890124')));
      expect(upload.toString(), isNot(contains('56789')));
      expect(upload.fileName, 'aadhaar_front.jpg');
    });
  });
}
