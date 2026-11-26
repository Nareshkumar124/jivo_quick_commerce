import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    as api
    show JivoApi, Reward, RewardHistoryEntry, Rewards;
import 'package:jivo_core/jivo_core.dart';

import '../../cart/data/api_cart_repository.dart' show freeVariantFromApi;
import '../../cart/domain/cart.dart';
import '../domain/reward.dart';

/// The customer's rewards (`GET /account/rewards/`, ADR 0002, 0003).
/// Account data, but sent with the serving store's `X-Store-Id` when there
/// is one, so each reward names that store's fixed free size
/// (`free_variant`, ADR 0003). Implementations throw [ApiError].
///
/// Using a reward is not here: it is the cart's apply-coupon call
/// (`CartRepository.applyCoupon`), with no `free_variant_id` when the store
/// has a fixed free size (ADR 0003), else with the size picked.
abstract interface class RewardsRepository {
  /// Available and claimed rewards, and the history.
  Future<RewardsSummary> fetch();
}

/// `GET /account/rewards/` (`account_rewards_retrieve`) on the generated
/// client. This file is the only place that uses the generated reward
/// types. [storeId] reads the serving store at call time (optional
/// `X-Store-Id`; left out when there is no store yet).
class ApiRewardsRepository implements RewardsRepository {
  const ApiRewardsRepository(this._api, [this._storeId]);

  final api.JivoApi _api;
  final int? Function()? _storeId;

  @override
  Future<RewardsSummary> fetch() async {
    try {
      final response = await _api.getAccountApi().accountRewardsRetrieve(
        xStoreId: _storeId?.call(),
      );
      return rewardsFromApi(response.data!);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// The generated `Rewards` as the app's [RewardsSummary], values as sent.
/// The rewards list is free cartons (ADR 0002).
RewardsSummary rewardsFromApi(api.Rewards r) => RewardsSummary(
  available: [for (final reward in r.available) _reward(reward)],
  history: [for (final entry in r.history) _entry(entry)],
);

// The rewards list is free cartons only (ADR 0002): `discountType` keeps
// its FREE_UNIT default.
Reward _reward(api.Reward r) => Reward(
  code: r.code,
  title: r.title,
  source: RewardSource.fromWire(r.source_.value),
  status: RewardStatus.fromWire(r.status.value),
  expiresAt: r.expiresAt,
  orderNumber: r.orderNumber,
  quantity: r.quantity,
  freeVariant: freeVariantFromApi(r.freeVariant),
);

RewardHistoryEntry _entry(api.RewardHistoryEntry e) => RewardHistoryEntry(
  at: e.at,
  kind: RewardHistoryKind.fromWire(e.kind.value),
  title: e.title,
  quantity: e.quantity,
  orderNumber: e.orderNumber,
);

/// A backend stand-in for `--dart-define=FAKE_API=true` and tests, with
/// the ADR 0002 shapes. [summary] is what `fetch` returns.
class FakeRewardsRepository implements RewardsRepository {
  FakeRewardsRepository({this.summary = RewardsSummary.empty});

  /// The dev flavor's demo (ADR 0003: 2 free 1 L cartons each): a welcome
  /// gift to use, a referral reward on an order, and some history.
  /// [welcomeCode] is also a reward the fake cart accepts
  /// (`app/repositories.dart`), of the fake store's fixed free size
  /// [demoFreeVariant].
  factory FakeRewardsRepository.demo({DateTime? now}) {
    final today = (now ?? DateTime.now()).toUtc();
    return FakeRewardsRepository(
      summary: RewardsSummary(
        available: [
          Reward(
            code: welcomeCode,
            title: '2 free cartons',
            source: RewardSource.welcome,
            status: RewardStatus.available,
            expiresAt: today.add(const Duration(days: 28)),
            quantity: demoQuantity,
            freeVariant: demoFreeVariant,
          ),
          Reward(
            code: 'REF-2FC-7P2K',
            title: '2 free cartons',
            source: RewardSource.referralReferrer,
            status: RewardStatus.claimed,
            expiresAt: today.add(const Duration(days: 20)),
            orderNumber: 'JV-261124-001002',
            quantity: demoQuantity,
            freeVariant: demoFreeVariant,
          ),
        ],
        history: [
          RewardHistoryEntry(
            at: today.subtract(const Duration(days: 2)),
            kind: RewardHistoryKind.earned,
            title: 'Welcome gift',
            quantity: demoQuantity,
          ),
          RewardHistoryEntry(
            at: today.subtract(const Duration(days: 1)),
            kind: RewardHistoryKind.claimed,
            title: 'Referral reward',
            quantity: demoQuantity,
            orderNumber: 'JV-261124-001002',
          ),
          RewardHistoryEntry(
            at: today.subtract(const Duration(days: 5)),
            kind: RewardHistoryKind.volumeFree,
            title: 'Buy 10 get 1 free',
            quantity: 2,
            orderNumber: 'JV-261120-001001',
          ),
        ],
      ),
    );
  }

  /// The demo welcome reward's code.
  static const welcomeCode = 'WELCOME-2FC';

  /// Free cartons in each demo reward (staging's setting, ADR 0003).
  static const demoQuantity = 2;

  /// The fake store's fixed free size: the fake catalog's 1 L water.
  static const demoFreeVariant = FreeVariant(
    id: 1501,
    name: '1 L',
    productName: 'Jivo Packaged Drinking Water',
  );

  RewardsSummary summary;

  /// When set, [fetch] throws it (until cleared).
  Object? error;

  /// When set, [fetch] answers only after it completes (tests).
  Future<void>? gate;
  int fetches = 0;

  @override
  Future<RewardsSummary> fetch() async {
    fetches++;
    final wait = gate;
    if (wait != null) await wait;
    final failure = error;
    if (failure != null) throw failure;
    return summary;
  }
}
