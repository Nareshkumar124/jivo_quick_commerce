import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../../shared/paging.dart';
import '../../task/presentation/task_providers.dart';
import '../data/api_inbox_repository.dart';
import '../data/fake_inbox_backend.dart';
import '../domain/inbox.dart';

/// The fake inbox (`FAKE_API` builds). Overridden in tests.
final fakeInboxBackendProvider = Provider<FakeInboxBackend>(
  (ref) => FakeInboxBackend(clock: ref.watch(clockProvider)),
);

/// The inbox: the generated client, the fake with `FAKE_API`. Where the
/// rider work screens run (dev flavor, DL-30/DL-32).
final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeInboxBackendProvider);
  }
  return ApiInboxRepository(ref.watch(jivoApiProvider));
});

/// The home bell's badge: unread entries on the first page. Re-read when
/// the inbox changes, on `task.updated` and pull-to-refresh on home.
final inboxUnreadCountProvider = FutureProvider.autoDispose<InboxBadge>((
  ref,
) async {
  if (!ref.watch(riderWorkActiveProvider)) return InboxBadge.none;
  return InboxBadge.of(await ref.watch(inboxRepositoryProvider).fetchPage());
});

final inboxControllerProvider =
    NotifierProvider.autoDispose<
      InboxController,
      PagedListState<InboxEntry, void>
    >(InboxController.new);

/// The inbox list (newest first, paged) with mark-read: a tap marks one
/// entry read, "Mark all read" all of them. The list updates at once; the
/// server's answer is kept, and a failure puts the entry back as unread.
class InboxController extends PagedListNotifier<InboxEntry, void> {
  InboxController()
    : super(
        (ref, cursor) async => (
          await ref.read(inboxRepositoryProvider).fetchPage(page: cursor),
          null,
        ),
        keyOf: (entry) => entry.id,
      );

  InboxRepository get _repo => ref.read(inboxRepositoryProvider);

  void _replace(int id, InboxEntry Function(InboxEntry entry) update) {
    state = PagedListState(
      items: [
        for (final entry in state.items) entry.id == id ? update(entry) : entry,
      ],
      nextPage: state.nextPage,
      loading: state.loading,
      loaded: state.loaded,
      error: state.error,
    );
  }

  Future<void> markRead(int id) async {
    final before = state.items.where((e) => e.id == id).firstOrNull;
    if (before == null || before.read) return;
    _replace(id, (entry) => entry.asRead());
    try {
      final stored = await _repo.markRead(id);
      if (!ref.mounted) return;
      _replace(id, (_) => stored);
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return;
      reportAppControlError(ref, error);
      debugPrint('InboxController.markRead: ${error.code}');
      if (error.code != ApiErrorCode.notFound) _replace(id, (_) => before);
    }
    if (ref.mounted) ref.invalidate(inboxUnreadCountProvider);
  }

  /// Returns false when the call failed (the list is left as it was).
  Future<bool> markAllRead() async {
    final before = state.items;
    state = PagedListState(
      items: [for (final entry in before) entry.asRead()],
      nextPage: state.nextPage,
      loaded: state.loaded,
    );
    try {
      await _repo.markAllRead();
      return true;
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return false;
      reportAppControlError(ref, error);
      state = PagedListState(
        items: before,
        nextPage: state.nextPage,
        loaded: state.loaded,
        error: error,
      );
      return false;
    } finally {
      if (ref.mounted) ref.invalidate(inboxUnreadCountProvider);
    }
  }
}

/// Staging and prod while gated: never reached; every call fails.
class _Unavailable implements InboxRepository {
  const _Unavailable();

  static const _error = ApiError(code: ApiErrorCode.notFound, statusCode: 404);

  @override
  Future<Page<InboxEntry>> fetchPage({int? page}) async => throw _error;

  @override
  Future<InboxEntry> markRead(int id) async => throw _error;

  @override
  Future<int> markAllRead() async => throw _error;
}
