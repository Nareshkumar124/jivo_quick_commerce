import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../data/api_earnings_repository.dart';
import '../data/fake_earnings_backend.dart';
import '../domain/earnings.dart';

/// The fake earnings and payouts (`FAKE_API` builds). Overridden in tests.
final fakeEarningsBackendProvider = Provider<FakeEarningsBackend>(
  (ref) => FakeEarningsBackend(),
);

/// Earnings and payouts: the generated client (P5 slice 5.4), the fake
/// with `FAKE_API`. The screens stay where the rider work screens run (dev
/// flavor, DL-30/DL-32).
final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeEarningsBackendProvider);
  }
  return ApiEarningsRepository(ref.watch(jivoApiProvider));
});

/// The chosen period and its IST dates.
typedef EarningsSelection = ({EarningsPeriod period, DateRange range});

final earningsSelectionProvider =
    NotifierProvider.autoDispose<EarningsSelectionNotifier, EarningsSelection>(
      EarningsSelectionNotifier.new,
    );

class EarningsSelectionNotifier extends Notifier<EarningsSelection> {
  @override
  EarningsSelection build() => (
    period: EarningsPeriod.today,
    range: rangeFor(EarningsPeriod.today, ref.read(clockProvider)()),
  );

  void select(EarningsPeriod period) {
    if (period == EarningsPeriod.custom) return;
    state = (
      period: period,
      range: rangeFor(period, ref.read(clockProvider)()),
    );
  }

  void custom(DateRange range) =>
      state = (period: EarningsPeriod.custom, range: range);
}

/// `GET /rider/earnings/` for the selected dates.
final earningsProvider = FutureProvider.autoDispose<EarningsSummary>((ref) {
  final range = ref.watch(earningsSelectionProvider.select((s) => s.range));
  return ref.watch(earningsRepositoryProvider).fetchEarnings(range);
});

/// `GET /rider/payouts/`, paged.
final payoutsProvider =
    NotifierProvider.autoDispose<
      PagedListNotifier<Payout, void>,
      PagedListState<Payout, void>
    >(
      () => PagedListNotifier((ref, cursor) async {
        final result = await ref
            .read(earningsRepositoryProvider)
            .fetchPayouts(cursor: cursor);
        return (result, null);
      }, keyOf: (payout) => payout.id),
    );
