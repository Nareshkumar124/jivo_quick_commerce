import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../../shared/paging.dart';
import '../../task/presentation/task_providers.dart';
import '../data/fake_history_backend.dart';
import '../domain/task_history.dart';

/// TODO(api): the fake task history. Handed out only where the rider work
/// screens run (dev flavor, DL-30/DL-32); overridden in tests.
final fakeHistoryBackendProvider = Provider<FakeHistoryBackend>(
  (ref) => FakeHistoryBackend(clock: ref.watch(clockProvider)),
);

/// TODO(api): bind to the generated client when the rider contract lands.
final taskHistoryRepositoryProvider = Provider<TaskHistoryRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  return ref.watch(fakeHistoryBackendProvider);
});

/// `GET /rider/tasks/history/`, newest first, paged.
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
      }, keyOf: (entry) => entry.taskId),
    );

/// Staging and prod until the rider API lands: never reached (the routes
/// and the home menu exist only in the dev flavor); every call fails with
/// `NOT_FOUND`.
class _Unavailable implements TaskHistoryRepository {
  const _Unavailable();

  @override
  Future<Page<TaskHistoryEntry>> fetchHistory({int page = 1}) async =>
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
}
