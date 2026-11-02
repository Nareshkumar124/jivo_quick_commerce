import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/onboarding/domain/kyc_document.dart';
import 'package:rider_app/features/onboarding/domain/validators.dart';
import 'package:rider_app/features/onboarding/domain/vehicle_type.dart';

/// Passes the Verhoeff check (UIDAI format); not a real Aadhaar.
const validAadhaar = '234567890124';

void main() {
  group('date of birth: 18 or older on the IST date', () {
    final today = DateTime.utc(2026, 11, 2);

    test('exactly 18 today passes; one day short fails', () {
      expect(
        validateDateOfBirth(DateTime.utc(2008, 11, 2), today: today),
        isNull,
      );
      expect(
        validateDateOfBirth(DateTime.utc(2008, 11, 3), today: today),
        FieldError.dobUnderage,
      );
      expect(
        validateDateOfBirth(DateTime.utc(1990, 1, 1), today: today),
        isNull,
      );
    });

    test('missing and future dates', () {
      expect(validateDateOfBirth(null, today: today), FieldError.required);
      expect(
        validateDateOfBirth(DateTime.utc(2026, 11, 3), today: today),
        FieldError.dobInFuture,
      );
      expect(
        validateDateOfBirth(DateTime.utc(2026, 11, 2), today: today),
        FieldError.dobUnderage,
      );
    });

    test('the time of day and zone of the picked date do not matter', () {
      expect(
        validateDateOfBirth(DateTime(2008, 11, 2, 23, 59), today: today),
        isNull,
      );
    });

    test('29 February birthdays turn 18 on 1 March in other years', () {
      final dob = DateTime.utc(2008, 2, 29);
      expect(
        validateDateOfBirth(dob, today: DateTime.utc(2026, 2, 28)),
        FieldError.dobUnderage,
      );
      expect(validateDateOfBirth(dob, today: DateTime.utc(2026, 3, 1)), isNull);
    });

    test('istToday uses the Indian date, not the phone zone', () {
      // 19:00 UTC on 1 Nov is 00:30 IST on 2 Nov.
      expect(
        istToday(DateTime.utc(2026, 11, 1, 19)),
        DateTime.utc(2026, 11, 2),
      );
      expect(
        istToday(DateTime.utc(2026, 11, 1, 18, 29)),
        DateTime.utc(2026, 11, 1),
      );
    });

    test('latestAllowedDateOfBirth is the date picker limit', () {
      expect(
        latestAllowedDateOfBirth(DateTime.utc(2026, 11, 2)),
        DateTime.utc(2008, 11, 2),
      );
      // 29 Feb 2028; 2010 has no 29 Feb, so the last day of February.
      final leapDay = DateTime.utc(2028, 2, 29);
      final latest = latestAllowedDateOfBirth(leapDay);
      expect(latest, DateTime.utc(2010, 2, 28));
      expect(validateDateOfBirth(latest, today: leapDay), isNull);
      expect(
        validateDateOfBirth(
          latest.add(const Duration(days: 1)),
          today: leapDay,
        ),
        FieldError.dobUnderage,
      );
    });
  });

  group('vehicle rules', () {
    test('only motorbikes and scooters are motorised', () {
      expect(VehicleType.bicycle.isMotorised, isFalse);
      expect(VehicleType.eBike.isMotorised, isFalse);
      expect(VehicleType.motorbike.isMotorised, isTrue);
      expect(VehicleType.scooter.isMotorised, isTrue);
    });

    test('vehicle number: required for motorised only, ignored otherwise', () {
      for (final type in [VehicleType.bicycle, VehicleType.eBike, null]) {
        expect(validateVehicleNumber('', vehicle: type), isNull);
        expect(validateVehicleNumber('junk', vehicle: type), isNull);
      }
      for (final type in [VehicleType.motorbike, VehicleType.scooter]) {
        expect(validateVehicleNumber('', vehicle: type), FieldError.required);
        expect(validateVehicleNumber('  ', vehicle: type), FieldError.required);
        expect(
          validateVehicleNumber('DL3', vehicle: type),
          FieldError.vehicleNumberInvalid,
        );
        expect(validateVehicleNumber('DL 3C AB 1234', vehicle: type), isNull);
      }
    });

    test('vehicle number formats: state series and BH series', () {
      for (final valid in [
        'DL3CAB1234',
        'dl 3c ab 1234',
        'MH12AB1234',
        'KA01A1234',
        'DL1CA1234',
        'UP16-BT-0001',
        '22BH1234AB',
      ]) {
        expect(isValidVehicleNumber(valid), isTrue, reason: valid);
      }
      for (final invalid in ['', '1234', 'DL', 'DLAB1234', 'DL3CAB12345X']) {
        expect(isValidVehicleNumber(invalid), isFalse, reason: invalid);
      }
      expect(normaliseRegistrationNumber('dl 3c-ab 1234'), 'DL3CAB1234');
    });

    test('DL and RC are required for motorised vehicles only', () {
      const base = [
        KycDocumentType.photo,
        KycDocumentType.aadhaarFront,
        KycDocumentType.aadhaarBack,
        KycDocumentType.pan,
      ];
      expect(requiredDocumentsFor(VehicleType.bicycle), base);
      expect(requiredDocumentsFor(VehicleType.eBike), base);
      expect(requiredDocumentsFor(VehicleType.motorbike), [
        ...base,
        KycDocumentType.drivingLicence,
        KycDocumentType.vehicleRc,
      ]);
      expect(requiredDocumentsFor(VehicleType.scooter), hasLength(6));
    });
  });

  group('bank details', () {
    test('IFSC: 4 letters, 0, 6 letters or digits', () {
      for (final valid in ['HDFC0001234', 'hdfc0001234', 'SBIN0ABC123']) {
        expect(validateIfsc(valid), isNull, reason: valid);
      }
      expect(validateIfsc(''), FieldError.required);
      for (final invalid in [
        'HDFC1001234', // fifth character must be 0
        'HDF00001234', // 3 letters
        'HDFC000123', // 10 characters
        'HDFC00012345', // 12 characters
        'HDFC0-01234',
      ]) {
        expect(validateIfsc(invalid), FieldError.ifscInvalid, reason: invalid);
      }
      expect(normaliseIfsc(' hdfc0001234 '), 'HDFC0001234');
    });

    test('account number: 9 to 18 digits', () {
      expect(validateAccountNumber(''), FieldError.required);
      expect(
        validateAccountNumber('12345678'),
        FieldError.accountNumberInvalid,
      );
      expect(validateAccountNumber('123456789'), isNull);
      expect(validateAccountNumber('123456789012345678'), isNull);
      expect(
        validateAccountNumber('1234567890123456789'),
        FieldError.accountNumberInvalid,
      );
      expect(
        validateAccountNumber('12345A789'),
        FieldError.accountNumberInvalid,
      );
    });

    test('confirm must repeat the account number exactly', () {
      expect(
        validateAccountConfirmation('123456789012', ''),
        FieldError.required,
      );
      expect(
        validateAccountConfirmation('123456789012', '123456789013'),
        FieldError.accountNumbersMismatch,
      );
      expect(
        validateAccountConfirmation('123456789012', '12345678901'),
        FieldError.accountNumbersMismatch,
      );
      expect(
        validateAccountConfirmation('123456789012', '123456789012'),
        isNull,
      );
    });

    test('UPI ID is optional but must look like name@handle', () {
      expect(validateUpiId(''), isNull);
      expect(validateUpiId('   '), isNull);
      expect(validateUpiId('ravi.kumar@okhdfcbank'), isNull);
      expect(validateUpiId('9876543210@ybl'), isNull);
      for (final invalid in ['ravi', 'ravi@', '@ybl', 'ravi@@ybl', 'r@y']) {
        expect(validateUpiId(invalid), FieldError.upiInvalid, reason: invalid);
      }
    });
  });

  group('document numbers', () {
    test('Aadhaar: 12 digits, not starting 0/1, Verhoeff check digit', () {
      expect(isValidAadhaar(validAadhaar), isTrue);
      expect(isValidAadhaar('2345 6789 0124'), isTrue);
      expect(isValidAadhaar('234567890120'), isFalse, reason: 'check digit');
      expect(isValidAadhaar('134567890124'), isFalse, reason: 'starts with 1');
      expect(isValidAadhaar('23456789012'), isFalse, reason: '11 digits');
      expect(
        validateDocumentNumber(KycDocumentType.aadhaarFront, '234567890120'),
        FieldError.aadhaarInvalid,
      );
      expect(
        validateDocumentNumber(KycDocumentType.aadhaarFront, validAadhaar),
        isNull,
      );
    });

    test('PAN, DL and RC formats', () {
      expect(validateDocumentNumber(KycDocumentType.pan, 'abcde1234f'), isNull);
      expect(
        validateDocumentNumber(KycDocumentType.pan, 'ABCD1234F'),
        FieldError.panInvalid,
      );
      expect(
        validateDocumentNumber(
          KycDocumentType.drivingLicence,
          'DL-0420110149646',
        ),
        isNull,
      );
      expect(
        validateDocumentNumber(KycDocumentType.drivingLicence, '1234567'),
        FieldError.drivingLicenceInvalid,
      );
      expect(
        validateDocumentNumber(KycDocumentType.vehicleRc, 'DL3CAB1234'),
        isNull,
      );
      expect(
        validateDocumentNumber(KycDocumentType.vehicleRc, 'DL3'),
        FieldError.vehicleNumberInvalid,
      );
    });

    test('a number is required only where the document has one', () {
      expect(
        validateDocumentNumber(KycDocumentType.pan, ''),
        FieldError.required,
      );
      expect(validateDocumentNumber(KycDocumentType.photo, ''), isNull);
      expect(validateDocumentNumber(KycDocumentType.aadhaarBack, ''), isNull);
    });
  });

  group('people', () {
    test('names: letters in any script, 2 to 120 characters', () {
      expect(validatePersonName('Ravi Kumar'), isNull);
      expect(validatePersonName("  D'Souza  Anil-Kumar Jr. "), isNull);
      expect(validatePersonName('रवि कुमार'), isNull);
      expect(validatePersonName(''), FieldError.required);
      expect(validatePersonName('R'), FieldError.nameInvalid);
      expect(validatePersonName('Ravi2'), FieldError.nameInvalid);
      expect(validatePersonName('R' * 121), FieldError.nameInvalid);
      expect(normaliseName('  Ravi   Kumar '), 'Ravi Kumar');
    });

    test('emergency contact: a valid mobile that is not the rider', () {
      expect(validateEmergencyPhone(''), FieldError.required);
      expect(validateEmergencyPhone('98765'), FieldError.phoneIncomplete);
      expect(validateEmergencyPhone('5876543210'), FieldError.phoneInvalid);
      expect(validateEmergencyPhone('9876543210'), isNull);
      expect(
        validateEmergencyPhone('9876543210', riderPhoneE164: '+919876543210'),
        FieldError.phoneSameAsRider,
      );
      expect(
        validateEmergencyPhone('9876543211', riderPhoneE164: '+919876543210'),
        isNull,
      );
    });
  });
}
