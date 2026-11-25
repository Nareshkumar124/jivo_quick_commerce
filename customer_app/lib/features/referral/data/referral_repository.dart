import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    as api
    show
        CouponDiscountTypeEnum,
        JivoApi,
        Referral,
        ReferralApplyRequest,
        ReferralStatusEnum,
        ReferredBy;
import 'package:jivo_core/jivo_core.dart';

import '../domain/referral.dart';

/// Refer a friend (`GET /account/referral/`,
/// `POST /account/referral/apply/`). This file is the only place that uses
/// the generated referral types.
abstract interface class ReferralRepository {
  /// The customer's code, share message, reward terms and counts. Throws
  /// [ApiError].
  Future<ReferralInfo> fetch();

  /// Enters a friend's [code] (once, before the first order). Returns the
  /// updated screen. Throws [ApiError]: `REFERRAL_CODE_INVALID`,
  /// `REFERRAL_SELF`, `REFERRAL_ALREADY_APPLIED`, `REFERRAL_NOT_ELIGIBLE`
  /// (422), `RATE_LIMITED` (429).
  Future<ReferralInfo> apply(String code);
}

class ApiReferralRepository implements ReferralRepository {
  const ApiReferralRepository(this._api);

  final api.JivoApi _api;

  @override
  Future<ReferralInfo> fetch() => _guard(
    () async => referralFromApi(
      (await _api.getAccountApi().accountReferralRetrieve()).data!,
    ),
  );

  @override
  Future<ReferralInfo> apply(String code) => _guard(
    () async => referralFromApi(
      (await _api.getAccountApi().accountReferralApply(
        referralApplyRequest: api.ReferralApplyRequest(code: code.trim()),
      )).data!,
    ),
  );
}

/// Maps the generated `Referral` to the app model. `reward_type`
/// `FREE_UNIT` (ADR 0002) is a free-carton reward of `reward_quantity`
/// cartons; the app words it itself (l10n) rather than showing the
/// server's English `reward_label`, and never shows the deprecated
/// `reward_amount` for it.
ReferralInfo referralFromApi(api.Referral r) => ReferralInfo(
  code: r.code,
  shareMessage: r.shareMessage,
  isEnabled: r.isEnabled,
  rewardAmount: r.rewardAmount,
  rewardType: r.rewardType == api.CouponDiscountTypeEnum.FREE_UNIT
      ? ReferralRewardType.freeCarton
      : ReferralRewardType.amount,
  rewardQuantity: r.rewardQuantity,
  rewardValidityDays: r.rewardValidityDays,
  rewardMinOrderValue: r.rewardMinOrderValue,
  canApplyCode: r.canApplyCode,
  referredBy: switch (r.referredBy) {
    null => null,
    final api.ReferredBy by => ReferredBy(
      codeMasked: by.codeMasked,
      status: switch (by.status) {
        api.ReferralStatusEnum.PENDING => ReferralStatus.pending,
        api.ReferralStatusEnum.REWARDED => ReferralStatus.rewarded,
        api.ReferralStatusEnum.VOID => ReferralStatus.noReward,
        api.ReferralStatusEnum.unknownDefaultOpenApi => ReferralStatus.unknown,
      },
      appliedAt: by.appliedAt,
    ),
  },
  friendsJoined: r.friendsJoined,
  friendsRewarded: r.friendsRewarded,
);

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}

/// A backend stand-in for `--dart-define=FAKE_API=true` and tests.
/// Follows the server's checks in the server's order: program off,
/// code already entered, order already placed, unknown code, own code.
class FakeReferralRepository implements ReferralRepository {
  FakeReferralRepository({
    this.code = 'K7M2PQ',
    this.isEnabled = true,
    this.hasOrders = false,
    this.referredBy,
    this.friendsJoined = 2,
    this.friendsRewarded = 1,
    this.friendCodes = const {'AB3K7P', 'JIVO90'},
    this.rewardType = ReferralRewardType.amount,
  });

  final String code;
  bool isEnabled;

  /// ₹90 off (the old reward) or a free carton (ADR 0002).
  ReferralRewardType rewardType;

  /// An order was already placed: codes can no longer be entered.
  bool hasOrders;
  ReferredBy? referredBy;
  int friendsJoined;
  int friendsRewarded;

  /// Codes of other customers that [apply] accepts.
  final Set<String> friendCodes;

  ApiError? fetchError;
  ApiError? applyError;

  /// When set, [fetch] / [apply] answer only after it completes (tests).
  Future<void>? fetchGate;
  Future<void>? applyGate;
  final List<String> applied = [];
  int fetches = 0;

  ReferralInfo get info => ReferralInfo(
    code: code,
    shareMessage: rewardType == ReferralRewardType.freeCarton
        ? 'Use my code $code on the Jivo app and we each get 1 free carton. '
              'https://jivo.in/app'
        : 'Use my code $code on the Jivo app and we both get ₹90 off. '
              'https://jivo.in/app',
    isEnabled: isEnabled,
    rewardType: rewardType,
    rewardAmount: rewardType == ReferralRewardType.freeCarton
        ? '0.00'
        : '90.00',
    rewardValidityDays: 30,
    rewardMinOrderValue: '0.00',
    canApplyCode: isEnabled && referredBy == null && !hasOrders,
    referredBy: referredBy,
    friendsJoined: friendsJoined,
    friendsRewarded: friendsRewarded,
  );

  @override
  Future<ReferralInfo> fetch() async {
    fetches++;
    final gate = fetchGate;
    if (gate != null) await gate;
    final error = fetchError;
    if (error != null) throw error;
    return info;
  }

  @override
  Future<ReferralInfo> apply(String code) async {
    applied.add(code);
    final gate = applyGate;
    if (gate != null) await gate;
    final error = applyError;
    if (error != null) throw error;
    final clean = code.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (!isEnabled) _fail(ApiErrorCode.referralNotEligible, 'PROGRAM_OFF');
    if (referredBy != null) _fail(ApiErrorCode.referralAlreadyApplied);
    if (hasOrders) _fail(ApiErrorCode.referralNotEligible, 'HAS_ORDERS');
    if (clean == this.code) _fail(ApiErrorCode.referralSelf);
    if (!friendCodes.contains(clean)) _fail(ApiErrorCode.referralCodeInvalid);
    referredBy = ReferredBy(
      codeMasked: clean.length < 5
          ? clean
          : '${clean.substring(0, 2)}**${clean.substring(clean.length - 2)}',
      status: ReferralStatus.pending,
      appliedAt: DateTime.now().toUtc(),
    );
    return info;
  }

  Never _fail(ApiErrorCode code, [String? reason]) => throw ApiError(
    code: code,
    rawCode: code.wireValue,
    statusCode: 422,
    details: {'reason': ?reason},
  );
}
