import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../data/fake_cash_backend.dart';
import '../domain/cash_ledger.dart';

/// TODO(api): the fake cash ledger. Handed out only where the rider work
/// screens run (dev flavor, DL-30/DL-32); overridden in tests.
final fakeCashBackendProvider = Provider<FakeCashBackend>(
  (ref) => FakeCashBackend(clock: ref.watch(clockProvider)),
);

/// TODO(api): bind to the generated client when the rider contract lands.
final cashRepositoryProvider = Provider<CashRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  return ref.watch(fakeCashBackendProvider);
});

/// The ledger, paged, with the cash summary from the latest page as the
/// header.
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
      }, keyOf: (entry) => entry.id),
    );

/// Staging and prod until the rider API lands: never reached (the routes
/// and the home menu exist only in the dev flavor); every call fails with
/// `NOT_FOUND`.
class _Unavailable implements CashRepository {
  const _Unavailable();

  @override
  Future<CashLedgerPage> fetchLedger({int page = 1}) async =>
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
}
