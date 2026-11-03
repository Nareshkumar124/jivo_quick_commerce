import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../domain/image_compression.dart';
import '../domain/kyc_document.dart';
import '../domain/masking.dart';
import '../domain/onboarding_inputs.dart';
import '../domain/rider_onboarding_repository.dart';
import '../domain/rider_profile.dart';
import '../domain/vehicle_type.dart';

/// Who the fake is answering for: the signed-in phone and the
/// `rider_status` the app currently routes by.
typedef FakeRiderIdentity = ({String key, RiderStatusEnum status});

/// TODO(api): stands in for the rider onboarding endpoints of 06 §3
/// (`/rider/register/`, `/rider/me/`, `/rider/documents/`,
/// `/rider/bank-account/`) and the missing store list, until the rider
/// contract lands at the end of P4. Behaviour the docs do not define is
/// marked "assumed" and listed as API questions in the run report.
///
/// Profiles live in memory, keyed by phone, and are lost on restart. A
/// rider without a profile here is seeded from the status the app routes by,
/// matching `FakeAuthBackend`'s test numbers: last digit 2 `PENDING_KYC`
/// (everything submitted, in review), 3 `REJECTED` (PAN rejected),
/// 4 `SUSPENDED`. `NONE` has no profile until it registers.
class FakeRiderOnboardingBackend implements RiderOnboardingRepository {
  FakeRiderOnboardingBackend({
    this.delay = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration delay;
  final DateTime Function() _clock;

  /// Set by the provider: the signed-in rider, or null when signed out.
  FakeRiderIdentity? Function() currentRider = () => null;

  final Map<String, RiderProfile> _profiles = {};

  /// Calls made, for tests. Never contains document or account numbers.
  final List<String> calls = [];

  /// When set, the next call fails with it (then it is cleared).
  ApiError? failNext;

  static const stores = [
    StoreOption(id: 1, name: 'Jivo Sector 18', city: 'Noida'),
    StoreOption(id: 2, name: 'Jivo Indirapuram', city: 'Ghaziabad'),
    StoreOption(id: 3, name: 'Jivo Saket', city: 'New Delhi'),
  ];

  static const rejectedPanNote =
      'The photo is blurred. Upload a clear photo of your PAN card.';
  static const rejectionReason = 'Your PAN card photo could not be read.';

  @override
  Future<List<StoreOption>> fetchStores() async {
    await _call('fetchStores');
    return stores;
  }

  @override
  Future<RiderProfile> register(RiderRegistration registration) async {
    await _call('register');
    final rider = _rider();
    if (_profiles.containsKey(rider.key) || _seed(rider) != null) {
      throw _validation({
        'non_field_errors': ['A rider profile already exists.'],
      });
    }
    final store = stores.where((s) => s.id == registration.preferredStoreId);
    if (store.isEmpty) {
      throw _validation({
        'preferred_store': ['Choose a store.'],
      });
    }
    if (registration.vehicleType.isMotorised &&
        (registration.vehicleNumber ?? '').isEmpty) {
      throw _validation({
        'vehicle_number': ['Required for motorised vehicles.'],
      });
    }
    final profile = RiderProfile(
      status: RiderStatusEnum.PENDING_KYC,
      fullName: registration.fullName,
      dateOfBirth: registration.dateOfBirth,
      emergencyContactName: registration.emergencyContactName,
      emergencyContactPhone: registration.emergencyContactPhone,
      preferredStore: store.single,
      vehicleType: registration.vehicleType,
      vehicleNumber: registration.vehicleType.isMotorised
          ? registration.vehicleNumber
          : null,
    );
    return _profiles[rider.key] = profile;
  }

  @override
  Future<RiderProfile> fetchProfile() async {
    await _call('fetchProfile');
    return _profile();
  }

  @override
  Future<RiderDocument> uploadDocument(DocumentUpload upload) async {
    await _call('uploadDocument ${upload.type.wireValue}');
    final rider = _rider();
    final profile = _profile();
    if (upload.image.length > kKycImageMaxBytes) {
      throw _validation({
        'file': ['The file is larger than 1 MB.'],
      });
    }
    if (upload.type.hasNumber && (upload.number ?? '').isEmpty) {
      throw _validation({
        'number': ['This field is required.'],
      });
    }
    // Assumed: an approved document cannot be replaced.
    if (profile.documentOf(upload.type)?.canReplace == false) {
      throw const ApiError(
        code: ApiErrorCode.invalidStateTransition,
        rawCode: 'INVALID_STATE_TRANSITION',
        statusCode: 409,
      );
    }
    final number = upload.number;
    final document = RiderDocument(
      type: upload.type,
      status: DocumentReviewStatus.pending,
      numberMasked: number == null
          ? null
          : upload.type == KycDocumentType.aadhaarFront
          ? Masking.aadhaar(number)
          : Masking.trailing(number),
      uploadedAt: _clock().toUtc(),
    );
    _profiles[rider.key] = _resubmitIfFixed(profile.withDocument(document));
    return document;
  }

  @override
  Future<BankAccountSummary> saveBankAccount(BankAccountInput input) async {
    await _call('saveBankAccount');
    final rider = _rider();
    final profile = _profile();
    final summary = BankAccountSummary(
      holderName: input.holderName,
      accountNumberMasked: Masking.accountNumber(input.accountNumber),
      ifsc: input.ifsc,
      upiId: input.upiId,
    );
    _profiles[rider.key] = _resubmitIfFixed(
      profile.copyWith(bankAccount: summary),
    );
    return summary;
  }

  // Dev and test controls: the real review happens in the admin panel.

  /// Stores [profile] for the rider signed in with [phoneE164].
  void seed(String phoneE164, RiderProfile profile) =>
      _profiles[phoneE164] = profile;

  /// The stored profile for [phoneE164], if any.
  RiderProfile? profileOf(String phoneE164) => _profiles[phoneE164];

  /// Ops approved the rider: `ACTIVE`, home store assigned, documents
  /// approved.
  void approveCurrent() {
    final rider = _rider();
    final profile = _profile();
    _profiles[rider.key] = profile.copyWith(
      status: RiderStatusEnum.ACTIVE,
      homeStore: profile.preferredStore,
      clearRejectionReason: true,
      documents: [
        for (final d in profile.documents)
          RiderDocument(
            type: d.type,
            status: DocumentReviewStatus.approved,
            numberMasked: d.numberMasked,
            uploadedAt: d.uploadedAt,
          ),
      ],
    );
  }

  /// Ops rejected the rider because of [document].
  void rejectCurrent({
    KycDocumentType document = KycDocumentType.pan,
    String note = rejectedPanNote,
    String reason = rejectionReason,
  }) {
    final rider = _rider();
    final profile = _profile();
    final existing = profile.documentOf(document);
    _profiles[rider.key] = profile
        .withDocument(
          RiderDocument(
            type: document,
            status: DocumentReviewStatus.rejected,
            numberMasked: existing?.numberMasked,
            reviewNote: note,
            uploadedAt: existing?.uploadedAt,
          ),
        )
        .copyWith(status: RiderStatusEnum.REJECTED, rejectionReason: reason);
  }

  /// Assumed: once a `REJECTED` rider has replaced every rejected document
  /// and everything required is in, the application goes back to review
  /// (`PENDING_KYC`). Whether the server does this, or needs an explicit
  /// resubmit, is an open API question.
  RiderProfile _resubmitIfFixed(RiderProfile profile) {
    if (profile.status == RiderStatusEnum.REJECTED &&
        profile.documentsComplete &&
        profile.hasBankAccount) {
      return profile.copyWith(
        status: RiderStatusEnum.PENDING_KYC,
        clearRejectionReason: true,
      );
    }
    return profile;
  }

  Future<void> _call(String name) async {
    calls.add(name);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  FakeRiderIdentity _rider() =>
      currentRider() ??
      (throw const ApiError(
        code: ApiErrorCode.authRequired,
        rawCode: 'AUTH_REQUIRED',
        statusCode: 401,
      ));

  RiderProfile _profile() {
    final rider = _rider();
    final profile = _profiles[rider.key] ?? _seed(rider);
    if (profile == null) {
      // Assumed: a user without a rider profile gets 404 from /rider/me/.
      throw const ApiError(
        code: ApiErrorCode.notFound,
        rawCode: 'NOT_FOUND',
        statusCode: 404,
      );
    }
    return _profiles[rider.key] = profile;
  }

  RiderProfile? _seed(FakeRiderIdentity rider) {
    final base = RiderProfile(
      status: rider.status,
      fullName: 'Ravi Kumar',
      dateOfBirth: DateTime.utc(1995, 6, 15),
      emergencyContactName: 'Sunita Kumar',
      emergencyContactPhone: '+919876500001',
      preferredStore: stores.first,
      vehicleType: VehicleType.motorbike,
      vehicleNumber: 'DL3CAB1234',
      documents: [
        for (final type in requiredDocumentsFor(VehicleType.motorbike))
          RiderDocument(
            type: type,
            status: rider.status == RiderStatusEnum.SUSPENDED
                ? DocumentReviewStatus.approved
                : DocumentReviewStatus.pending,
            numberMasked: switch (type) {
              KycDocumentType.aadhaarFront => 'XXXX XXXX 4321',
              KycDocumentType.pan => 'XXXXXX234F',
              KycDocumentType.drivingLicence => 'XXXXXXXXXXX2345',
              KycDocumentType.vehicleRc => 'XXXXXX1234',
              KycDocumentType.photo || KycDocumentType.aadhaarBack => null,
            },
            uploadedAt: DateTime.utc(2026, 10, 30, 6),
          ),
      ],
      bankAccount: const BankAccountSummary(
        holderName: 'Ravi Kumar',
        accountNumberMasked: 'XXXXXXXX6789',
        ifsc: 'HDFC0001234',
      ),
    );
    return switch (rider.status) {
      RiderStatusEnum.ACTIVE => RiderProfile(
        status: RiderStatusEnum.ACTIVE,
        fullName: base.fullName,
        dateOfBirth: base.dateOfBirth,
        emergencyContactName: base.emergencyContactName,
        emergencyContactPhone: base.emergencyContactPhone,
        preferredStore: base.preferredStore,
        homeStore: stores.first,
        vehicleType: base.vehicleType,
        vehicleNumber: base.vehicleNumber,
        rating: '4.8',
        bankAccount: base.bankAccount,
        documents: [
          for (final d in base.documents)
            RiderDocument(
              type: d.type,
              status: DocumentReviewStatus.approved,
              numberMasked: d.numberMasked,
              uploadedAt: d.uploadedAt,
            ),
        ],
      ),
      RiderStatusEnum.PENDING_KYC => base,
      RiderStatusEnum.SUSPENDED => base.copyWith(homeStore: stores.first),
      RiderStatusEnum.REJECTED =>
        base
            .withDocument(
              RiderDocument(
                type: KycDocumentType.pan,
                status: DocumentReviewStatus.rejected,
                numberMasked: 'XXXXXX234F',
                reviewNote: rejectedPanNote,
                uploadedAt: DateTime.utc(2026, 10, 30, 6),
              ),
            )
            .copyWith(rejectionReason: rejectionReason),
      RiderStatusEnum.NONE || RiderStatusEnum.unknownDefaultOpenApi => null,
    };
  }

  static ApiError _validation(Map<String, Object?> details) => ApiError(
    code: ApiErrorCode.validationError,
    rawCode: 'VALIDATION_ERROR',
    statusCode: 400,
    details: details,
  );
}

/// Staging and prod until the rider contract lands: there is no rider API
/// yet and fakes never run there, so every call fails with `NOT_FOUND`. The
/// router keeps the Phase 1 placeholder screens in these builds, so this is
/// only a safety net.
class UnavailableRiderOnboardingRepository
    implements RiderOnboardingRepository {
  const UnavailableRiderOnboardingRepository();

  static const _error = ApiError(code: ApiErrorCode.notFound, statusCode: 404);

  @override
  Future<List<StoreOption>> fetchStores() async => throw _error;

  @override
  Future<RiderProfile> register(RiderRegistration registration) async =>
      throw _error;

  @override
  Future<RiderProfile> fetchProfile() async => throw _error;

  @override
  Future<RiderDocument> uploadDocument(DocumentUpload upload) async =>
      throw _error;

  @override
  Future<BankAccountSummary> saveBankAccount(BankAccountInput input) async =>
      throw _error;
}
