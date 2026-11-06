import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/onboarding/data/api_rider_onboarding_repository.dart';
import 'package:rider_app/features/onboarding/domain/kyc_document.dart';
import 'package:rider_app/features/onboarding/domain/onboarding_inputs.dart';
import 'package:rider_app/features/onboarding/domain/vehicle_type.dart';

import '../../../helpers/canned_http.dart';

const _profile = {
  'id': 3,
  'phone': '+919811122231',
  'status': 'REJECTED',
  'rejection_reason': 'PAN photo is blurred.',
  'suspension_reason': '',
  'full_name': 'Ravi Kumar',
  'dob': '1998-04-02',
  'emergency_contact_name': 'Sita',
  'emergency_contact_phone': '+919811100000',
  'vehicle_type': 'MOTORBIKE',
  'vehicle_number': 'DL01AB1234',
  'preferred_store': {'id': 1, 'name': 'Sector 18', 'city': 'Noida'},
  'home_store': null,
  'photo_url': null,
  'photo_url_expires_at': null,
  'rating_avg': null,
  'documents': [
    {
      'doc_type': 'PAN',
      'status': 'REJECTED',
      'doc_number_masked': 'XXXXXX234F',
      'review_note': 'Blurred',
      'uploaded_at': '2026-11-03T10:00:00Z',
      'reviewed_at': '2026-11-03T12:00:00Z',
    },
  ],
  'required_documents': ['PHOTO', 'PAN'],
  'missing_documents': ['PHOTO'],
  'bank_account': {
    'holder_name': 'Ravi Kumar',
    'account_number_masked': 'XXXXXX7890',
    'ifsc': 'HDFC0001234',
    'upi_id': null,
    'updated_at': '2026-11-03T10:00:00Z',
  },
  'ready_for_review': false,
  'is_online': false,
  'cash': {
    'cash_in_hand': '0.00',
    'cash_limit': '5000.00',
    'limit_reached': false,
    'deposit_required': false,
  },
  'today': {
    'date': '2026-11-04',
    'orders_delivered': 0,
    'earnings': '0.00',
    'cash_in_hand': '0.00',
    'online_seconds': 0,
  },
  'created_at': '2026-11-01T10:00:00Z',
};

/// Registration and KYC bound to the P5 contract (slice 5.1).
void main() {
  late CannedAdapter http;
  late ApiRiderOnboardingRepository repo;

  setUp(() {
    http = CannedAdapter();
    repo = ApiRiderOnboardingRepository(cannedApi(http));
  });

  test('stores for the preferred-store dropdown', () async {
    http.answers['/api/v1/rider/stores/'] = const Canned(200, {
      'results': [
        {'id': 1, 'name': 'Sector 18', 'city': 'Noida'},
      ],
    });
    final stores = await repo.fetchStores();
    expect(stores.single.name, 'Sector 18');
  });

  test('register sends dob as a date (YYYY-MM-DD), not a datetime', () async {
    http.answers['/api/v1/rider/register/'] = const Canned(201, _profile);
    await repo.register(
      RiderRegistration(
        fullName: 'Ravi Kumar',
        dateOfBirth: DateTime(1998, 4, 2),
        emergencyContactName: 'Sita',
        emergencyContactPhone: '+919811100000',
        preferredStoreId: 1,
        vehicleType: VehicleType.motorbike,
        vehicleNumber: 'DL01AB1234',
      ),
    );
    final body = http.jsonBody('/api/v1/rider/register/');
    expect(body['dob'], '1998-04-02');
    expect(body['vehicle_type'], 'MOTORBIKE');
    expect(body['preferred_store_id'], 1);
  });

  test('GET /rider/me/ maps status, rejection, documents and bank', () async {
    http.answers['/api/v1/rider/me/'] = const Canned(200, _profile);
    final profile = await repo.fetchProfile();
    expect(profile.status, RiderStatusEnum.REJECTED);
    expect(profile.rejectionReason, 'PAN photo is blurred.');
    final pan = profile.documents.single;
    expect(pan.type, KycDocumentType.pan);
    expect(pan.status, DocumentReviewStatus.rejected);
    expect(pan.numberMasked, 'XXXXXX234F');
    expect(profile.bankAccount!.accountNumberMasked, 'XXXXXX7890');
    expect(profile.homeStore, isNull);
  });

  test(
    'a document is uploaded as multipart doc_type + file + number',
    () async {
      http.answers['/api/v1/rider/documents/'] = const Canned(201, {
        'doc_type': 'PAN',
        'status': 'PENDING',
        'doc_number_masked': 'XXXXXX234F',
        'review_note': '',
        'uploaded_at': '2026-11-04T10:00:00Z',
        'reviewed_at': null,
      });
      final doc = await repo.uploadDocument(
        DocumentUpload(
          type: KycDocumentType.pan,
          image: Uint8List.fromList([1, 2, 3]),
          number: 'ABCDE1234F',
        ),
      );
      final form = http.bodies['/api/v1/rider/documents/']! as FormData;
      expect(Map.fromEntries(form.fields), {
        'doc_type': 'PAN',
        'number': 'ABCDE1234F',
      });
      expect(form.files.single.value.contentType.toString(), 'image/jpeg');
      expect(doc.status, DocumentReviewStatus.pending);
      expect(doc.reviewNote, isNull);
    },
  );

  test('an image over 1 MB is refused on the phone, nothing is sent', () async {
    await expectLater(
      repo.uploadDocument(
        DocumentUpload(type: KycDocumentType.pan, image: Uint8List(1000001)),
      ),
      throwsA(isA<ApiError>()),
    );
    expect(http.requests, isEmpty);
  });

  test('bank details: PUT, the answer masked', () async {
    http.answers['/api/v1/rider/bank-account/'] = const Canned(200, {
      'holder_name': 'Ravi Kumar',
      'account_number_masked': 'XXXXXX7890',
      'ifsc': 'HDFC0001234',
      'upi_id': 'ravi@upi',
      'updated_at': '2026-11-04T10:00:00Z',
    });
    final saved = await repo.saveBankAccount(
      const BankAccountInput(
        holderName: 'Ravi Kumar',
        accountNumber: '1234567890',
        ifsc: 'HDFC0001234',
        upiId: 'ravi@upi',
      ),
    );
    expect(saved.accountNumberMasked, 'XXXXXX7890');
    expect(http.requests.single.method, 'PUT');
  });
}
