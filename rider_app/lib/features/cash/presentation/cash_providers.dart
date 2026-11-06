import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../data/api_cash_repository.dart';
import '../data/fake_cash_backend.dart';
import '../domain/cash_ledger.dart';

/// The fake cash ledger (`FAKE_API` builds). Overridden in tests.
final fakeCashBackendProvider = Provider<FakeCashBackend>(
  (ref) => FakeCashBackend(clock: ref.watch(clockProvider)),
);

/// The ledger: the generated client (P5 slice 5.4), the fake with
/// `FAKE_API`. The screens stay where the rider work screens run (dev
/// flavor, DL-30/DL-32).
final cashRepositoryProvider = Provider<CashRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeCashBackendProvider);
  }
  return ApiCashRepository(ref.watch(jivoApiProvider));
});

/// The ledger, paged, with the cash summary from the latest page as the
/// header.
final cashLedgerProvider =
    NotifierProvider.autoDispose<
      PagedListNotifier<CashEntry, CashSummary>,
      PagedListState<CashEntry, CashSummary>
    >(
      () => PagedListNotifier((ref, cursor) async {
        final result = await ref
            .read(cashRepositoryProvider)
            .fetchLedger(cursor: cursor);
        return (result.entries, result.summary);
      }, keyOf: (entry) => entry.id),
    );

/// Staging and prod until the rider API lands: never reached (the routes
/// and the home menu exist only in the dev flavor); every call fails with
/// `NOT_FOUND`.
class _Unavailable implements CashRepository {
  const _Unavailable();

  @override
  Future<CashLedgerPage> fetchLedger({int? cursor}) async =>
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
}
