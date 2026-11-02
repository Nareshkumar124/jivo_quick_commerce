import 'kyc_document.dart';
import 'onboarding_inputs.dart';
import 'rider_profile.dart';

/// Rider registration and KYC (06 §3, 04 §2.2). Every method throws
/// jivo_core's `ApiError` on failure.
///
/// TODO(api): no rider contract yet (development-phase §7 row 2 was not
/// approved). Bound to the generated `jivo_api` types at the end of P4; the
/// fake stands in until then.
abstract interface class RiderOnboardingRepository {
  /// Stores a rider can choose as preferred home store.
  ///
  /// TODO(api): missing from 06 §3 (reported as a gap).
  Future<List<StoreOption>> fetchStores();

  /// `POST /rider/register/`: creates the rider profile (`PENDING_KYC`).
  Future<RiderProfile> register(RiderRegistration registration);

  /// `GET /rider/me/`: profile, KYC status per document, payout details.
  Future<RiderProfile> fetchProfile();

  /// `POST /rider/documents/` (multipart `type + file + number`). Replaces a
  /// document of the same type.
  Future<RiderDocument> uploadDocument(DocumentUpload upload);

  /// `PUT /rider/bank-account/`.
  Future<BankAccountSummary> saveBankAccount(BankAccountInput input);
}
