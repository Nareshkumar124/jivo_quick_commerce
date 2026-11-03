import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../../shared/paging.dart';
import '../../cash/domain/cash_ledger.dart';
import '../../history/domain/task_history.dart';
import '../../task/presentation/task_providers.dart';
import '../data/fake_rider_records_backend.dart';
import '../domain/earnings.dart';

/// TODO(api): the fake earnings / payouts / cash / history backend, gated
/// like the other rider fakes (DL-30: dev flavor only). Overridden in tests.
final fakeRiderRecordsBackendProvider = Provider<FakeRiderRecordsBackend>(
  (ref) => FakeRiderRecordsBackend(),
);

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  return ref.watch(fakeRiderRecordsBackendProvider);
});

final cashRepositoryProvider = Provider<CashRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  return ref.watch(fakeRiderRecordsBackendProvider);
});

final taskHistoryRepositoryProvider = Provider<TaskHistoryRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  return ref.watch(fakeRiderRecordsBackendProvider);
});

// ------------------------------------------------------------- earnings

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

// ---------------------------------------------------------- paged lists

final payoutsProvider =
    NotifierProvider.autoDispose<
      PagedListNotifier<Payout, void>,
      PagedListState<Payout, void>
    >(
      () => PagedListNotifier((ref, page) async {
        final result = await ref
            .read(earningsRepositoryProvider)
            .fetchPayouts(page: page);
        return (result, null);
      }),
    );

final taskHistoryProvider =
    NotifierProvider.autoDispose<
      PagedListNotifier<TaskHistoryEntry, void>,
      PagedListState<TaskHistoryEntry, void>
    >(
      () => PagedListNotifier((ref, page) async {
        final result = await ref
            .read(taskHistoryRepositoryProvider)
            .fetchHistory(page: page);
        return (result, null);
      }),
    );

/// The ledger, with the cash summary from its first page as the header.
final cashLedgerProvider =
    NotifierProvider.autoDispose<
      PagedListNotifier<CashEntry, CashSummary>,
      PagedListState<CashEntry, CashSummary>
    >(
      () => PagedListNotifier((ref, page) async {
        final result = await ref
            .read(cashRepositoryProvider)
            .fetchLedger(page: page);
        return (result.entries, result.summary);
      }),
    );

/// Staging and prod: never reached (the screens exist only where the fake
/// runs); every call fails with `NOT_FOUND`.
class _Unavailable
    implements EarningsRepository, CashRepository, TaskHistoryRepository {
  const _Unavailable();

  static const _error = ApiError(code: ApiErrorCode.notFound, statusCode: 404);

  @override
  Future<EarningsSummary> fetchEarnings(DateRange range) async => throw _error;

  @override
  Future<Page<Payout>> fetchPayouts({int page = 1}) async => throw _error;

  @override
  Future<CashLedgerPage> fetchLedger({int page = 1}) async => throw _error;

  @override
  Future<Page<TaskHistoryEntry>> fetchHistory({int page = 1}) async =>
      throw _error;
}
