import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    as api
    show JivoApi, Reward, RewardHistoryEntry, Rewards;
import 'package:jivo_core/jivo_core.dart';

import '../../cart/domain/cart.dart';
import '../domain/reward.dart';

/// The customer's rewards (`GET /account/rewards/`, ADR 0002). Account
/// data: no `X-Store-Id`. Implementations throw [ApiError].
///
/// Using a reward is not here: it is the cart's apply-coupon call with
/// `free_variant_id` (`CartRepository.applyCoupon`).
abstract interface class RewardsRepository {
  /// Available and claimed rewards, and the history.
  Future<RewardsSummary> fetch();
}

/// `GET /account/rewards/` (`account_rewards_retrieve`) on the generated
/// client. This file is the only place that uses the generated reward
/// types.
class ApiRewardsRepository implements RewardsRepository {
  const ApiRewardsRepository(this._api);

  final api.JivoApi _api;

  @override
  Future<RewardsSummary> fetch() async {
    try {
      final response = await _api.getAccountApi().accountRewardsRetrieve();
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

  /// The dev flavor's demo: a welcome gift to use, a referral reward on an
  /// order, and some history. [welcomeCode] is also a reward the fake cart
  /// accepts (`app/repositories.dart`).
  factory FakeRewardsRepository.demo({DateTime? now}) {
    final today = (now ?? DateTime.now()).toUtc();
    return FakeRewardsRepository(
      summary: RewardsSummary(
        available: [
          Reward(
            code: welcomeCode,
            title: '1 free carton',
            source: RewardSource.welcome,
            status: RewardStatus.available,
            expiresAt: today.add(const Duration(days: 28)),
          ),
          Reward(
            code: 'REF-1FC-7P2K',
            title: '1 free carton',
            source: RewardSource.referralReferrer,
            status: RewardStatus.claimed,
            expiresAt: today.add(const Duration(days: 20)),
            orderNumber: 'JV-261124-001002',
          ),
        ],
        history: [
          RewardHistoryEntry(
            at: today.subtract(const Duration(days: 2)),
            kind: RewardHistoryKind.earned,
            title: 'Welcome gift',
          ),
          RewardHistoryEntry(
            at: today.subtract(const Duration(days: 1)),
            kind: RewardHistoryKind.claimed,
            title: 'Referral reward',
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
  static const welcomeCode = 'WELCOME-1FC';

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
