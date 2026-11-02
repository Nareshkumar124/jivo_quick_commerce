import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:rider_app/features/onboarding/data/fake_rider_onboarding_backend.dart';
import 'package:rider_app/features/onboarding/domain/kyc_document.dart';
import 'package:rider_app/features/onboarding/domain/rider_profile.dart';
import 'package:rider_app/features/onboarding/domain/vehicle_type.dart';

/// FakeAuthBackend test numbers (last digit decides `rider_status`).
const pendingPhone = '+919811122232';
const rejectedPhone = '+919811122233';
const suspendedPhone = '+919811122234';
const nonePhone = '+919811122235';

const bankSummary = BankAccountSummary(
  holderName: 'Ravi Kumar',
  accountNumberMasked: 'XXXXXXXX9012',
  ifsc: 'HDFC0001234',
);

/// A `PENDING_KYC` profile. Default: bicycle, nothing uploaded, no bank.
RiderProfile pendingProfile({
  VehicleType vehicle = VehicleType.bicycle,
  Map<KycDocumentType, DocumentReviewStatus> documents = const {},
  BankAccountSummary? bank,
}) => RiderProfile(
  status: RiderStatusEnum.PENDING_KYC,
  fullName: 'Ravi Kumar',
  dateOfBirth: DateTime.utc(1995, 6, 15),
  emergencyContactName: 'Sunita Kumar',
  emergencyContactPhone: '+919876500001',
  preferredStore: FakeRiderOnboardingBackend.stores.first,
  vehicleType: vehicle,
  vehicleNumber: vehicle.isMotorised ? 'DL3CAB1234' : null,
  documents: [
    for (final MapEntry(key: type, value: status) in documents.entries)
      RiderDocument(type: type, status: status),
  ],
  bankAccount: bank,
);

/// Every required bicycle document, in review.
const allBicycleDocuments = {
  KycDocumentType.photo: DocumentReviewStatus.pending,
  KycDocumentType.aadhaarFront: DocumentReviewStatus.pending,
  KycDocumentType.aadhaarBack: DocumentReviewStatus.pending,
  KycDocumentType.pan: DocumentReviewStatus.pending,
};

/// Scrolls the list with [listKey] until [finder] is built and visible.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  required Key listKey,
}) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find
        .descendant(of: find.byKey(listKey), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}
