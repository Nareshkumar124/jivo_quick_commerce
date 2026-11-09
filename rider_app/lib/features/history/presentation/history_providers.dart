import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../../shared/paging.dart';
import '../../task/presentation/task_providers.dart';
import '../data/api_history_repository.dart';
import '../data/fake_history_backend.dart';
import '../domain/task_history.dart';

/// The fake task history (`FAKE_API` builds). Overridden in tests.
final fakeHistoryBackendProvider = Provider<FakeHistoryBackend>(
  (ref) => FakeHistoryBackend(clock: ref.watch(clockProvider)),
);

/// Task history: the generated client (P5 slice 5.4), the fake with
/// `FAKE_API`. The screens stay where the rider work screens run (dev
/// flavor, DL-30/DL-32).
final taskHistoryRepositoryProvider = Provider<TaskHistoryRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeHistoryBackendProvider);
  }
  return ApiHistoryRepository(ref.watch(jivoApiProvider));
});

/// `GET /rider/tasks/history/`, newest first, paged.
final taskHistoryProvider =
    NotifierProvider.autoDispose<
      PagedListNotifier<TaskHistoryEntry, void>,
      PagedListState<TaskHistoryEntry, void>
    >(
      () => PagedListNotifier((ref, cursor) async {
        final result = await ref
            .read(taskHistoryRepositoryProvider)
            .fetchHistory(cursor: cursor);
        return (result, null);
      }, keyOf: (entry) => entry.taskId),
    );

/// One past task (`GET /rider/tasks/history/{id}/`).
final taskHistoryDetailProvider = FutureProvider.autoDispose
    .family<TaskHistoryDetail, int>(
      (ref, taskId) =>
          ref.watch(taskHistoryRepositoryProvider).fetchDetail(taskId),
    );

/// Staging and prod until the rider API lands: never reached (the routes
/// and the home menu exist only in the dev flavor); every call fails with
/// `NOT_FOUND`.
class _Unavailable implements TaskHistoryRepository {
  const _Unavailable();

  @override
  Future<Page<TaskHistoryEntry>> fetchHistory({int? cursor}) async =>
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);

  @override
  Future<TaskHistoryDetail> fetchDetail(int taskId) async =>
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
}
