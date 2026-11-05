import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    as api
    show
        JivoApi,
        RiderBankAccount,
        RiderBankAccountUpdateRequest,
        RiderDocument,
        RiderDocumentStatusEnum,
        RiderDocumentTypeEnum,
        RiderHomeStore,
        RiderProfile,
        RiderRegisterRequest,
        RiderStore,
        VehicleTypeEnum;
import 'package:jivo_core/jivo_core.dart';

import '../domain/image_compression.dart';
import '../domain/kyc_document.dart';
import '../domain/onboarding_inputs.dart';
import '../domain/rider_onboarding_repository.dart';
import '../domain/rider_profile.dart';
import '../domain/vehicle_type.dart';

/// Registration and KYC through the generated client (P5 slice 5.1):
/// `rider_stores_list`, `rider_register`, `rider_me_retrieve`,
/// `rider_documents_create` (multipart) and `rider_bank_account_update`.
class ApiRiderOnboardingRepository implements RiderOnboardingRepository {
  ApiRiderOnboardingRepository(this._api);

  final api.JivoApi _api;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  @override
  Future<List<StoreOption>> fetchStores() => _call(() async {
    final list = (await _api.getRiderApi().riderStoresList()).data!;
    return [for (final s in list.results) _store(s)];
  });

  @override
  Future<RiderProfile> register(RiderRegistration r) => _call(() async {
    final profile = (await _api.getRiderApi().riderRegister(
      // `dob` is a date: the generator sends it as YYYY-MM-DD (#38).
      riderRegisterRequest: api.RiderRegisterRequest(
        fullName: r.fullName,
        dob: r.dateOfBirth,
        emergencyContactName: r.emergencyContactName,
        emergencyContactPhone: r.emergencyContactPhone,
        preferredStoreId: r.preferredStoreId,
        vehicleType: api.VehicleTypeEnum.values.firstWhere(
          (t) => t.value == r.vehicleType.wireValue,
        ),
        vehicleNumber: r.vehicleNumber,
      ),
    )).data!;
    return profileFromApi(profile);
  });

  @override
  Future<RiderProfile> fetchProfile() => _call(
    () async =>
        profileFromApi((await _api.getRiderApi().riderMeRetrieve()).data!),
  );

  /// The image comes from `compressToLimit` (`image_compression.dart`),
  /// which guarantees a JPEG of at most [kKycImageMaxBytes]. The size is
  /// checked again here, cheaply, so nothing larger ever leaves the phone.
  @override
  Future<RiderDocument> uploadDocument(DocumentUpload upload) =>
      _call(() async {
        if (upload.image.length > kKycImageMaxBytes) {
          throw const ApiError(
            code: ApiErrorCode.validationError,
            details: {
              'file': ['The photo is larger than 1 MB.'],
            },
          );
        }
        final document = (await _api.getRiderApi().riderDocumentsCreate(
          docType: api.RiderDocumentTypeEnum.values.firstWhere(
            (t) => t.value == upload.type.wireValue,
          ),
          file: MultipartFile.fromBytes(
            upload.image,
            filename: '${upload.type.wireValue.toLowerCase()}.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
          number: upload.number,
        )).data!;
        return documentFromApi(document)!;
      });

  @override
  Future<BankAccountSummary> saveBankAccount(BankAccountInput input) =>
      _call(() async {
        final account = (await _api.getRiderApi().riderBankAccountUpdate(
          riderBankAccountUpdateRequest: api.RiderBankAccountUpdateRequest(
            holderName: input.holderName,
            accountNumber: input.accountNumber,
            ifsc: input.ifsc,
            upiId: input.upiId,
          ),
        )).data!;
        return _bank(account);
      });
}

StoreOption _store(api.RiderStore s) =>
    StoreOption(id: s.id, name: s.name, city: s.city);

StoreOption _homeStore(api.RiderHomeStore s) =>
    StoreOption(id: s.id, name: s.name, city: s.city);

BankAccountSummary _bank(api.RiderBankAccount b) => BankAccountSummary(
  holderName: b.holderName,
  accountNumberMasked: b.accountNumberMasked,
  ifsc: b.ifsc,
  upiId: b.upiId,
);

/// `GET /rider/me/` as the domain profile.
RiderProfile profileFromApi(api.RiderProfile p) => RiderProfile(
  status: p.status,
  fullName: p.fullName,
  dateOfBirth: p.dob,
  emergencyContactName: p.emergencyContactName,
  emergencyContactPhone: p.emergencyContactPhone,
  preferredStore: _store(p.preferredStore),
  homeStore: p.homeStore == null ? null : _homeStore(p.homeStore!),
  vehicleType: VehicleType.fromWire(p.vehicleType.value) ?? VehicleType.bicycle,
  vehicleNumber: p.vehicleNumber,
  rejectionReason: p.rejectionReason.isEmpty ? null : p.rejectionReason,
  documents: [for (final d in p.documents) ?documentFromApi(d)],
  bankAccount: p.bankAccount == null ? null : _bank(p.bankAccount!),
  photoUrl: p.photoUrl,
  rating: p.ratingAvg,
);

/// A document the app knows, or null for a type this version does not.
RiderDocument? documentFromApi(api.RiderDocument d) {
  final type = KycDocumentType.fromWire(d.docType.value);
  if (type == null) return null;
  return RiderDocument(
    type: type,
    status: switch (d.status) {
      api.RiderDocumentStatusEnum.APPROVED => DocumentReviewStatus.approved,
      api.RiderDocumentStatusEnum.REJECTED => DocumentReviewStatus.rejected,
      _ => DocumentReviewStatus.pending,
    },
    numberMasked: d.docNumberMasked,
    reviewNote: d.reviewNote.isEmpty ? null : d.reviewNote,
    uploadedAt: d.uploadedAt,
  );
}
