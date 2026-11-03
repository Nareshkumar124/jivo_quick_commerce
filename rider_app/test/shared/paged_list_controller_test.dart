import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/shared/paged_list_controller.dart';
import 'package:rider_app/shared/paging.dart';

import '../helpers/rider_app_harness.dart';

/// Answers each page request with a completer the test controls.
class _Pages {
  final requests = <int>[];
  final _pending = <Completer<Page<int>>>[];

  Future<Page<int>> fetch(int page) {
    requests.add(page);
    final completer = Completer<Page<int>>();
    _pending.add(completer);
    return completer.future;
  }

  /// Completes an open request: the oldest, or the [at]-th still open.
  Future<void> answer(List<int> items, {int? next, int at = 0}) async {
    _pending.removeAt(at).complete(Page(items: items, nextPage: next));
    await pumpEventQueue();
  }

  Future<void> fail(ApiError error, {int at = 0}) async {
    _pending.removeAt(at).completeError(error);
    await pumpEventQueue();
  }
}

/// Counts every state write after `build`, to prove a late answer writes
/// nothing.
class _SpyNotifier extends PagedListNotifier<int, void> {
  _SpyNotifier(_Pages pages, {required bool dedupe})
    : super(
        (ref, page) async => (await pages.fetch(page), null),
        keyOf: dedupe ? (item) => item : null,
      );

  int writes = 0;

  @override
  set state(PagedListState<int, void> value) {
    writes++;
    super.state = value;
  }
}

void main() {
  late _Pages pages;
  late ProviderContainer container;
  late NotifierProvider<_SpyNotifier, PagedListState<int, void>> provider;

  Future<void> start({bool dedupe = true}) async {
    pages = _Pages();
    provider = NotifierProvider(() => _SpyNotifier(pages, dedupe: dedupe));
    container = await RiderTestHarness().container();
    container.listen(provider, (_, _) {});
    await pumpEventQueue();
  }

  PagedListState<int, void> state() => container.read(provider);
  _SpyNotifier notifier() => container.read(provider.notifier);

  test('first page on start, then "Load more" until the last page', () async {
    await start();
    expect(state().loading, isTrue);
    expect(pages.requests, [1]);

    await pages.answer([5, 4, 3], next: 2);
    expect(state().items, [5, 4, 3]);
    expect(state().hasMore, isTrue);

    unawaited(notifier().loadMore());
    await pumpEventQueue();
    // A second tap while loading asks for nothing more.
    unawaited(notifier().loadMore());
    await pages.answer([2, 1]);
    expect(pages.requests, [1, 2]);
    expect(state().items, [5, 4, 3, 2, 1]);
    expect(state().hasMore, isFalse);
  });

  test('a row pushed onto the next page by a new one is listed once', () async {
    await start();
    await pages.answer([10, 9, 8], next: 2);
    // A delivery added row 11 meanwhile: page 2 now starts with 8.
    unawaited(notifier().loadMore());
    await pumpEventQueue();
    await pages.answer([8, 7, 6]);

    expect(state().items, [10, 9, 8, 7, 6]);
  });

  test('without keyOf, rows are appended as they come', () async {
    await start(dedupe: false);
    await pages.answer([10, 9, 8], next: 2);
    unawaited(notifier().loadMore());
    await pumpEventQueue();
    await pages.answer([8, 7]);

    expect(state().items, [10, 9, 8, 8, 7]);
  });

  test('a refresh supersedes a "Load more" in flight; its late answer is '
      'dropped', () async {
    await start();
    await pages.answer([5, 4, 3], next: 2);

    unawaited(notifier().loadMore());
    await pumpEventQueue();
    final refreshed = notifier().refresh();
    await pumpEventQueue();
    expect(pages.requests, [1, 2, 1]);

    await pages.answer([2, 1]); // the stale page 2
    expect(state().items, [5, 4, 3]);
    expect(state().loading, isTrue);

    await pages.answer([6, 5, 4], next: 2);
    await refreshed;
    expect(state().items, [6, 5, 4]);
    expect(state().loading, isFalse);
  });

  test('a failed next page keeps the rows and the error; retry clears '
      'it', () async {
    await start();
    await pages.answer([5, 4, 3], next: 2);

    unawaited(notifier().loadMore());
    await pumpEventQueue();
    await pages.fail(const ApiError(code: ApiErrorCode.network));
    expect(state().items, [5, 4, 3]);
    expect(state().error?.code, ApiErrorCode.network);
    expect(state().hasMore, isTrue);

    unawaited(notifier().loadMore());
    await pumpEventQueue();
    expect(state().error, isNull, reason: 'cleared while retrying');
    await pages.answer([2, 1]);
    expect(state().items, [5, 4, 3, 2, 1]);
  });

  test('a failed first page: not loaded, with the error', () async {
    await start();
    await pages.fail(const ApiError(code: ApiErrorCode.timeout));

    expect(state().loaded, isFalse);
    expect(state().loading, isFalse);
    expect(state().error?.code, ApiErrorCode.timeout);
  });

  test('a refresh during a refresh: the latest wins, even when the older '
      'answer comes last', () async {
    await start();
    await pages.answer([5, 4, 3], next: 2);

    final first = notifier().refresh();
    await pumpEventQueue();
    final second = notifier().refresh();
    await pumpEventQueue();
    expect(pages.requests, [1, 1, 1]);

    await pages.answer([9, 8], at: 1); // the second refresh
    await second;
    expect(state().items, [9, 8]);
    expect(state().loading, isFalse);
    expect(state().hasMore, isFalse);

    await pages.answer([1], next: 2); // the first, late
    await first;
    expect(state().items, [9, 8]);
    expect(state().hasMore, isFalse);
  });

  test('a refresh fails while a stale "Load more" is pending: the error '
      'stays, the late page is dropped', () async {
    await start();
    await pages.answer([5, 4, 3], next: 2);

    unawaited(notifier().loadMore());
    await pumpEventQueue();
    final refreshed = notifier().refresh();
    await pumpEventQueue();
    expect(pages.requests, [1, 2, 1]);

    await pages.fail(const ApiError(code: ApiErrorCode.network), at: 1);
    await refreshed;
    expect(state().items, [5, 4, 3]);
    expect(state().error?.code, ApiErrorCode.network);
    expect(state().loading, isFalse);

    final writes = notifier().writes;
    await pages.answer([2, 1]); // the stale page 2
    expect(notifier().writes, writes, reason: 'no state write');
    expect(state().items, [5, 4, 3]);
    expect(state().error?.code, ApiErrorCode.network);
  });

  test('a late answer after the list is gone: no exception, no state '
      'write', () async {
    await start();
    expect(pages.requests, [1]);
    final spy = notifier();
    final writes = spy.writes;

    container.dispose();
    // Writing state after dispose would throw (an uncaught error fails
    // the test) and count a write.
    await pages.answer([5, 4, 3], next: 2);
    expect(spy.writes, writes);

    // Same for a failure.
    await start();
    final failing = notifier();
    final failingWrites = failing.writes;
    container.dispose();
    await pages.fail(const ApiError(code: ApiErrorCode.network));
    expect(failing.writes, failingWrites);
  });

  test('disposed before the first load starts: nothing is fetched', () async {
    pages = _Pages();
    provider = NotifierProvider(() => _SpyNotifier(pages, dedupe: true));
    container = await RiderTestHarness().container();
    final spy = container.read(provider.notifier);
    container.dispose();
    await pumpEventQueue();

    expect(pages.requests, isEmpty);
    expect(spy.writes, 0);
  });
}
