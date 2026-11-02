import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:rider_app/features/onboarding/domain/kyc_document.dart';
import 'package:rider_app/features/onboarding/domain/onboarding_forms.dart';
import 'package:rider_app/features/onboarding/domain/rider_profile.dart';
import 'package:rider_app/features/onboarding/domain/validators.dart';
import 'package:rider_app/features/onboarding/domain/vehicle_type.dart';

final today = DateTime.utc(2026, 11, 2);

RegistrationDraft draft({
  VehicleType? vehicle = VehicleType.bicycle,
  String vehicleNumber = '',
  DateTime? dob,
  String emergencyPhone = '98765 00001',
}) => RegistrationDraft(
  fullName: ' Ravi  Kumar ',
  dateOfBirth: dob ?? DateTime.utc(1995, 6, 15),
  emergencyName: 'Sunita Kumar',
  emergencyPhone: emergencyPhone,
  storeId: 2,
  vehicleType: vehicle,
  vehicleNumber: vehicleNumber,
);

RiderProfile profile({
  RiderStatusEnum status = RiderStatusEnum.PENDING_KYC,
  VehicleType vehicle = VehicleType.bicycle,
  List<RiderDocument> documents = const [],
  BankAccountSummary? bank,
}) => RiderProfile(
  status: status,
  fullName: 'Ravi Kumar',
  dateOfBirth: DateTime.utc(1995, 6, 15),
  emergencyContactName: 'Sunita Kumar',
  emergencyContactPhone: '+919876500001',
  preferredStore: const StoreOption(
    id: 1,
    name: 'Jivo Sector 18',
    city: 'Noida',
  ),
  vehicleType: vehicle,
  documents: documents,
  bankAccount: bank,
);

RiderDocument doc(
  KycDocumentType type, [
  DocumentReviewStatus status = DocumentReviewStatus.pending,
]) => RiderDocument(type: type, status: status);

const bank = BankAccountSummary(
  holderName: 'Ravi Kumar',
  accountNumberMasked: 'XXXXXXXX9012',
  ifsc: 'HDFC0001234',
);

void main() {
  group('RegistrationDraft', () {
    test('an empty form reports every required field', () {
      final errors = const RegistrationDraft().validate(today: today);
      expect(errors, {
        RegistrationField.fullName: FieldError.required,
        RegistrationField.dateOfBirth: FieldError.required,
        RegistrationField.emergencyName: FieldError.required,
        RegistrationField.emergencyPhone: FieldError.required,
        RegistrationField.store: FieldError.required,
        RegistrationField.vehicleType: FieldError.required,
      });
    });

    test('a bicycle needs no vehicle number; it is dropped from the '
        'request', () {
      final form = draft(vehicleNumber: 'DL3CAB1234');
      expect(form.validate(today: today), isEmpty);
      final registration = form.toRegistration();
      expect(registration.vehicleNumber, isNull);
      expect(registration.fullName, 'Ravi Kumar');
      expect(registration.emergencyContactPhone, '+919876500001');
      expect(registration.dateOfBirth, DateTime.utc(1995, 6, 15));
      expect(registration.preferredStoreId, 2);
    });

    test('a motorbike needs a valid vehicle number, normalised', () {
      expect(draft(vehicle: VehicleType.motorbike).validate(today: today), {
        RegistrationField.vehicleNumber: FieldError.required,
      });
      expect(
        draft(
          vehicle: VehicleType.scooter,
          vehicleNumber: 'DL3',
        ).validate(today: today),
        {RegistrationField.vehicleNumber: FieldError.vehicleNumberInvalid},
      );
      final form = draft(
        vehicle: VehicleType.motorbike,
        vehicleNumber: 'dl 3c ab 1234',
      );
      expect(form.validate(today: today), isEmpty);
      expect(form.toRegistration().vehicleNumber, 'DL3CAB1234');
    });

    test('under 18 and own phone as emergency contact', () {
      final errors = draft(
        dob: DateTime.utc(2008, 11, 3),
        emergencyPhone: '9811122235',
      ).validate(today: today, riderPhoneE164: '+919811122235');
      expect(errors, {
        RegistrationField.dateOfBirth: FieldError.dobUnderage,
        RegistrationField.emergencyPhone: FieldError.phoneSameAsRider,
      });
    });
  });

  group('BankAccountDraft', () {
    const valid = BankAccountDraft(
      holderName: 'Ravi Kumar',
      accountNumber: '123456789012',
      confirmAccountNumber: '123456789012',
      ifsc: 'hdfc0001234',
      upiId: ' ravi@okhdfcbank ',
    );

    test('valid details make the request (IFSC upper-cased, UPI trimmed)', () {
      expect(valid.validate(), isEmpty);
      final input = valid.toInput();
      expect(input.accountNumber, '123456789012');
      expect(input.ifsc, 'HDFC0001234');
      expect(input.upiId, 'ravi@okhdfcbank');
      expect(
        const BankAccountDraft(
          holderName: 'Ravi Kumar',
          accountNumber: '123456789012',
          confirmAccountNumber: '123456789012',
          ifsc: 'HDFC0001234',
        ).toInput().upiId,
        isNull,
      );
    });

    test('mismatch, bad IFSC and bad UPI are reported per field', () {
      const form = BankAccountDraft(
        holderName: 'Ravi Kumar',
        accountNumber: '123456789012',
        confirmAccountNumber: '123456789013',
        ifsc: 'HDFC1001234',
        upiId: 'ravi',
      );
      expect(form.validate(), {
        BankField.confirmAccountNumber: FieldError.accountNumbersMismatch,
        BankField.ifsc: FieldError.ifscInvalid,
        BankField.upiId: FieldError.upiInvalid,
      });
    });

    test('toString never prints the account number', () {
      expect(valid.toString(), isNot(contains('123456789012')));
    });
  });

  group('RiderProfile.stage (approval status screen)', () {
    final allBicycleDocs = [
      for (final t in requiredDocumentsFor(VehicleType.bicycle)) doc(t),
    ];

    test('PENDING_KYC: documents, then bank, then in review', () {
      expect(profile().stage, OnboardingStage.needsDocuments);
      expect(profile().documentsDone, 0);
      expect(profile().missingDocuments, hasLength(4));

      expect(
        profile(documents: allBicycleDocs).stage,
        OnboardingStage.needsBankAccount,
      );
      expect(
        profile(documents: allBicycleDocs, bank: bank).stage,
        OnboardingStage.inReview,
      );
    });

    test('a rejected document sends the rider back to documents', () {
      final docs = [
        ...allBicycleDocs.where((d) => d.type != KycDocumentType.pan),
        doc(KycDocumentType.pan, DocumentReviewStatus.rejected),
      ];
      final p = profile(documents: docs, bank: bank);
      expect(p.stage, OnboardingStage.needsDocuments);
      expect(p.rejectedDocuments.single.type, KycDocumentType.pan);
      expect(p.documentsDone, 3);
      expect(p.documentsComplete, isFalse);
    });

    test('a motorbike also needs DL and RC', () {
      final p = profile(
        vehicle: VehicleType.motorbike,
        documents: allBicycleDocs,
        bank: bank,
      );
      expect(p.stage, OnboardingStage.needsDocuments);
      expect(p.missingDocuments, [
        KycDocumentType.drivingLicence,
        KycDocumentType.vehicleRc,
      ]);
    });

    test('REJECTED, ACTIVE, SUSPENDED and unknown statuses', () {
      expect(
        profile(status: RiderStatusEnum.REJECTED).stage,
        OnboardingStage.rejected,
      );
      expect(
        profile(status: RiderStatusEnum.ACTIVE).stage,
        OnboardingStage.approved,
      );
      expect(
        profile(status: RiderStatusEnum.SUSPENDED).stage,
        OnboardingStage.suspended,
      );
      expect(
        profile(status: RiderStatusEnum.unknownDefaultOpenApi).stage,
        OnboardingStage.unknown,
      );
    });

    test('approved documents cannot be replaced', () {
      expect(doc(KycDocumentType.pan).canReplace, isTrue);
      expect(
        doc(KycDocumentType.pan, DocumentReviewStatus.rejected).canReplace,
        isTrue,
      );
      expect(
        doc(KycDocumentType.pan, DocumentReviewStatus.approved).canReplace,
        isFalse,
      );
    });
  });
}
